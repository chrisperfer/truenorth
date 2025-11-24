# Multi-Location Waypoints Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform TrueNorth from single-direction compass to multi-waypoint navigator with simultaneous spatial audio for multiple locations.

**Architecture:** Refactor SpatialAudioEngine from single AVAudioPlayerNode to dictionary-based multi-source management. Extract tone generation into configurable profiles. Add geocoding service for address search. Persist locations via UserDefaults.

**Tech Stack:** SwiftUI, AVFoundation, CoreLocation, Combine

---

## Phase 1: Foundation - Data Models & Stores

### Task 1.1: Create ToneProfile Model

**Files:**
- Create: `TrueNorth/TrueNorth/Models/ToneProfile.swift`

**Step 1: Create Models directory**

```bash
mkdir -p TrueNorth/TrueNorth/Models
```

**Step 2: Create ToneProfile.swift**

Create new file with complete ToneProfile model:

```swift
import Foundation

struct ToneProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String

    // Core tone parameters
    var frequency: Float
    var pingDuration: Float
    var pingInterval: Float
    var echoDelay: Float
    var echoAttenuation: Float

    // Harmonic parameters
    var fundamentalAmplitude: Float
    var harmonic2Amplitude: Float
    var harmonic3Amplitude: Float
    var harmonic4Amplitude: Float

    // Transient parameters
    var transientFrequency: Float
    var transientAmplitude: Float
    var transientDecay: Float

    // Envelope parameters
    var pingEnvelopeDecay: Float
    var echoEnvelopeDecay: Float
    var frequencySweepAmount: Float

    init(
        id: UUID = UUID(),
        name: String,
        frequency: Float = 830.0,
        pingDuration: Float = 0.15,
        pingInterval: Float = 5.0,
        echoDelay: Float = 5.0,
        echoAttenuation: Float = 0.28,
        fundamentalAmplitude: Float = 1.0,
        harmonic2Amplitude: Float = 1.0,
        harmonic3Amplitude: Float = 1.0,
        harmonic4Amplitude: Float = 1.0,
        transientFrequency: Float = 3000.0,
        transientAmplitude: Float = 0.3,
        transientDecay: Float = 50.0,
        pingEnvelopeDecay: Float = 3.0,
        echoEnvelopeDecay: Float = 4.0,
        frequencySweepAmount: Float = 0.4
    ) {
        self.id = id
        self.name = name
        self.frequency = frequency
        self.pingDuration = pingDuration
        self.pingInterval = pingInterval
        self.echoDelay = echoDelay
        self.echoAttenuation = echoAttenuation
        self.fundamentalAmplitude = fundamentalAmplitude
        self.harmonic2Amplitude = harmonic2Amplitude
        self.harmonic3Amplitude = harmonic3Amplitude
        self.harmonic4Amplitude = harmonic4Amplitude
        self.transientFrequency = transientFrequency
        self.transientAmplitude = transientAmplitude
        self.transientDecay = transientDecay
        self.pingEnvelopeDecay = pingEnvelopeDecay
        self.echoEnvelopeDecay = echoEnvelopeDecay
        self.frequencySweepAmount = frequencySweepAmount
    }
}
```

**Step 3: Add file to Xcode project**

Open TrueNorth.xcodeproj, right-click Models folder (or create it), select "Add Files to TrueNorth", select ToneProfile.swift, ensure target membership includes TrueNorth.

**Step 4: Build to verify no errors**

Run: `xcodebuild -project TrueNorth/TrueNorth.xcodeproj -scheme TrueNorth -sdk iphonesimulator`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add TrueNorth/TrueNorth/Models/ToneProfile.swift
git commit -m "feat: add ToneProfile data model with audio parameters"
```

---

### Task 1.2: Create Location Model

**Files:**
- Create: `TrueNorth/TrueNorth/Models/Location.swift`

**Step 1: Create Location.swift**

Create new file:

```swift
import Foundation
import CoreLocation

struct Location: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var toneProfileId: UUID
    var isEnabled: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        id: UUID = UUID(),
        name: String,
        coordinate: CLLocationCoordinate2D,
        toneProfileId: UUID,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.toneProfileId = toneProfileId
        self.isEnabled = isEnabled
    }

    // Codable conformance for CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, toneProfileId, isEnabled
    }
}
```

**Step 2: Add to Xcode project**

Add Location.swift to Models group with TrueNorth target membership.

**Step 3: Build to verify**

Run: `xcodebuild -project TrueNorth/TrueNorth.xcodeproj -scheme TrueNorth -sdk iphonesimulator`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add TrueNorth/TrueNorth/Models/Location.swift
git commit -m "feat: add Location data model with coordinates and tone profile"
```

---

