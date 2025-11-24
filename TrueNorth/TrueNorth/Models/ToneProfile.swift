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
