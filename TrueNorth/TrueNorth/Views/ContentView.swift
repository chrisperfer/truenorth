import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var orientationManager = OrientationManager()
    @StateObject private var audioEngine = SpatialAudioEngine()
    @State private var showingSettings = false
    @State private var testToneGenerator: SimpleToneGenerator?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                CompassView(
                    heading: orientationManager.combinedHeading,
                    isHeadTrackingActive: orientationManager.isHeadTrackingActive,
                    headingAccuracy: orientationManager.headingAccuracy
                )
                .padding()
                
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: audioEngine.isPlaying ? "speaker.wave.3.fill" : "speaker.slash.fill")
                            .font(.system(size: 24))
                            .foregroundColor(audioEngine.isPlaying ? .green : .gray)
                        
                        Button(action: toggleAudio) {
                            Text(audioEngine.isPlaying ? "Stop North Tone" : "Start North Tone")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 15)
                                .background(audioEngine.isPlaying ? Color.red : Color.blue)
                                .cornerRadius(25)
                        }
                    }
                    
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
                    .padding(.horizontal, 40)
                    
                    // Test audio button
                    Button(action: {
                        if testToneGenerator == nil {
                            testToneGenerator = SimpleToneGenerator()
                            testToneGenerator?.playTestTone()
                        } else {
                            testToneGenerator?.stop()
                            testToneGenerator = nil
                        }
                    }) {
                        Text(testToneGenerator != nil ? "Stop Test Tone" : "Test Basic Audio")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    // 3D Position Controls for testing
                    VStack(spacing: 10) {
                        Text("3D Position Test")
                            .font(.headline)
                        
                        HStack {
                            Text("X:")
                            Slider(value: $audioEngine.sourceX, in: -30...30)
                            Text("\(Int(audioEngine.sourceX))")
                                .frame(width: 30)
                        }
                        
                        HStack {
                            Text("Y:")
                            Slider(value: $audioEngine.sourceY, in: -10...10)
                            Text("\(Int(audioEngine.sourceY))")
                                .frame(width: 30)
                        }
                        
                        HStack {
                            Text("Z:")
                            Slider(value: $audioEngine.sourceZ, in: -30...30)
                            Text("\(Int(audioEngine.sourceZ))")
                                .frame(width: 30)
                        }
                        
                        Button("Reset to North") {
                            audioEngine.updateSourcePosition(x: 0, y: 0, z: 20)
                        }
                        .font(.caption)
                        
                        Text("X=right/left, Y=up/down, Z=forward/back")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
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
                
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(icon: "location.north", 
                           label: "Device Heading", 
                           value: "\(Int(orientationManager.deviceHeading))°")
                    
                    InfoRow(icon: "airpodspro", 
                           label: "Head Tracking", 
                           value: orientationManager.isHeadTrackingActive ? "Active" : "Inactive")
                    
                    InfoRow(icon: "arrow.triangle.merge", 
                           label: "Combined Heading", 
                           value: "\(Int(orientationManager.combinedHeading))°")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(15)
                .padding(.horizontal)
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
        .onReceive(orientationManager.$combinedHeading.throttle(for: .milliseconds(50), scheduler: DispatchQueue.main, latest: true)) { newHeading in
            audioEngine.updateOrientation(heading: newHeading)
        }
        .onChange(of: audioEngine.sourceX) { _ in updateAudioPosition() }
        .onChange(of: audioEngine.sourceY) { _ in updateAudioPosition() }
        .onChange(of: audioEngine.sourceZ) { _ in updateAudioPosition() }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    private func toggleAudio() {
        if audioEngine.isPlaying {
            audioEngine.stopPlayingTone()
        } else {
            audioEngine.startPlayingTone()
        }
    }
    
    private func updateAudioPosition() {
        audioEngine.updateSourcePosition(
            x: audioEngine.sourceX,
            y: audioEngine.sourceY,
            z: audioEngine.sourceZ
        )
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 25)
                .foregroundColor(.blue)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
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
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}