### Task 1.3: Create ToneProfileStore

**Files:**
- Create: `TrueNorth/TrueNorth/Stores/ToneProfileStore.swift`

**Step 1: Create Stores directory**

```bash
mkdir -p TrueNorth/TrueNorth/Stores
```

**Step 2: Create ToneProfileStore.swift**

```swift
import Foundation
import Combine

class ToneProfileStore: ObservableObject {
    @Published var profiles: [ToneProfile]

    // Hardcoded profiles for POC
    init() {
        self.profiles = [
            ToneProfile(
                name: "Default North Tone",
                frequency: 830.0,
                pingDuration: 0.15,
                pingInterval: 5.0,
                echoDelay: 5.0,
                echoAttenuation: 0.28,
                fundamentalAmplitude: 1.0,
                harmonic2Amplitude: 1.0,
                harmonic3Amplitude: 1.0,
                harmonic4Amplitude: 1.0,
                transientFrequency: 3000.0,
                transientAmplitude: 0.3,
                transientDecay: 50.0,
                pingEnvelopeDecay: 3.0,
                echoEnvelopeDecay: 4.0,
                frequencySweepAmount: 0.4
            ),
            ToneProfile(
                name: "Warm Alternate",
                frequency: 600.0,
                pingDuration: 0.15,
                pingInterval: 5.0,
                echoDelay: 5.0,
                echoAttenuation: 0.28,
                fundamentalAmplitude: 1.0,
                harmonic2Amplitude: 0.8,
                harmonic3Amplitude: 0.6,
                harmonic4Amplitude: 0.4,
                transientFrequency: 2400.0,
                transientAmplitude: 0.25,
                transientDecay: 50.0,
                pingEnvelopeDecay: 3.0,
                echoEnvelopeDecay: 4.0,
                frequencySweepAmount: 0.4
            )
        ]
    }

    func profile(withId id: UUID) -> ToneProfile? {
        profiles.first { $0.id == id }
    }

    var defaultProfile: ToneProfile {
        profiles[0]
    }
}
```

**Step 3: Add to Xcode project**

Add ToneProfileStore.swift to Stores group.

**Step 4: Build to verify**

Run build command. Expected: Success

**Step 5: Commit**

```bash
git add TrueNorth/TrueNorth/Stores/ToneProfileStore.swift
git commit -m "feat: add ToneProfileStore with hardcoded POC profiles"
```

---

### Task 1.4: Create LocationStore

**Files:**
- Create: `TrueNorth/TrueNorth/Stores/LocationStore.swift`

**Step 1: Create LocationStore.swift**

```swift
import Foundation
import Combine
import CoreLocation

class LocationStore: ObservableObject {
    @Published var locations: [Location] = []

    private let storageKey = "SavedLocations"
    private var cancellables = Set<AnyCancellable>()

    init() {
        load()

        // Auto-save on changes
        $locations
            .dropFirst() // Skip initial load
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.save()
            }
            .store(in: &cancellables)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Location].self, from: data) else {
            locations = []
            return
        }
        locations = decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(locations) else {
            print("Failed to encode locations")
            return
        }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }

    func add(_ location: Location) {
        locations.append(location)
    }

    func update(_ location: Location) {
        if let index = locations.firstIndex(where: { $0.id == location.id }) {
            locations[index] = location
        }
    }

    func delete(_ location: Location) {
        locations.removeAll { $0.id == location.id }
    }

    func toggle(_ location: Location) {
        if let index = locations.firstIndex(where: { $0.id == location.id }) {
            locations[index].isEnabled.toggle()
        }
    }
}
```

**Step 2: Add to Xcode project**

Add LocationStore.swift to Stores group.

**Step 3: Build to verify**

Run build. Expected: Success

**Step 4: Commit**

```bash
git add TrueNorth/TrueNorth/Stores/LocationStore.swift
git commit -m "feat: add LocationStore with UserDefaults persistence"
```

---

## Phase 2: Services - Location & Geocoding

### Task 2.1: Create LocationService for Geocoding

**Files:**
- Create: `TrueNorth/TrueNorth/Services/LocationService.swift`

**Step 1: Create Services directory**

```bash
mkdir -p TrueNorth/TrueNorth/Services
```

**Step 2: Create LocationService.swift**

```swift
import Foundation
import CoreLocation

enum LocationServiceError: Error, LocalizedError {
    case noResults
    case invalidAddress
    case geocodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noResults:
            return "No results found for this address"
        case .invalidAddress:
            return "Invalid address format"
        case .geocodingFailed(let error):
            return "Geocoding failed: \(error.localizedDescription)"
        }
    }
}

class LocationService {
    private let geocoder = CLGeocoder()

    func geocode(address: String) async -> Result<CLLocationCoordinate2D, LocationServiceError> {
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)

            guard let coordinate = placemarks.first?.location?.coordinate else {
                return .failure(.noResults)
            }

            return .success(coordinate)
        } catch {
            return .failure(.geocodingFailed(error))
        }
    }

    func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }
}
```

