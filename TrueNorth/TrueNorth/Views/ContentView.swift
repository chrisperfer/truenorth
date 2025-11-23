import SwiftUI
import Combine
import AVFoundation

struct ContentView: View {
    @StateObject private var orientationManager = OrientationManager()
    @StateObject private var audioEngine = SpatialAudioEngine()
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 20) {
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
                    
                    // Pocket Mode Lock Button
                    Button(action: {
                        orientationManager.togglePocketMode()
                    }) {
                        Image(systemName: orientationManager.isPocketMode ? "lock.fill" : "lock.open")
                            .font(.system(size: 28))
                            .foregroundColor(orientationManager.isPocketMode ? .orange : .gray)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.gray.opacity(0.1)))
                    }
                }
                .padding()
                
                VStack(spacing: 20) {
                    // Volume control
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "speaker.wave.2")
                            Text("Volume")
                            Spacer()
                            Text("\(Int(audioEngine.volume * 100))%")
                        }
                        .font(.subheadline)
                        
                        Slider(value: $audioEngine.volume, in: 0...1) { _ in
                            audioEngine.setVolume(audioEngine.volume)
                        }
                    }
                    .padding(.horizontal)
                    
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
            .navigationTitle("TrueNorth")
            .navigationBarTitleDisplayMode(.large)
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
    @State private var selectedTab = 0
    
    // 3D Position
    @State private var positionX: Float = 0
    @State private var positionY: Float = 0
    @State private var positionZ: Float = 20
    
    // Audio parameters
    @State private var reverbLevel: Float = -20
    @State private var reverbBlend: Float = 0.0
    @State private var obstruction: Float = 0.0
    @State private var occlusion: Float = 0.0
    
    // Tone parameters
    @State private var frequency: Float = 1500
    @State private var pingDuration: Float = 0.15
    @State private var pingInterval: Float = 1.5
    @State private var echoDelay: Float = 0.3
    @State private var echoAttenuation: Float = 0.3
    
    // Distance attenuation
    @State private var maxDistance: Float = 100
    @State private var referenceDistance: Float = 1
    @State private var rolloffFactor: Float = 1
    
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
                            
                            SliderControl(label: "Ping Interval (s)", value: $pingInterval, range: 0.5...3) { _ in
                                audioEngine.setPingInterval(pingInterval)
                            }
                            
                            SliderControl(label: "Echo Delay (s)", value: $echoDelay, range: 0.1...1) { _ in
                                audioEngine.setEchoDelay(echoDelay)
                            }
                            
                            SliderControl(label: "Echo Attenuation", value: $echoAttenuation, range: 0...1) { _ in
                                audioEngine.setEchoAttenuation(echoAttenuation)
                            }
                            
                            Button("Regenerate Tone") {
                                audioEngine.regenerateTone()
                            }
                            .buttonStyle(.borderedProminent)
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
                        
                        // Presets
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Presets")
                                .font(.headline)
                            
                            HStack(spacing: 10) {
                                Button("North") {
                                    positionX = 0
                                    positionY = 0
                                    positionZ = 20
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
                                    positionZ = 50
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