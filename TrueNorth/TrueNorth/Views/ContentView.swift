import SwiftUI
import Combine
import AVFoundation

struct ContentView: View {
    @StateObject private var orientationManager = OrientationManager()
    @StateObject private var audioEngine = SpatialAudioEngine()
    @EnvironmentObject var locationStore: LocationStore
    @EnvironmentObject var toneProfileStore: ToneProfileStore
    @State private var showingSettings = false
    @State private var showBottomSheet = true
    @State private var selectedDetent: PresentationDetent = .height(180)

    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                VStack(spacing: 10) {
                    // Warning when AirPods not connected - horizontally centered above compass
                    if !orientationManager.isHeadTrackingActive {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.orange)
                            Text("No AirPods Connected")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }

                    CompassView(
                        heading: orientationManager.combinedHeading,
                        isHeadTrackingActive: orientationManager.isHeadTrackingActive,
                        headingAccuracy: orientationManager.headingAccuracy,
                        deviceHeading: orientationManager.deviceHeading,
                        smoothedDeviceHeading: orientationManager.smoothedDeviceHeading,
                        headOffset: {
                            var offset = orientationManager.deviceHeading - orientationManager.combinedHeading
                            if offset > 180 { offset -= 360 }
                            if offset < -180 { offset += 360 }
                            return offset
                        }()
                    )

                    HStack(spacing: 20) {
                        // Head Tracking Calibration Button
                        Button(action: {
                            orientationManager.calibrateHeadTracking()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "scope")
                                    .font(.system(size: 24))
                                    .foregroundColor(orientationManager.isHeadTrackingActive ? .green : .gray)
                                Text("Zero")
                                    .font(.system(size: 10))
                                    .foregroundColor(orientationManager.isHeadTrackingActive ? .green : .gray)
                            }
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.gray.opacity(0.1)))
                        }
                        .disabled(!orientationManager.isHeadTrackingActive)

                        // Pocket Mode Lock Button
                        Button(action: {
                            orientationManager.togglePocketMode()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: orientationManager.isPocketMode ? "lock.fill" : "lock.open")
                                    .font(.system(size: 24))
                                    .foregroundColor(orientationManager.isPocketMode ? .orange : .gray)
                                Text("Lock")
                                    .font(.system(size: 10))
                                    .foregroundColor(orientationManager.isPocketMode ? .orange : .gray)
                            }
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.gray.opacity(0.1)))
                        }
                    }
                }
                .padding(.horizontal, 10)

                if orientationManager.calibrationNeeded {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Compass calibration recommended")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .onAppear {
            orientationManager.start()
            orientationManager.setupLocationUpdates(
                locationStore: locationStore,
                toneProfileStore: toneProfileStore,
                audioEngine: audioEngine
            )
        }
        .onDisappear {
            orientationManager.stop()
            audioEngine.stopPlayingTone()
        }
        .onReceive(orientationManager.$combinedHeading.throttle(for: .milliseconds(16), scheduler: DispatchQueue.main, latest: true)) { newHeading in
            audioEngine.updatePositions(
                heading: newHeading,
                userLocation: orientationManager.userLocation,
                locations: locationStore.locations
            )
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(audioEngine: audioEngine)
        }
        .sheet(isPresented: $showBottomSheet) {
            BottomSheetContent(
                volume: $audioEngine.volume,
                onVolumeChange: { newVolume in
                    audioEngine.setVolume(newVolume)
                },
                heading: orientationManager.combinedHeading,
                deviceHeading: orientationManager.deviceHeading,
                headOffset: {
                    var offset = orientationManager.deviceHeading - orientationManager.combinedHeading
                    if offset > 180 { offset -= 360 }
                    if offset < -180 { offset += 360 }
                    return offset
                }(),
                headingAccuracy: orientationManager.headingAccuracy,
                isHeadTrackingActive: orientationManager.isHeadTrackingActive,
                selectedDetent: $selectedDetent,
                locations: locationStore.locations,
                isNorthPlaying: audioEngine.isPlaying,
                onNorthToggle: { enabled in
                    if enabled {
                        audioEngine.startPlayingTone()
                    } else {
                        audioEngine.stopPlayingTone()
                    }
                },
                onLocationToggle: { location in
                    locationStore.toggle(location)
                }
            )
            .presentationDetents([.height(180), .height(280), .medium], selection: $selectedDetent)
            .presentationBackgroundInteraction(.enabled)
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
    }

    private func toggleAudio() {
        if audioEngine.isPlaying {
            audioEngine.stopPlayingTone()
        } else {
            audioEngine.startPlayingTone()
        }
    }
}