**Step 3: Add to Xcode project**

Add LocationService.swift to Services group.

**Step 4: Build to verify**

Run build. Expected: Success

**Step 5: Commit**

```bash
git add TrueNorth/TrueNorth/Services/LocationService.swift
git commit -m "feat: add LocationService with async geocoding"
```

---

### Task 2.2: Extend OrientationManager for User Location

**Files:**
- Modify: `TrueNorth/TrueNorth/ViewModels/OrientationManager.swift`

**Step 1: Read current OrientationManager**

Read the file to understand current structure.

**Step 2: Add user location tracking**

Add these properties near the top of the class (after existing @Published properties):

```swift
@Published var userLocation: CLLocationCoordinate2D?
@Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
```

**Step 3: Add location manager configuration**

In `startHeadTracking()` or `startDeviceMotion()`, add after compass setup:

```swift
// Enable user location tracking for waypoint bearings
locationManager.desiredAccuracy = kCLLocationAccuracyBest
locationManager.startUpdatingLocation()
```

**Step 4: Implement location delegate method**

Add this extension at the bottom of the file (before or after existing CLLocationManagerDelegate):

```swift
// MARK: - User Location Updates
extension OrientationManager {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last?.coordinate
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationAuthorizationStatus = manager.authorizationStatus
    }
}
```

**Step 5: Build to verify**

Run build. Expected: Success

**Step 6: Commit**

```bash
git add TrueNorth/TrueNorth/ViewModels/OrientationManager.swift
git commit -m "feat: add user location tracking to OrientationManager"
```

---

### Task 2.3: Add Bearing Calculation Utility

**Files:**
- Create: `TrueNorth/TrueNorth/Utilities/BearingCalculator.swift`

**Step 1: Create BearingCalculator.swift**

```swift
import Foundation
import CoreLocation

struct BearingCalculator {
    /// Calculate bearing from user location to destination in degrees (0-360)
    /// 0° = North, 90° = East, 180° = South, 270° = West
    static func calculateBearing(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi

        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Calculate relative bearing from user heading to destination bearing
    /// Returns angle in degrees (-180 to 180) where 0 = straight ahead
    static func relativeBearing(
        userHeading: Double,
        destinationBearing: Double
    ) -> Double {
        var relative = destinationBearing - userHeading

        // Normalize to -180 to 180
        if relative > 180 {
            relative -= 360
        } else if relative < -180 {
            relative += 360
        }

        return relative
    }
}
```

**Step 2: Add to Xcode project**

Add to Utilities group.

**Step 3: Build to verify**

Run build. Expected: Success

**Step 4: Commit**

```bash
git add TrueNorth/TrueNorth/Utilities/BearingCalculator.swift
git commit -m "feat: add bearing calculation utilities"
```

---

## Phase 3: Audio Engine Refactoring

### Task 3.1: Extract Buffer Generation Method

**Files:**
- Modify: `TrueNorth/TrueNorth/Utilities/SpatialAudioEngine.swift`

**Step 1: Read current SpatialAudioEngine**

Understand the current `generateAudioBuffer()` implementation.

**Step 2: Add new generateAudioBuffer method with ToneProfile parameter**

Add this new method before the existing `generateAudioBuffer()`:

```swift
private func generateAudioBuffer(for profile: ToneProfile) -> AVAudioPCMBuffer? {
    let sampleRate: Double = 44100
    let duration: TimeInterval = max(Double(profile.pingInterval), 2.0)
    let frameCount = AVAudioFrameCount(sampleRate * duration)

    guard let buffer = AVAudioPCMBuffer(
        pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!,
        frameCapacity: frameCount
    ) else {
        print("Failed to create audio buffer")
        return nil
    }

    buffer.frameLength = frameCount

    guard let channelData = buffer.floatChannelData?[0] else {
        print("Failed to get channel data")
        return nil
    }

    for frame in 0..<Int(frameCount) {
        let time = Double(frame) / sampleRate
        var sample: Float = 0

        let cycleTime = time.truncatingRemainder(dividingBy: Double(profile.pingInterval))

        // Main ping with harmonics
        if cycleTime < Double(profile.pingDuration) {
            let pingTime = cycleTime / Double(profile.pingDuration)
            let envelope = Float(exp(-Double(profile.pingEnvelopeDecay) * pingTime))
            let frequency = Double(profile.frequency) * (1.0 - Double(profile.frequencySweepAmount) * pingTime)

            let fundamental = sin(Float(2.0 * .pi * frequency * cycleTime)) * envelope * profile.fundamentalAmplitude
            let harmonic2 = sin(Float(2.0 * .pi * frequency * 2.0 * cycleTime)) * envelope * profile.harmonic2Amplitude
            let harmonic3 = sin(Float(2.0 * .pi * frequency * 3.0 * cycleTime)) * envelope * profile.harmonic3Amplitude
            let harmonic4 = sin(Float(2.0 * .pi * frequency * 4.0 * cycleTime)) * envelope * profile.harmonic4Amplitude

            let transientEnvelope = Float(exp(-Double(profile.transientDecay) * pingTime))
            let transient = sin(Float(2.0 * .pi * Double(profile.transientFrequency) * cycleTime)) * transientEnvelope * profile.transientAmplitude

            sample = fundamental + harmonic2 + harmonic3 + harmonic4 + transient
        }

        // Echo
        let echoStart = Double(profile.echoDelay)
        let echoEnd = echoStart + Double(profile.pingDuration)
        if cycleTime >= echoStart && cycleTime < echoEnd {
            let echoTime = (cycleTime - echoStart) / Double(profile.pingDuration)
            let envelope = Float(exp(-Double(profile.echoEnvelopeDecay) * echoTime)) * profile.echoAttenuation
            let frequency = Double(profile.frequency) * 0.9 * (1.0 - Double(profile.frequencySweepAmount) * 1.5 * echoTime)

            let fundamental = sin(Float(2.0 * .pi * frequency * (cycleTime - echoStart))) * envelope * profile.fundamentalAmplitude
            let harmonic2 = sin(Float(2.0 * .pi * frequency * 2.0 * (cycleTime - echoStart))) * envelope * profile.harmonic2Amplitude * 0.75
            let harmonic3 = sin(Float(2.0 * .pi * frequency * 3.0 * (cycleTime - echoStart))) * envelope * profile.harmonic3Amplitude * 0.6

            sample += fundamental + harmonic2 + harmonic3
        }

        sample = tanh(sample)
        channelData[frame] = sample
    }

    return buffer
}
```

**Step 3: Update existing generateAudioBuffer() to use new method**

Replace the body of the old `generateAudioBuffer()` with:

```swift
private func generateAudioBuffer() {
    // Create default tone profile from current instance properties
    let profile = ToneProfile(
        name: "Default",
        frequency: toneFrequency,
        pingDuration: pingDuration,
        pingInterval: pingInterval,
        echoDelay: echoDelay,
        echoAttenuation: echoAttenuation,
        fundamentalAmplitude: fundamentalAmplitude,
        harmonic2Amplitude: harmonic2Amplitude,
        harmonic3Amplitude: harmonic3Amplitude,
        harmonic4Amplitude: harmonic4Amplitude,
        transientFrequency: transientFrequency,
        transientAmplitude: transientAmplitude,
        transientDecay: transientDecay,
        pingEnvelopeDecay: pingEnvelopeDecay,
        echoEnvelopeDecay: echoEnvelopeDecay,
        frequencySweepAmount: frequencySweepAmount
    )

    audioBuffer = generateAudioBuffer(for: profile)

    if audioBuffer != nil {
        print("Audio buffer generated: Enhanced spatial ping")
    }
}
```

**Step 4: Build to verify**

Run build. Expected: Success

**Step 5: Commit**

```bash
git add TrueNorth/TrueNorth/Utilities/SpatialAudioEngine.swift
git commit -m "refactor: extract tone profile-based buffer generation"
```

---

### Task 3.2: Add Multi-Source Infrastructure

**Files:**
- Modify: `TrueNorth/TrueNorth/Utilities/SpatialAudioEngine.swift`

**Step 1: Add multi-source properties**

After existing properties (around line 43), add:

```swift
// Multi-source management
private var playerNodes: [UUID: AVAudioPlayerNode] = [:]
private var audioBuffers: [UUID: AVAudioPCMBuffer] = [:]

// North special case
private let northId = UUID() // Static identifier for north direction
```

**Step 2: Build to verify no compile errors**

Run build. Expected: Success

**Step 3: Commit**

```bash
git add TrueNorth/TrueNorth/Utilities/SpatialAudioEngine.swift
git commit -m "feat: add multi-source infrastructure to SpatialAudioEngine"
```

---

### Task 3.3: Add Audio Source Lifecycle Methods

**Files:**
- Modify: `TrueNorth/TrueNorth/Utilities/SpatialAudioEngine.swift`

**Step 1: Add createPlayerNode method**

Add before `deinit`:

