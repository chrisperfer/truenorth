# Multi-Location Waypoints Design

**Date:** 2025-11-24
**Status:** Approved

## Overview

Transform TrueNorth from a single-direction compass into a multi-waypoint navigator. Users can save custom locations (home, office, favorite spots) that play simultaneously with distinct audio tones, creating spatial awareness of multiple points.

## Requirements

1. **Multiple Simultaneous Audio Sources**: All active waypoints play at once with distinguishable tones
2. **Location Management**: Add/edit/delete custom locations with friendly names and coordinates
3. **Address Geocoding**: Convert street addresses to coordinates using Apple's geocoding service
4. **Tone Abstraction**: Each location uses a configurable tone profile with unique acoustic properties
5. **Data Persistence**: Locations persist between sessions via UserDefaults
6. **North Preservation**: Magnetic north remains as the default, always-available waypoint

## Data Models

### ToneProfile

Encapsulates all audio parameters currently hardcoded in `SpatialAudioEngine`:

```swift
struct ToneProfile: Identifiable, Codable {
    let id: UUID
    var name: String

    // Core tone parameters
    var frequency: Float = 830.0
    var pingDuration: Float = 0.15
    var pingInterval: Float = 5.0
    var echoDelay: Float = 5.0
    var echoAttenuation: Float = 0.28

    // Harmonic parameters
    var fundamentalAmplitude: Float = 1.0
    var harmonic2Amplitude: Float = 1.0
    var harmonic3Amplitude: Float = 1.0
    var harmonic4Amplitude: Float = 1.0

    // Transient parameters
    var transientFrequency: Float = 3000.0
    var transientAmplitude: Float = 0.3
    var transientDecay: Float = 50.0

    // Envelope parameters
    var pingEnvelopeDecay: Float = 3.0
    var echoEnvelopeDecay: Float = 4.0
    var frequencySweepAmount: Float = 0.4
}
```

**POC Implementation**: Two hardcoded profiles:
- Default: Current settings (830 Hz fundamental)
- Alternate: 600 Hz fundamental with adjusted harmonic ratios for warmth

### Location

Represents a saved waypoint:

```swift
struct Location: Identifiable, Codable {
    let id: UUID
    var name: String
    var coordinate: CLLocationCoordinate2D
    var toneProfileId: UUID
    var isEnabled: Bool

    init(name: String, coordinate: CLLocationCoordinate2D, toneProfileId: UUID) {
        self.id = UUID()
        self.name = name
        self.coordinate = coordinate
        self.toneProfileId = toneProfileId
        self.isEnabled = true
    }
}
```

**Special Case**: North has no location entry—it represents a direction, not coordinates. The system handles it separately in audio calculations.

## Audio Architecture

### Multi-Source Engine Refactoring

`SpatialAudioEngine` evolves from single-source to multi-source:

**Current State:**
- One `AVAudioPlayerNode` (playerNode)
- One audio buffer (audioBuffer)
- One 3D position updated by heading

**New State:**
```swift
class SpatialAudioEngine: ObservableObject {
    // Audio infrastructure (unchanged)
    private var audioEngine = AVAudioEngine()
    private var environmentNode = AVAudioEnvironmentNode()

    // Multi-source management
    private var playerNodes: [UUID: AVAudioPlayerNode] = [:]
    private var audioBuffers: [UUID: AVAudioPCMBuffer] = [:]

    // North as special case
    private let northId = UUID() // Static identifier for north
}
```

### Audio Buffer Generation

Extract buffer generation into reusable method:

```swift
func generateAudioBuffer(for profile: ToneProfile) -> AVAudioPCMBuffer? {
    // Use profile parameters instead of instance properties
    // Generate mono buffer with profile's harmonics/transients
    // Return configured buffer
}
```

This replaces the current `generateAudioBuffer()` that uses instance properties.

### Position Calculation

Bearing calculation for waypoints:

```swift
func calculateBearing(from userLocation: CLLocationCoordinate2D,
                     to destination: CLLocationCoordinate2D) -> Double {
    // Haversine formula or CLLocation built-in
    let lat1 = userLocation.latitude * .pi / 180
    let lon1 = userLocation.longitude * .pi / 180
    let lat2 = destination.latitude * .pi / 180
    let lon2 = destination.longitude * .pi / 180

    let dLon = lon2 - lon1
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    let bearing = atan2(y, x) * 180 / .pi

    return (bearing + 360).truncatingRemainder(dividingBy: 360)
}
```

Combine with user heading to get relative audio position:

```swift
func updateOrientation(heading: Double, userLocation: CLLocationCoordinate2D, locations: [Location]) {
    // Update north (special case - direction only)
    updateNorthPosition(heading: heading)

    // Update each enabled location
    for location in locations where location.isEnabled {
        let bearing = calculateBearing(from: userLocation, to: location.coordinate)
        let relativeBearing = bearing - heading
        let position = calculateAudioPosition(relativeBearing: relativeBearing)

        if let playerNode = playerNodes[location.id] {
            playerNode.position = position
        }
    }
}
```

