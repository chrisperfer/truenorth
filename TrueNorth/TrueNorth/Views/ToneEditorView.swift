import SwiftUI

struct ToneEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var toneProfileStore: ToneProfileStore
    @EnvironmentObject var locationStore: LocationStore

    // The profile being edited (nil for new)
    let editingProfile: ToneProfile?

    // Audio engine for preview
    @ObservedObject var audioEngine: SpatialAudioEngine

    // Form state
    @State private var name: String = ""
    @State private var frequency: Float = 830.0
    @State private var pingDuration: Float = 0.15
    @State private var pingInterval: Float = 5.0
    @State private var echoDelay: Float = 5.0
    @State private var echoAttenuation: Float = 0.28
    @State private var fundamentalAmplitude: Float = 1.0
    @State private var harmonic2Amplitude: Float = 1.0
    @State private var harmonic3Amplitude: Float = 1.0
    @State private var harmonic4Amplitude: Float = 1.0
    @State private var transientFrequency: Float = 3000.0
    @State private var transientAmplitude: Float = 0.3
    @State private var transientDecay: Float = 50.0
    @State private var pingEnvelopeDecay: Float = 3.0
    @State private var echoEnvelopeDecay: Float = 4.0
    @State private var frequencySweepAmount: Float = 0.4

    @State private var isPreviewing = false

    var isEditing: Bool { editingProfile != nil }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.headline)
                        TextField("Tone Name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)

                    // Preview button
                    Button(action: togglePreview) {
                        HStack {
                            Image(systemName: isPreviewing ? "stop.fill" : "play.fill")
                            Text(isPreviewing ? "Stop Preview" : "Preview Tone")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isPreviewing ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    // Tone Parameters
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Tone Parameters")
                            .font(.headline)

                        ToneSlider(label: "Frequency (Hz)", value: $frequency, range: 200...4000)
                        ToneSlider(label: "Ping Duration (s)", value: $pingDuration, range: 0.05...0.5)
                        ToneSlider(label: "Ping Interval (s)", value: $pingInterval, range: 0.5...120)
                        ToneSlider(label: "Echo Delay (s)", value: $echoDelay, range: 0.1...120)
                        ToneSlider(label: "Echo Attenuation", value: $echoAttenuation, range: 0...1)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)

                    // Harmonic Amplitudes
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Harmonic Amplitudes")
                            .font(.headline)

                        ToneSlider(label: "Fundamental", value: $fundamentalAmplitude, range: 0...1)
                        ToneSlider(label: "2nd Harmonic (Octave)", value: $harmonic2Amplitude, range: 0...1)
                        ToneSlider(label: "3rd Harmonic", value: $harmonic3Amplitude, range: 0...1)
                        ToneSlider(label: "4th Harmonic", value: $harmonic4Amplitude, range: 0...1)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)

                    // Transient Click
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Transient Click (Localization)")
                            .font(.headline)

                        ToneSlider(label: "Frequency (Hz)", value: $transientFrequency, range: 1000...8000)
                        ToneSlider(label: "Amplitude", value: $transientAmplitude, range: 0...1)
                        ToneSlider(label: "Decay Rate", value: $transientDecay, range: 10...200)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)

                    // Envelope & Sweep
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Envelope & Frequency Sweep")
                            .font(.headline)

                        ToneSlider(label: "Ping Envelope Decay", value: $pingEnvelopeDecay, range: 1...10)
                        ToneSlider(label: "Echo Envelope Decay", value: $echoEnvelopeDecay, range: 1...10)
                        ToneSlider(label: "Frequency Sweep %", value: $frequencySweepAmount, range: 0...0.5)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle(isEditing ? "Edit Tone" : "New Tone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        stopPreviewIfNeeded()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                loadProfile()
            }
            .onDisappear {
                stopPreviewIfNeeded()
            }
        }
    }

    private func loadProfile() {
        guard let profile = editingProfile else { return }
        name = profile.name
        frequency = profile.frequency
        pingDuration = profile.pingDuration
        pingInterval = profile.pingInterval
        echoDelay = profile.echoDelay
        echoAttenuation = profile.echoAttenuation
        fundamentalAmplitude = profile.fundamentalAmplitude
        harmonic2Amplitude = profile.harmonic2Amplitude
        harmonic3Amplitude = profile.harmonic3Amplitude
        harmonic4Amplitude = profile.harmonic4Amplitude
        transientFrequency = profile.transientFrequency
        transientAmplitude = profile.transientAmplitude
        transientDecay = profile.transientDecay
        pingEnvelopeDecay = profile.pingEnvelopeDecay
        echoEnvelopeDecay = profile.echoEnvelopeDecay
        frequencySweepAmount = profile.frequencySweepAmount
    }

    private func currentProfile() -> ToneProfile {
        ToneProfile(
            id: editingProfile?.id ?? UUID(),
            name: name,
            frequency: frequency,
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
    }

    private func togglePreview() {
        if isPreviewing {
            audioEngine.stopPreview()
            isPreviewing = false
        } else {
            audioEngine.previewTone(profile: currentProfile())
            isPreviewing = true
        }
    }

    private func stopPreviewIfNeeded() {
        if isPreviewing {
            audioEngine.stopPreview()
            isPreviewing = false
        }
    }

    private func saveProfile() {
        stopPreviewIfNeeded()
        let profile = currentProfile()
        if isEditing {
            toneProfileStore.update(profile)
            // Regenerate audio for any waypoints using this profile
            audioEngine.regenerateProfile(profile.id, profile: profile, locations: locationStore.locations)
        } else {
            toneProfileStore.add(profile)
        }
        dismiss()
    }
}

// Simple slider without callback (used in tone editor)
struct ToneSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>

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

            Slider(value: $value, in: range)
        }
    }
}

#Preview {
    ToneEditorView(editingProfile: nil, audioEngine: SpatialAudioEngine())
        .environmentObject(ToneProfileStore())
        .environmentObject(LocationStore())
}