```swift
// MARK: - Multi-Source Management

private func createPlayerNode(for id: UUID, profile: ToneProfile) -> AVAudioPlayerNode? {
    let node = AVAudioPlayerNode()

    // Generate buffer for this profile
    guard let buffer = generateAudioBuffer(for: profile) else {
        print("Failed to generate buffer for \(id)")
        return nil
    }

    // Attach and connect node
    audioEngine.attach(node)

    let monoFormat = AVAudioFormat(
        standardFormatWithSampleRate: audioEngine.outputNode.outputFormat(forBus: 0).sampleRate,
        channels: 1
    )!

    audioEngine.connect(node, to: environmentNode, format: monoFormat)

    // Configure node
    node.position = AVAudio3DPoint(x: 0, y: 0, z: -4)
    node.renderingAlgorithm = .HRTFHQ
    node.volume = volume

    // Schedule looping playback
    node.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)

    // Store
    playerNodes[id] = node
    audioBuffers[id] = buffer

    print("Created player node for \(id)")
    return node
}

private func removePlayerNode(for id: UUID) {
    guard let node = playerNodes[id] else { return }

    node.stop()
    audioEngine.detach(node)
    playerNodes.removeValue(forKey: id)
    audioBuffers.removeValue(forKey: id)

    print("Removed player node for \(id)")
}
```

**Step 2: Build to verify**

Run build. Expected: Success

**Step 3: Commit**

```bash
git add TrueNorth/TrueNorth/Utilities/SpatialAudioEngine.swift
git commit -m "feat: add player node lifecycle management"
```

---

### Task 3.4: Add Location Update Methods

**Files:**
- Modify: `TrueNorth/TrueNorth/Utilities/SpatialAudioEngine.swift`

**Step 1: Add updateLocations method**

Add after createPlayerNode methods:

```swift
func updateLocations(_ locations: [Location], toneProfileStore: ToneProfileStore) {
    // Get IDs of enabled locations
    let enabledIds = Set(locations.filter { $0.isEnabled }.map { $0.id })

    // Remove nodes for disabled/deleted locations
    let currentIds = Set(playerNodes.keys).subtracting([northId])
    let toRemove = currentIds.subtracting(enabledIds)
    toRemove.forEach { removePlayerNode(for: $0) }

    // Add nodes for newly enabled locations
    let toAdd = enabledIds.subtracting(currentIds)
    for id in toAdd {
        guard let location = locations.first(where: { $0.id == id }),
              let profile = toneProfileStore.profile(withId: location.toneProfileId),
              let node = createPlayerNode(for: id, profile: profile) else {
            continue
        }

        // Start playback if engine is running
        if audioEngine.isRunning && isPlaying {
            node.play()
        }
    }
}

func updatePositions(
    heading: Double,
    userLocation: CLLocationCoordinate2D?,
    locations: [Location]
) {
    guard audioEngine.isRunning else { return }

    // Update north position (existing behavior)
    updateNorthPosition(heading: heading)

    // Update waypoint positions
    guard let userLocation = userLocation else { return }

    for location in locations where location.isEnabled {
        guard let node = playerNodes[location.id] else { continue }

        let bearing = BearingCalculator.calculateBearing(
            from: userLocation,
            to: location.coordinate
        )
        let relativeBearing = BearingCalculator.relativeBearing(
            userHeading: heading,
            destinationBearing: bearing
        )

        let position = calculateAudioPosition(relativeBearing: relativeBearing)
        node.position = position
    }
}

private func updateNorthPosition(heading: Double) {
    let angleRadians = Float(heading * .pi / 180)
    let distance: Float = 4.0
    let northX = -sin(angleRadians) * distance
    let northZ = -cos(angleRadians) * distance
    let elevationFactor: Float = 1.5
    let northY = cos(angleRadians) * elevationFactor

    if let northNode = playerNodes[northId] {
        northNode.position = AVAudio3DPoint(x: northX, y: northY, z: northZ)
    } else {
        // Fallback to original playerNode for backward compatibility
        playerNode.position = AVAudio3DPoint(x: northX, y: northY, z: northZ)
    }
}

private func calculateAudioPosition(relativeBearing: Double) -> AVAudio3DPoint {
    let angleRadians = Float(relativeBearing * .pi / 180)
    let distance: Float = 4.0
    let x = sin(angleRadians) * distance
    let z = -cos(angleRadians) * distance
    let elevationFactor: Float = 1.5
    let y = cos(angleRadians) * elevationFactor

    return AVAudio3DPoint(x: x, y: y, z: z)
}
```

**Step 2: Build to verify**

Run build. Expected: Success

**Step 3: Commit**

```bash
git add TrueNorth/TrueNorth/Utilities/SpatialAudioEngine.swift
git commit -m "feat: add multi-location position updates"
```