### Node Lifecycle

**Activation** (location enabled):
1. Create `AVAudioPlayerNode`
2. Attach to `audioEngine`
3. Connect to `environmentNode`
4. Generate buffer with location's tone profile
5. Schedule looping playback
6. Start playback
7. Store node in `playerNodes[location.id]`

**Deactivation** (location disabled):
1. Stop playback
2. Remove node from engine
3. Remove from `playerNodes` dictionary
4. Release buffer from `audioBuffers`

## Geocoding Service

Simple wrapper around Apple's geocoding:

```swift
class LocationService {
    func geocode(address: String) async -> Result<CLLocationCoordinate2D, Error> {
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.geocodeAddressString(address)

            guard let coordinate = placemarks.first?.location?.coordinate else {
                return .failure(LocationError.noResults)
            }

            return .success(coordinate)
        } catch {
            return .failure(error)
        }
    }
}

enum LocationError: Error {
    case noResults
    case invalidAddress
}
```

## User Location Tracking

Enhance `OrientationManager` to track user position:

```swift
class OrientationManager: ObservableObject {
    @Published var userLocation: CLLocationCoordinate2D?

    private let locationManager = CLLocationManager()

    func startTracking() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }
}

extension OrientationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager,
                        didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last?.coordinate
        updateAudioPositions() // Recalculate all waypoint bearings
    }
}
```

We already request location permission for compass heading, so no additional permission required.

## Data Persistence

### LocationStore

Manages location collection with UserDefaults persistence:

```swift
class LocationStore: ObservableObject {
    @Published var locations: [Location] = []

    private let storageKey = "SavedLocations"

    init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Location].self, from: data) else {
            locations = []
            return
        }
        locations = decoded
    }

    func save() {
        guard let encoded = try? JSONEncoder().encode(locations) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }

    func add(_ location: Location) {
        locations.append(location)
        save()
    }

    func update(_ location: Location) {
        if let index = locations.firstIndex(where: { $0.id == location.id }) {
            locations[index] = location
            save()
        }
    }

    func delete(_ location: Location) {
        locations.removeAll { $0.id == location.id }
        save()
    }

    func toggle(_ location: Location) {
        if let index = locations.firstIndex(where: { $0.id == location.id }) {
            locations[index].isEnabled.toggle()
            save()
        }
    }
}
```

### ToneProfileStore

Provides tone profiles (hardcoded for POC):

```swift
class ToneProfileStore: ObservableObject {
    @Published var profiles: [ToneProfile] = []

    init() {
        profiles = [
            ToneProfile(
                id: UUID(),
                name: "Default North Tone",
                frequency: 830.0
                // ... current default parameters
            ),
            ToneProfile(
                id: UUID(),
                name: "Warm Alternate",
                frequency: 600.0,
                harmonic2Amplitude: 0.8,
                harmonic3Amplitude: 0.6
                // ... adjusted for warmer sound
            )
        ]
    }
}
```

Future versions can persist custom profiles to UserDefaults.

## State Synchronization

Connect stores to audio engine with Combine:

```swift
class ContentViewModel: ObservableObject {
    @Published var locationStore = LocationStore()
    @Published var toneProfileStore = ToneProfileStore()
    @Published var audioEngine = SpatialAudioEngine()

    private var cancellables = Set<AnyCancellable>()

    init() {
        // React to location changes
        locationStore.$locations
            .sink { [weak self] locations in
                self?.audioEngine.updateLocations(locations)
            }
            .store(in: &cancellables)
    }
}
```

When locations change, the audio engine creates/destroys nodes as needed.

## User Interface

### Settings Sheet Extension

Add "Locations" section below existing audio settings:

```
Settings
├── Audio Settings (existing)
│   ├── Ping Interval
│   ├── Echo Delay
│   └── ...
└── Locations (new)
    ├── [Toggle] North (Default Tone)
    ├── [Toggle] Home (Warm Alternate) [Edit] [Delete]
    ├── [Toggle] Office (Default Tone) [Edit] [Delete]
    └── [+ Add Location]
```

### Add Location Form

SwiftUI sheet with:

1. **Address Search Field**: Text input with "Search" button
2. **Search Result Display**: Shows formatted address and coordinates after geocoding
3. **Name Field**: Defaults to first line of address, user can customize
4. **Tone Profile Picker**: Dropdown with available profiles
5. **Save/Cancel Buttons**: Validate and save or dismiss

