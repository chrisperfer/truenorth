import AVFoundation
import Combine

class SpatialAudioEngine: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var volume: Float = 0.5
    @Published var sourceX: Float = 0
    @Published var sourceY: Float = 0
    @Published var sourceZ: Float = 20
    
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
        
        // Set initial position
        updateSourcePosition(x: sourceX, y: sourceY, z: sourceZ)
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
        
        // Get the output format from the engine
        let outputFormat = audioEngine.outputNode.outputFormat(forBus: 0)
        print("Output format: \(outputFormat.channelCount) channels at \(outputFormat.sampleRate)Hz")
        
        // For spatial audio, use mono format for the source
        let monoFormat = AVAudioFormat(standardFormatWithSampleRate: outputFormat.sampleRate, channels: 1)!
        
        // Connect with appropriate formats:
        // - Player to Environment: mono (spatial source)
        // - Environment to Output: stereo (spatialized output)
        audioEngine.connect(playerNode, to: environmentNode, format: monoFormat)
        audioEngine.connect(environmentNode, to: audioEngine.outputNode, format: outputFormat)
        
        configureEnvironment()
        
        do {
            try audioEngine.start()
            print("Audio engine started with spatial audio support")
            print("Player -> Environment format: \(monoFormat)")
            print("Environment -> Output format: \(outputFormat)")
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
        print("Environment rendering algorithm: \(environmentNode.renderingAlgorithm)")
        
        // Enable reverb to help with spatialization
        environmentNode.reverbParameters.enable = true
        environmentNode.reverbParameters.level = -20
        environmentNode.reverbParameters.loadFactoryReverbPreset(.mediumHall)
        
        // Set listener at origin facing forward (north)
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environmentNode.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: 0, pitch: 0, roll: 0)
        
        // Position sound source north of listener
        // In AVAudio3D: +X is right, +Y is up, +Z is forward (north)
        playerNode.position = AVAudio3DPoint(x: sourceX, y: sourceY, z: sourceZ)
        playerNode.renderingAlgorithm = .HRTFHQ
        playerNode.volume = volume
        
        // Enable occlusion for more realistic spatial audio
        playerNode.occlusion = 0
        playerNode.obstruction = 0
        
        // Output final format
        print("Environment output format: \(environmentNode.outputFormat(forBus: 0))")
        print("Environment configured: Source at (\(sourceX),\(sourceY),\(sourceZ)), Listener at (0,0,0)")
        print("Player rendering algorithm: \(playerNode.renderingAlgorithm)")
    }
    
    private func generateAudioBuffer() {
        let sampleRate: Double = 44100
        let duration: TimeInterval = 1.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        // Create mono buffer for spatial audio source
        guard let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!, frameCapacity: frameCount) else {
            print("Failed to create audio buffer")
            return
        }
        
        buffer.frameLength = frameCount
        
        // Create a simple clicking pattern
        let clickDuration = 0.02 // 20ms per click
        let clickSpacing = 0.2 // 200ms between clicks
        
        // Generate random seed for consistent white noise
        var seed: UInt64 = 12345
        
        // Fill mono channel
        guard let channelData = buffer.floatChannelData?[0] else {
            print("Failed to get channel data")
            return
        }
        
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
        
        audioBuffer = buffer
        print("Audio buffer generated successfully with mono channel")
    }
    
    func updateSourcePosition(x: Float, y: Float, z: Float) {
        sourceX = x
        sourceY = y
        sourceZ = z
        
        // For real-time position updates with HRTF, we need to update during playback
        playerNode.position = AVAudio3DPoint(x: x, y: y, z: z)
        
        // Also update the reverberation blend to help with distance perception
        playerNode.reverbBlend = min(1.0, sqrt(x*x + y*y + z*z) / 50.0)
        
        print("Source position updated to: (\(x), \(y), \(z)), reverb blend: \(playerNode.reverbBlend)")
    }
    
    func updateOrientation(heading: Double) {
        // Convert heading to radians
        // Heading 0 = North, 90 = East, 180 = South, 270 = West
        // When user faces East (90°), we need to rotate listener -90° so sound stays north
        let angleRadians = -heading * .pi / 180
        
        // AMPLIFIED: Multiply rotation by 5x to make effect more noticeable
        let amplifiedAngle = angleRadians * 5.0
        
        // Rotate listener in opposite direction to keep sound at North
        let listenerOrientation = AVAudio3DAngularOrientation(
            yaw: Float(amplifiedAngle),  // Amplified rotation
            pitch: 0,
            roll: 0
        )
        
        environmentNode.listenerAngularOrientation = listenerOrientation
        
        // Also try moving the source position based on rotation to make it more obvious
        let rotatedX = sin(angleRadians) * 30.0  // Move source left/right based on rotation
        let rotatedZ = cos(angleRadians) * 20.0  // Keep distance but rotate position
        
        // Force the audio graph to update with rotated position
        if audioEngine.isRunning {
            // Update source position to rotate around listener
            playerNode.position = AVAudio3DPoint(x: Float(rotatedX), y: sourceY, z: Float(rotatedZ))
            playerNode.reverbBlend = min(1.0, sqrt(Float(rotatedX*rotatedX) + sourceY*sourceY + Float(rotatedZ*rotatedZ)) / 50.0)
        }
        
        // Debug output - show every 10 degrees for more feedback
        if Int(heading) % 10 == 0 {
            print("Heading: \(Int(heading))°, Amplified yaw: \(Int(amplifiedAngle * 180 / .pi))°")
            print("Listener orientation: yaw=\(listenerOrientation.yaw)")
            print("Rotated source position: (\(rotatedX), \(sourceY), \(rotatedZ))")
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
        
        // Configure audio session for spatial audio
        do {
            let session = AVAudioSession.sharedInstance()
            // Use .playback category with spatial audio options
            try session.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowAirPlay])
            
            // Enable spatial audio playback
            if #available(iOS 15.0, *) {
                try session.setSupportsMultichannelContent(true)
            }
            
            try session.setActive(true)
            print("Audio session configured for spatial audio")
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
        
        // Ensure initial position is set
        playerNode.position = AVAudio3DPoint(x: sourceX, y: sourceY, z: sourceZ)
        playerNode.reverbBlend = min(1.0, sqrt(sourceX*sourceX + sourceY*sourceY + sourceZ*sourceZ) / 50.0)
        
        print("Scheduling buffer...")
        playerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        playerNode.play()
        isPlaying = true
        print("Playback started with position: (\(sourceX), \(sourceY), \(sourceZ))")
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