---

### Task 3.5: Initialize North as First Location

**Files:**
- Modify: `TrueNorth/TrueNorth/Utilities/SpatialAudioEngine.swift`

**Step 1: Update init() to create north node**

Modify the `init()` method to initialize north node (instead of just setting source position):

Find the init() method and at the end (before the closing brace), replace the updateSourcePosition call with:

```swift
// Initialize north as the default source
if let defaultProfile = ToneProfileStore().defaultProfile {
    _ = createPlayerNode(for: northId, profile: defaultProfile)
}
```

Note: We'll need to pass ToneProfileStore properly in the next phase when connecting everything.

**Step 2: Build to verify**

Run build. May have warnings about ToneProfileStore(), that's expected for now.

**Step 3: Commit**

```bash
git add TrueNorth/TrueNorth/Utilities/SpatialAudioEngine.swift
git commit -m "feat: initialize north as first multi-source location"
```

---

## Phase 4: UI - Location Management

### Task 4.1: Create AddLocationView

**Files:**
- Create: `TrueNorth/TrueNorth/Views/AddLocationView.swift`

**Step 1: Create Views directory if needed**

```bash
mkdir -p TrueNorth/TrueNorth/Views
```

**Step 2: Create AddLocationView.swift**

```swift
import SwiftUI
import CoreLocation

struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationStore: LocationStore
    @EnvironmentObject var toneProfileStore: ToneProfileStore

    @State private var searchAddress = ""
    @State private var locationName = ""
    @State private var searchResult: CLLocationCoordinate2D?
    @State private var selectedProfileId: UUID
    @State private var isSearching = false
    @State private var errorMessage: String?

    private let locationService = LocationService()

    init() {
        // Default to first profile
        _selectedProfileId = State(initialValue: ToneProfileStore().profiles.first?.id ?? UUID())
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Address") {
                    TextField("123 Main St, City, State", text: $searchAddress)
                        .textContentType(.fullStreetAddress)
                        .autocapitalization(.words)

                    Button(action: searchAddress_action) {
                        if isSearching {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                                Text("Searching...")
                            }
                        } else {
                            Text("Search")
                        }
                    }
                    .disabled(searchAddress.isEmpty || isSearching)

                    if let result = searchResult {
                        Text("Found: \(locationService.formatCoordinate(result))")
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
                            .textContentType(.name)

                        Picker("Tone", selection: $selectedProfileId) {
                            ForEach(toneProfileStore.profiles) { profile in
                                Text(profile.name).tag(profile.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLocation()
                    }
                    .disabled(searchResult == nil || locationName.isEmpty)
                }
            }
        }
    }

    private func searchAddress_action() {
        Task {
            isSearching = true
            errorMessage = nil

            let result = await locationService.geocode(address: searchAddress)

            await MainActor.run {
                switch result {
                case .success(let coordinate):
                    searchResult = coordinate
                    if locationName.isEmpty {
                        locationName = searchAddress.components(separatedBy: ",").first ?? searchAddress
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
                isSearching = false
            }
        }
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

#Preview {
    AddLocationView()
        .environmentObject(LocationStore())
        .environmentObject(ToneProfileStore())
}
```

**Step 3: Add to Xcode project**

Add AddLocationView.swift to Views group.

**Step 4: Build to verify**

Run build. Expected: Success

**Step 5: Commit**

```bash
git add TrueNorth/TrueNorth/Views/AddLocationView.swift
git commit -m "feat: add AddLocationView with geocoding"
```

---

### Task 4.2: Create LocationRow View

**Files:**
- Create: `TrueNorth/TrueNorth/Views/LocationRow.swift`

**Step 1: Create LocationRow.swift**

```swift
import SwiftUI

struct LocationRow: View {
    let location: Location
    let profileName: String
    @Binding var isEnabled: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Toggle(isOn: $isEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.headline)

                    Text(profileName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
    }
}

#Preview {
    LocationRow(
        location: Location(
            name: "Home",
            coordinate: .init(latitude: 37.7749, longitude: -122.4194),
            toneProfileId: UUID()
        ),
        profileName: "Default Tone",
        isEnabled: .constant(true),
        onDelete: {}
    )
}
```

**Step 2: Add to Xcode project**

Add to Views group.

**Step 3: Build to verify**

Run build. Expected: Success

**Step 4: Commit**

```bash
git add TrueNorth/TrueNorth/Views/LocationRow.swift
git commit -m "feat: add LocationRow component"
```

---

### Task 4.3: Add Locations Section to Settings

**Files:**
- Modify: `TrueNorth/TrueNorth/Views/SettingsView.swift` (or wherever settings are)