struct SettingsView: View {
    @ObservedObject var audioEngine: SpatialAudioEngine
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var locationStore: LocationStore
    @EnvironmentObject var toneProfileStore: ToneProfileStore
    @State private var showingAddLocation = false
    @State private var showingAddTone = false
    @State private var editingTone: ToneProfile?
    @State private var editingLocation: Location?

    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false

    var body: some View {
        NavigationView {
            List {
                // Show instructions at top for first launch, otherwise at bottom
                if !hasLaunchedBefore {
                    instructionsSection
                    tipsSection
                }

                // Volume control
                Section("Volume") {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(.secondary)
                            Slider(value: $audioEngine.volume, in: 0...1) { _ in
                                audioEngine.setVolume(audioEngine.volume)
                            }
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.secondary)
                        }
                        Text("\(Int(audioEngine.volume * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Locations") {
                    ForEach(locationStore.locations) { location in
                        LocationRow(
                            location: location,
                            profileName: toneProfileStore.profile(withId: location.toneProfileId)?.name ?? toneProfileStore.defaultProfile.name,
                            onEdit: {
                                editingLocation = location
                            },
                            onDelete: {
                                locationStore.delete(location)
                            }
                        )
                    }

                    Button(action: { showingAddLocation = true }) {
                        Label("Add Location", systemImage: "plus.circle.fill")
                    }
                }

                Section("Tones") {
                    ForEach(toneProfileStore.profiles) { profile in
                        ToneRow(
                            profile: profile,
                            onEdit: {
                                editingTone = profile
                            },
                            onDelete: {
                                toneProfileStore.delete(profile)
                            }
                        )
                    }

                    Button(action: { showingAddTone = true }) {
                        Label("Add Tone", systemImage: "plus.circle.fill")
                    }
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }

                // Show instructions at bottom for returning users
                if hasLaunchedBefore {
                    instructionsSection
                    tipsSection
                }
            }
            .sheet(isPresented: $showingAddLocation) {
                AddLocationView()
            }
            .sheet(isPresented: $showingAddTone) {
                ToneEditorView(editingProfile: nil, audioEngine: audioEngine)
            }
            .sheet(item: $editingTone) { profile in
                ToneEditorView(editingProfile: profile, audioEngine: audioEngine)
            }
            .sheet(item: $editingLocation) { location in
                LocationEditorView(location: location, audioEngine: audioEngine)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onDisappear {
                // Mark as launched after first settings view
                if !hasLaunchedBefore {
                    hasLaunchedBefore = true
                }
            }
        }
    }

    private var instructionsSection: some View {
        Section(header: Text("Instructions")) {
            VStack(alignment: .leading, spacing: 10) {
                Text("1. Connect your AirPods Pro or AirPods Max")
                Text("2. Allow motion tracking when prompted")
                Text("3. Hold your device flat and rotate to calibrate")
                Text("4. Toggle waypoints on the main screen")
                Text("5. The sound will come from the direction of each waypoint")
                Text("6. Use the lock button to fix reference when putting phone in pocket")
            }
            .font(.caption)
            .padding(.vertical, 5)
        }
    }

    private var tipsSection: some View {
        Section(header: Text("Tips")) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Works best outdoors away from magnetic interference",
                      systemImage: "tree")
                Label("Keep device flat for accurate readings",
                      systemImage: "iphone.radiowaves.left.and.right")
                Label("Head tracking requires AirPods Pro or Max",
                      systemImage: "airpodspro")
            }
            .font(.caption)
            .padding(.vertical, 5)
        }
    }
}

struct SliderControl: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let onEditingChanged: (Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}