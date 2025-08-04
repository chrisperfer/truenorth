import AVFoundation
import Combine

class SpatialAudioEngine: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var volume: Float = 0.5
    
    private var audioEngine = AVAudioEngine()
    private var environmentNode = AVAudioEnvironmentNode()
    private var playerNode = AVAudioPlayerNode()
    private var audioBuffer: AVAudioPCMBuffer?
    
    private let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupAudioSession()
        setupAudioEngine()
        generateAudioBuffer()
        testBasicAudio()
    }
    
    private func testBasicAudio() {
        // Test if basic audio works without spatial features
        let testEngine = AVAudioEngine()
        let testPlayer = AVAudioPlayerNode()
        
        testEngine.attach(testPlayer)
        testEngine.connect(testPlayer, to: testEngine.outputNode, format: nil)
        
        do {
            try testEngine.start()
            print("Test audio engine started")
            testEngine.stop()
        } catch {
            print("Test audio engine failed: \(error)")
        }
    }
    
    private func setupAudioSession() {
        // Don't configure audio session here - let it be configured on demand
        print("Audio session will be configured on first play")
    }
    
    private func setupAudioEngine() {
        audioEngine.attach(environmentNode)
        audioEngine.attach(playerNode)
        
        // Use stereo format for compatibility
        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        audioEngine.connect(playerNode, to: environmentNode, format: stereoFormat)
        audioEngine.connect(environmentNode, to: audioEngine.outputNode, format: nil)
        
        configureEnvironment()
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func configureEnvironment() {
        // Configure distance attenuation
        environmentNode.distanceAttenuationParameters.maximumDistance = 100
        environmentNode.distanceAttenuationParameters.referenceDistance = 1
        environmentNode.distanceAttenuationParameters.rolloffFactor = 1
        environmentNode.distanceAttenuationParameters.distanceAttenuationModel = .exponential
        
        // Use HRTF for headphone spatialization
        environmentNode.renderingAlgorithm = .HRTFHQ
        
        // Disable reverb for clearer directional audio
        environmentNode.reverbParameters.enable = false
        
        // Set listener at origin facing forward (north)
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environmentNode.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: 0, pitch: 0, roll: 0)
        
        // Position sound source north of listener
        // In AVAudio3D: +X is right, +Y is up, +Z is forward (north)
        playerNode.position = AVAudio3DPoint(x: 0, y: 0, z: 20)
        playerNode.renderingAlgorithm = .HRTFHQ
        playerNode.volume = volume
        
        // Enable occlusion for more realistic spatial audio
        playerNode.occlusion = 0
        playerNode.obstruction = 0
        
        print("Environment configured: Source at (0,0,20), Listener at (0,0,0)")
    }
    
    private func generateAudioBuffer() {
        let sampleRate: Double = 44100
        let duration: TimeInterval = 1.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        // Use stereo format to match the audio engine setup
        guard let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!, frameCapacity: frameCount) else {
            print("Failed to create audio buffer")
            return
        }
        
        buffer.frameLength = frameCount
        
        // Create a simple clicking pattern
        let clickDuration = 0.02 // 20ms per click
        let clickSpacing = 0.2 // 200ms between clicks
        
        // Generate random seed for consistent white noise
        var seed: UInt64 = 12345
        
        // Fill both channels with the same data
        for channel in 0..<2 {
            guard let channelData = buffer.floatChannelData?[channel] else { 
                print("Failed to get channel data for channel \(channel)")
                continue
            }
            
            // Reset seed for each channel to ensure identical data
            seed = 12345
            
            for frame in 0..<Int(frameCount) {
                let time = Double(frame) / sampleRate
                
                // Generate 3 clicks
                var sample: Float = 0
                for clickIndex in 0..<3 {
                    let clickStart = Double(clickIndex) * clickSpacing
                    let clickEnd = clickStart + clickDuration
                    
                    if time >= clickStart && time < clickEnd {
                        // Simple click sound (bandpass filtered noise)
                        seed = seed &* 1664525 &+ 1013904223
                        let noise = Float(Int32(bitPattern: UInt32(seed >> 32))) / Float(Int32.max)
                        sample = noise * 0.4
                    }
                }
                
                channelData[frame] = sample
            }
        }
        
        audioBuffer = buffer
        print("Audio buffer generated successfully with 2 channels")
    }
    
    func updateOrientation(heading: Double) {
        // Convert heading to radians
        // Heading 0 = North, 90 = East, 180 = South, 270 = West
        // We need to rotate the listener so the sound stays at North
        let angleRadians = heading * .pi / 180
        
        // Rotate listener in opposite direction to keep sound at North
        let listenerOrientation = AVAudio3DAngularOrientation(
            yaw: Float(angleRadians),  // Positive rotation to compensate
            pitch: 0,
            roll: 0
        )
        
        environmentNode.listenerAngularOrientation = listenerOrientation
        
        // Debug output
        if Int(heading) % 30 == 0 {
            print("Heading: \(Int(heading))°, Listener yaw: \(Int(angleRadians * 180 / .pi))°")
        }
    }
    
    func startPlayingTone() {
        guard let buffer = audioBuffer else {
            print("No audio buffer available")
            return
        }
        
        guard !isPlaying else {
            print("Already playing")
            return
        }
        
        // Configure audio session when starting playback
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
        
        if !audioEngine.isRunning {
            do {
                print("Starting audio engine...")
                try audioEngine.start()
                print("Audio engine started successfully")
            } catch {
                print("Failed to start audio engine: \(error)")
                return
            }
        }
        
        print("Scheduling buffer...")
        playerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        playerNode.play()
        isPlaying = true
        print("Playback started")
    }
    
    func stopPlayingTone() {
        playerNode.stop()
        isPlaying = false
    }
    
    func setVolume(_ newVolume: Float) {
        volume = newVolume
        playerNode.volume = volume
    }
    
    deinit {
        audioEngine.stop()
    }
}