**Step 1: Find settings view file**

Locate the settings UI file. It might be in ContentView or a separate SettingsView.

**Step 2: Add @EnvironmentObject declarations**

At the top of the view struct, add:

```swift
@EnvironmentObject var locationStore: LocationStore
@EnvironmentObject var toneProfileStore: ToneProfileStore
```

**Step 3: Add @State for showing add location sheet**

```swift
@State private var showingAddLocation = false
```

**Step 4: Add Locations section**

In the Form/List, add a new section after existing settings:

```swift
Section("Locations") {
    // North (always present, can be toggled)
    HStack {
        Toggle("North", isOn: $showNorthDirection)

        Spacer()

        Text("Default Tone")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    // Custom locations
    ForEach(locationStore.locations) { location in
        LocationRow(
            location: location,
            profileName: toneProfileStore.profile(withId: location.toneProfileId)?.name ?? "Unknown",
            isEnabled: Binding(
                get: { location.isEnabled },
                set: { _ in locationStore.toggle(location) }
            ),
            onDelete: {
                locationStore.delete(location)
            }
        )
    }

    Button(action: { showingAddLocation = true }) {
        Label("Add Location", systemImage: "plus.circle.fill")
    }
}
.sheet(isPresented: $showingAddLocation) {
    AddLocationView()
}
```

**Step 5: Add showNorthDirection state if not present**

```swift
@State private var showNorthDirection = true
```

**Step 6: Build to verify**

Run build. Expected: Success (may need to fix exact view structure based on actual code)

**Step 7: Commit**

```bash
git add TrueNorth/TrueNorth/Views/SettingsView.swift
git commit -m "feat: add Locations section to settings"
```

---

## Phase 5: Integration & Wiring

### Task 5.1: Update App Entry Point

**Files:**
- Modify: `TrueNorth/TrueNorth/TrueNorthApp.swift`

**Step 1: Add StateObject stores**

In the main App struct, add:

```swift
@StateObject private var locationStore = LocationStore()
@StateObject private var toneProfileStore = ToneProfileStore()
```

**Step 2: Pass as environment objects**

In the WindowGroup or main view, add:

```swift
ContentView()
    .environmentObject(locationStore)
    .environmentObject(toneProfileStore)
```

**Step 3: Build to verify**

Run build. Expected: Success

**Step 4: Commit**

```bash
git add TrueNorth/TrueNorth/TrueNorthApp.swift
git commit -m "feat: wire up location and tone profile stores"
```

---

### Task 5.2: Connect Audio Engine to Location Updates

**Files:**
- Modify: `TrueNorth/TrueNorth/ViewModels/OrientationManager.swift` (or wherever audio engine is managed)

**Step 1: Add references to stores**

Add these properties:

```swift
private var locationStore: LocationStore?
private var toneProfileStore: ToneProfileStore?
private var locationCancellable: AnyCancellable?
```

**Step 2: Add setup method**

```swift
func setupLocationUpdates(locationStore: LocationStore, toneProfileStore: ToneProfileStore) {
    self.locationStore = locationStore
    self.toneProfileStore = toneProfileStore

    // Subscribe to location changes
    locationCancellable = locationStore.$locations
        .sink { [weak self] locations in
            guard let self = self,
                  let toneProfileStore = self.toneProfileStore else { return }
            self.audioEngine.updateLocations(locations, toneProfileStore: toneProfileStore)
        }
}
```

**Step 3: Update orientation update calls**

In the method that calls `audioEngine.updateOrientation`, replace it with:

```swift
audioEngine.updatePositions(
    heading: combinedHeading,
    userLocation: userLocation,
    locations: locationStore?.locations ?? []
)
```

**Step 4: Call setup from ContentView**

In ContentView (or wherever OrientationManager is initialized), add:

```swift
.onAppear {
    orientationManager.setupLocationUpdates(
        locationStore: locationStore,
        toneProfileStore: toneProfileStore
    )
}
```

**Step 5: Build to verify**

Run build. Expected: Success

**Step 6: Commit**

```bash
git add TrueNorth/TrueNorth/ViewModels/OrientationManager.swift
git add TrueNorth/TrueNorth/Views/ContentView.swift
git commit -m "feat: connect audio engine to location store updates"
```

---

## Phase 6: Testing & Validation

### Task 6.1: Manual Testing - Data Persistence

**Test Steps:**

1. Build and run app on simulator
2. Go to Settings > Locations
3. Tap "Add Location"
4. Enter address: "1 Infinite Loop, Cupertino, CA"
5. Tap "Search"
6. Verify: Coordinates appear (37.3318, -122.0297 approximately)
7. Enter name: "Apple Park"
8. Select tone: "Warm Alternate"
9. Tap "Save"
10. Verify: Location appears in list
11. Force quit app
12. Relaunch app
13. Go to Settings > Locations
14. Verify: "Apple Park" location still present

