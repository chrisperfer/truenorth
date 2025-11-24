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
