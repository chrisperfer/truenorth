import SwiftUI
import Combine
import AVFoundation

struct ContentView: View {
    @StateObject private var orientationManager = OrientationManager()
    @StateObject private var audioEngine = SpatialAudioEngine()
    @State private var showingSettings = false
    
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
                        }(),
                        volume: $audioEngine.volume,
                        onVolumeChange: { newVolume in
                            audioEngine.setVolume(newVolume)
                        }
                    )

                    HStack(spacing: 20) {
                        // Head Tracking Calibration Button
                        Button(action: {
                            // TODO: Re-add calibrateHeadTracking() method to OrientationManager
                            // orientationManager.calibrateHeadTracking()
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

                VStack(spacing: 15) {
                    // Tone controls list
                    VStack(spacing: 0) {
                        // North tone
                        HStack {
                            Text("North")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: toggleAudio) {
                                Image(systemName: audioEngine.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(audioEngine.isPlaying ? .red : .blue)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Future tones will be added here with similar layout
                    }
                    .padding(.horizontal)
                }

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
        }
        .onDisappear {
            orientationManager.stop()
            audioEngine.stopPlayingTone()
        }
        .onReceive(orientationManager.$combinedHeading.throttle(for: .milliseconds(16), scheduler: DispatchQueue.main, latest: true)) { newHeading in
            audioEngine.updateOrientation(heading: newHeading)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(audioEngine: audioEngine)
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
    @State private var selectedTab = 0
    @State private var showingAddLocation = false
    @State private var showNorthDirection = true
    
    // 3D Position
    @State private var positionX: Float = 0
    @State private var positionY: Float = 0
    @State private var positionZ: Float = -20

    // Audio parameters
    @State private var reverbLevel: Float = -20
    @State private var reverbBlend: Float = 0.0
    @State private var obstruction: Float = 0.0
    @State private var occlusion: Float = 0.0

    // Tone parameters
    @State private var frequency: Float = 830.0
    @State private var pingDuration: Float = 0.15
    @State private var pingInterval: Float = 5.0
    @State private var echoDelay: Float = 5.0
    @State private var echoAttenuation: Float = 0.28

    // Distance attenuation
    @State private var maxDistance: Float = 282.88
    @State private var referenceDistance: Float = 1.08
    @State private var rolloffFactor: Float = 0.70

    // Harmonic amplitudes
    @State private var fundamentalAmplitude: Float = 1.0
    @State private var harmonic2Amplitude: Float = 1.0
    @State private var harmonic3Amplitude: Float = 1.0
    @State private var harmonic4Amplitude: Float = 1.0

    // Transient parameters
    @State private var transientFrequency: Float = 3000.0
    @State private var transientAmplitude: Float = 0.3
    @State private var transientDecay: Float = 50.0

    // Envelope parameters
    @State private var pingEnvelopeDecay: Float = 3.0
    @State private var echoEnvelopeDecay: Float = 4.0
    @State private var frequencySweepAmount: Float = 0.4
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // General Tab
                List {
                    Section(header: Text("About")) {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section(header: Text("Instructions")) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("1. Connect your AirPods Pro or AirPods Max")
                            Text("2. Allow motion tracking when prompted")
                            Text("3. Hold your device flat and rotate to calibrate")
                            Text("4. Press 'Start North Tone' to begin")
                            Text("5. The sound will always come from North")
                            Text("6. Use the lock button to fix north reference when putting phone in pocket")
                        }
                        .font(.caption)
                        .padding(.vertical, 5)
                    }
                    
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
                }
                .tabItem {
                    Image(systemName: "info.circle")
                    Text("General")
                }
                .tag(0)
                
                // Experimental Tab
                ScrollView {
                    VStack(spacing: 30) {
                        // 3D Position Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("3D Position")
                                .font(.headline)
                            
                            SliderControl(label: "X (Left/Right)", value: $positionX, range: -50...50) { _ in
                                audioEngine.updateSourcePosition(x: positionX, y: positionY, z: positionZ)
                            }
                            
                            SliderControl(label: "Y (Up/Down)", value: $positionY, range: -50...50) { _ in
                                audioEngine.updateSourcePosition(x: positionX, y: positionY, z: positionZ)
                            }
                            
                            SliderControl(label: "Z (Forward/Back)", value: $positionZ, range: -50...50) { _ in
                                audioEngine.updateSourcePosition(x: positionX, y: positionY, z: positionZ)
                            }
                            
                            Text("Distance: \(String(format: "%.1f", sqrt(positionX*positionX + positionY*positionY + positionZ*positionZ))) units")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Audio Effects Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Audio Effects")
                                .font(.headline)
                            
                            SliderControl(label: "Reverb Level (dB)", value: $reverbLevel, range: -60...0) { _ in
                                audioEngine.setReverbLevel(reverbLevel)
                            }
                            
                            SliderControl(label: "Reverb Blend", value: $reverbBlend, range: 0...1) { _ in
                                audioEngine.setReverbBlend(reverbBlend)
                            }
                            
                            SliderControl(label: "Obstruction", value: $obstruction, range: 0...1) { _ in
                                audioEngine.setObstruction(obstruction)
                            }
                            
                            SliderControl(label: "Occlusion", value: $occlusion, range: 0...1) { _ in
                                audioEngine.setOcclusion(occlusion)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Tone Parameters Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Tone Parameters")
                                .font(.headline)

                            SliderControl(label: "Frequency (Hz)", value: $frequency, range: 200...4000) { _ in
                                audioEngine.setToneFrequency(frequency)
                            }

                            SliderControl(label: "Ping Duration (s)", value: $pingDuration, range: 0.05...0.5) { _ in
                                audioEngine.setPingDuration(pingDuration)
                            }

                            SliderControl(label: "Ping Interval (s)", value: $pingInterval, range: 0.5...120) { _ in
                                audioEngine.setPingInterval(pingInterval)
                            }

                            SliderControl(label: "Echo Delay (s)", value: $echoDelay, range: 0.1...120) { _ in
                                audioEngine.setEchoDelay(echoDelay)
                            }

                            SliderControl(label: "Echo Attenuation", value: $echoAttenuation, range: 0...1) { _ in
                                audioEngine.setEchoAttenuation(echoAttenuation)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Distance Attenuation Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Distance Attenuation")
                                .font(.headline)

                            SliderControl(label: "Max Distance", value: $maxDistance, range: 10...500) { _ in
                                audioEngine.setDistanceAttenuation(
                                    maxDistance: maxDistance,
                                    referenceDistance: referenceDistance,
                                    rolloffFactor: rolloffFactor
                                )
                            }

                            SliderControl(label: "Reference Distance", value: $referenceDistance, range: 0.1...10) { _ in
                                audioEngine.setDistanceAttenuation(
                                    maxDistance: maxDistance,
                                    referenceDistance: referenceDistance,
                                    rolloffFactor: rolloffFactor
                                )
                            }

                            SliderControl(label: "Rolloff Factor", value: $rolloffFactor, range: 0...5) { _ in
                                audioEngine.setDistanceAttenuation(
                                    maxDistance: maxDistance,
                                    referenceDistance: referenceDistance,
                                    rolloffFactor: rolloffFactor
                                )
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)

                        // Harmonic & Spectral Controls Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Harmonic Amplitudes")
                                .font(.headline)

                            SliderControl(label: "Fundamental", value: $fundamentalAmplitude, range: 0...1) { _ in
                                audioEngine.setFundamentalAmplitude(fundamentalAmplitude)
                            }

                            SliderControl(label: "2nd Harmonic (Octave)", value: $harmonic2Amplitude, range: 0...1) { _ in
                                audioEngine.setHarmonic2Amplitude(harmonic2Amplitude)
                            }

                            SliderControl(label: "3rd Harmonic", value: $harmonic3Amplitude, range: 0...1) { _ in
                                audioEngine.setHarmonic3Amplitude(harmonic3Amplitude)
                            }

                            SliderControl(label: "4th Harmonic", value: $harmonic4Amplitude, range: 0...1) { _ in
                                audioEngine.setHarmonic4Amplitude(harmonic4Amplitude)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)

                        // Transient Click Controls Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Transient Click (Localization)")
                                .font(.headline)

                            SliderControl(label: "Frequency (Hz)", value: $transientFrequency, range: 1000...8000) { _ in
                                audioEngine.setTransientFrequency(transientFrequency)
                            }

                            SliderControl(label: "Amplitude", value: $transientAmplitude, range: 0...1) { _ in
                                audioEngine.setTransientAmplitude(transientAmplitude)
                            }

                            SliderControl(label: "Decay Rate", value: $transientDecay, range: 10...200) { _ in
                                audioEngine.setTransientDecay(transientDecay)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)

                        // Envelope & Sweep Controls Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Envelope & Frequency Sweep")
                                .font(.headline)

                            SliderControl(label: "Ping Envelope Decay", value: $pingEnvelopeDecay, range: 1...10) { _ in
                                audioEngine.setPingEnvelopeDecay(pingEnvelopeDecay)
                            }

                            SliderControl(label: "Echo Envelope Decay", value: $echoEnvelopeDecay, range: 1...10) { _ in
                                audioEngine.setEchoEnvelopeDecay(echoEnvelopeDecay)
                            }

                            SliderControl(label: "Frequency Sweep %", value: $frequencySweepAmount, range: 0...0.5) { _ in
                                audioEngine.setFrequencySweepAmount(frequencySweepAmount)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Presets
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Presets")
                                .font(.headline)
                            
                            HStack(spacing: 10) {
                                Button("North") {
                                    positionX = 0
                                    positionY = 0
                                    positionZ = -20
                                    audioEngine.updateSourcePosition(x: positionX, y: positionY, z: positionZ)
                                }
                                .buttonStyle(.bordered)

                                Button("East") {
                                    positionX = 20
                                    positionY = 0
                                    positionZ = 0
                                    audioEngine.updateSourcePosition(x: positionX, y: positionY, z: positionZ)
                                }
                                .buttonStyle(.bordered)

                                Button("Above") {
                                    positionX = 0
                                    positionY = 20
                                    positionZ = 0
                                    audioEngine.updateSourcePosition(x: positionX, y: positionY, z: positionZ)
                                }
                                .buttonStyle(.bordered)

                                Button("Far") {
                                    positionX = 0
                                    positionY = 0
                                    positionZ = -50
                                    audioEngine.updateSourcePosition(x: positionX, y: positionY, z: positionZ)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .padding()
                }
                .tabItem {
                    Image(systemName: "slider.horizontal.3")
                    Text("Experimental")
                }
                .tag(1)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Regenerate") {
                        audioEngine.regenerateTone()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Initialize sliders with current values
            positionX = audioEngine.sourceX
            positionY = audioEngine.sourceY
            positionZ = audioEngine.sourceZ
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