```swift
struct AddLocationView: View {
    @State private var searchAddress = ""
    @State private var locationName = ""
    @State private var searchResult: CLLocationCoordinate2D?
    @State private var selectedProfileId: UUID
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section("Address") {
                    TextField("123 Main St, City, State", text: $searchAddress)

                    Button("Search") {
                        Task {
                            await searchAddress()
                        }
                    }
                    .disabled(searchAddress.isEmpty || isSearching)

                    if let result = searchResult {
                        Text("Found: \(formatCoordinate(result))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                if searchResult != nil {
                    Section("Details") {
                        TextField("Location Name", text: $locationName)

                        Picker("Tone", selection: $selectedProfileId) {
                            ForEach(toneProfileStore.profiles) { profile in
                                Text(profile.name).tag(profile.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Location")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveLocation() }
                        .disabled(searchResult == nil || locationName.isEmpty)
                }
            }
        }
    }

    private func searchAddress() async {
        isSearching = true
        errorMessage = nil

        let result = await locationService.geocode(address: searchAddress)

        switch result {
        case .success(let coordinate):
            searchResult = coordinate
            // Default name to first line of search address
            if locationName.isEmpty {
                locationName = searchAddress.components(separatedBy: ",").first ?? searchAddress
            }
        case .failure:
            errorMessage = "Could not find address. Please try again."
        }

        isSearching = false
    }

    private func saveLocation() {
        guard let coordinate = searchResult else { return }

        let location = Location(
            name: locationName,
            coordinate: coordinate,
            toneProfileId: selectedProfileId
        )

        locationStore.add(location)
        dismiss()
    }
}
```

### Edit Location

Reuse `AddLocationView` with populated fields. Allow re-geocoding if user changes address.

### Visual Feedback (Optional for POC)

Main compass view could show small colored indicators at bearing positions for active locations. This is supplementary—spatial audio provides primary feedback.

## Migration & Backward Compatibility

The refactoring preserves existing audio behavior:

- North uses current default tone parameters
- Volume, frequency, and harmonic settings work identically
- No data migration needed (new feature, no existing data)
- Settings UI extends naturally (new section, doesn't replace existing)

## Error Handling

### Geocoding Failures
- No internet: Show "No internet connection" message
- Invalid address: Show "Could not find address" with suggestion to try different terms
- No results: Allow manual coordinate entry as fallback (future enhancement)

### Audio Engine Limits
- iOS supports ~32 simultaneous audio nodes practically
- If limit approached, disable locations gracefully with notification
- For POC, 5-10 locations poses no problem

### Location Permission
- Already requested for compass heading
- If denied, waypoint features show "Location permission required" message
- North direction still works (uses magnetometer, not GPS)

## Testing Approach

### Unit Tests
- Bearing calculation accuracy (test known coordinate pairs)
- Tone profile encoding/decoding
- Location store persistence

### Integration Tests
- Multiple audio nodes play simultaneously
- Position updates reflect correct bearings
- Enable/disable locations updates audio engine

### Manual Tests
- Address geocoding finds correct coordinates
- Audio distinguishable for different tones
- Spatial positioning accurate in real environment
- Settings UI flows work intuitively

## Implementation Phases

### Phase 1: Data Models & Persistence (POC Foundation)
- Create `ToneProfile` struct
- Create `Location` struct
- Implement `LocationStore` with UserDefaults
- Implement `ToneProfileStore` with hardcoded profiles

### Phase 2: Audio Architecture (Core Feature)
- Refactor `SpatialAudioEngine` for multi-source
- Extract buffer generation with tone profiles
- Implement bearing calculation
- Add location lifecycle (enable/disable nodes)

### Phase 3: Location Services (User Position)
- Add user location tracking to `OrientationManager`
- Implement bearing-to-audio-position conversion
- Connect location updates to audio position updates

### Phase 4: Geocoding (Address Search)
- Create `LocationService` with geocoding
- Test address resolution accuracy
- Handle error cases

### Phase 5: User Interface (User Interaction)
- Add "Locations" section to settings
- Build `AddLocationView` form
- Implement edit/delete functionality
- Add enable/disable toggles

### Phase 6: Polish & Testing
- Error message refinement
- Loading state indicators
- Integration testing with multiple locations
- Real-world spatial audio validation

## Success Criteria

1. Users can add custom locations by searching addresses
2. Multiple locations play simultaneously with distinct, recognizable tones
3. Spatial audio accurately reflects bearing to each location
4. Settings UI provides intuitive location management
5. Locations persist between app sessions
6. North direction remains available and unchanged
7. No degradation in existing compass functionality

## Future Enhancements (Out of Scope for POC)

- Custom tone profile editor with sliders
- Location categories/groups
- Distance-based attenuation (closer = louder)
- Turn-by-turn navigation mode (one location at a time)
- Import locations from Contacts or Maps
- Share locations between users
- Location history/favorites
