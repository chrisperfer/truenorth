import AVFoundation

class SimpleToneGenerator {
    private var audioEngine = AVAudioEngine()
    private var tonePlayer = AVAudioPlayerNode()
    private var mixer: AVAudioMixerNode
    
    init() {
        mixer = audioEngine.mainMixerNode
        setupAudio()
    }
    
    private func setupAudio() {
        // Attach and connect nodes
        audioEngine.attach(tonePlayer)
        audioEngine.connect(tonePlayer, to: mixer, format: nil)
        
        // Start engine
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            try audioEngine.start()
            print("Simple audio engine started")
        } catch {
            print("Simple audio setup error: \(error)")
        }
    }
    
    func playTestTone() {
        // Create simple sine wave
        let sampleRate: Double = 44100
        let amplitude: Float = 0.25
        let frequency: Double = 440
        let duration: Double = 1.0
        
        let frameCount = Int(sampleRate * duration)
        
        // Get the output format from the audio engine
        let outputFormat = audioEngine.outputNode.outputFormat(forBus: 0)
        let channelCount = outputFormat.channelCount
        
        guard channelCount > 0 else {
            print("Invalid channel count")
            return
        }
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            print("Failed to create buffer")
            return
        }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        // Fill all channels with the same data
        for channel in 0..<Int(channelCount) {
            if let channelData = buffer.floatChannelData?[channel] {
                for frame in 0..<frameCount {
                    let value = sinf(Float(2.0 * Double.pi * frequency * Double(frame) / sampleRate))
                    channelData[frame] = value * amplitude
                }
            }
        }
        
        tonePlayer.scheduleBuffer(buffer, at: nil, options: .loops)
        tonePlayer.play()
        print("Test tone playing with \(channelCount) channels")
    }
    
    func stop() {
        tonePlayer.stop()
    }
}