**Expected:** Location persists after app restart

---

### Task 6.2: Manual Testing - Audio Playback

**Test Steps:**

1. Launch app with AirPods Pro/Max
2. Enable compass audio
3. Add a location nearby (or use simulator location)
4. Rotate device 360°
5. Listen for both north tone and location tone
6. Verify: Two distinct tones audible
7. Verify: Tones come from correct spatial directions
8. Disable location in settings
9. Verify: Location tone stops, north continues

**Expected:** Multiple spatial audio sources work simultaneously

---

### Task 6.3: Manual Testing - Geocoding

**Test Steps:**

1. Tap "Add Location"
2. Enter invalid address: "asdfghjkl"
3. Tap "Search"
4. Verify: Error message shown
5. Enter valid address: "Space Needle, Seattle"
6. Tap "Search"
7. Verify: Coordinates shown (47.6205, -122.3493)
8. Verify: Name auto-fills with "Space Needle"

**Expected:** Geocoding handles errors gracefully and finds valid addresses

---

### Task 6.4: Polish - Loading States

**Files:**
- Modify: `TrueNorth/TrueNorth/Views/AddLocationView.swift`

**Step 1: Verify loading indicators present**

Check that `isSearching` state shows ProgressView during geocoding.

**Step 2: Add haptic feedback on success**

Import UIKit at top:

```swift
import UIKit
```

In `searchAddress_action()`, after successful geocode:

```swift
case .success(let coordinate):
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    searchResult = coordinate
```

**Step 3: Build and test**

Run app, search address, verify haptic feedback.

**Step 4: Commit**

```bash
git add TrueNorth/TrueNorth/Views/AddLocationView.swift
git commit -m "polish: add haptic feedback to geocoding"
```

---

### Task 6.5: Documentation Update

**Files:**
- Modify: `README.md`

**Step 1: Update README features section**

Add to features list:

```markdown
### Multi-Location Waypoints

- **Custom Locations**: Save favorite places with friendly names
- **Address Search**: Find locations by typing addresses
- **Simultaneous Audio**: All waypoints play at once with unique tones
- **Spatial Navigation**: Hear direction to multiple points simultaneously
- **Persistent Storage**: Locations save between sessions
```

**Step 2: Add usage instructions**

Add section:

```markdown
## Adding Custom Locations

1. Open Settings
2. Tap "Add Location" under Locations section
3. Enter an address (e.g., "1 Market St, San Francisco")
4. Tap "Search"
5. Confirm coordinates and enter a friendly name
6. Select a tone profile
7. Tap "Save"

The location will now play its tone whenever enabled, pointing you toward it via spatial audio.
```

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: update README with multi-location features"
```

---

## Final Integration

### Task 7.1: Build and Run Complete Integration

**Test Steps:**

1. Clean build folder: Product > Clean Build Folder in Xcode
2. Build: Cmd+B
3. Run on simulator with location enabled
4. Run on physical device with AirPods
5. Add 2-3 locations
6. Walk/move to test spatial audio
7. Verify all tones distinguishable
8. Verify directions accurate

**Expected:** Complete feature works end-to-end

---

### Task 7.2: Create Feature Branch PR

**Step 1: Push branch**

```bash
git push -u origin feature/multi-location-waypoints
```

**Step 2: Create PR via GitHub CLI or web**

```bash
gh pr create --title "feat: multi-location waypoints with spatial audio" --body "Implements multi-location waypoint navigation with:
- Multiple simultaneous spatial audio sources
- Address geocoding for location search
- Configurable tone profiles
- UserDefaults persistence
- Location management UI

Closes #[issue-number]"
```

**Step 3: Request review**

Assign reviewers or self-review the diff.

---

## Success Criteria

- ✅ Multiple locations can be added via address search
- ✅ Locations persist between app sessions
- ✅ Multiple spatial audio sources play simultaneously
- ✅ Each location has distinct, recognizable tone
- ✅ Spatial positioning reflects actual bearing to locations
- ✅ North direction preserved and functional
- ✅ UI provides intuitive location management
- ✅ No regressions in existing compass functionality

---

## Notes

- **TDD Adaptation**: iOS apps often lack test coverage. Manual testing steps replace automated tests while maintaining verification rigor.
- **Xcode Project Management**: Each file creation requires adding to Xcode project via Project Navigator.
- **Audio Testing**: Requires physical device with AirPods Pro/Max for full spatial audio validation.
- **Location Services**: Ensure Info.plist has `NSLocationWhenInUseUsageDescription` (already present per design doc).
