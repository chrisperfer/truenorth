import AVFoundation
import Combine

class SpatialAudioEngine: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var volume: Float = 0.5
    
    // Position for sound source (now public for experimental view)
    @Published var sourceX: Float = 0
    @Published var sourceY: Float = 0
    @Published var sourceZ: Float = 20
    
    // Tone parameters
    private var toneFrequency: Float = 1500
    private var pingDuration: Float = 0.15
    private var pingInterval: Float = 1.5
    private var echoDelay: Float = 0.3
    private var echoAttenuation: Float = 0.3
    
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
        print("Environment rendering algorithm set to: .HRTFHQ")

        // Validate that HRTF is actually active
        if environmentNode.renderingAlgorithm != .HRTFHQ {
            print("⚠️ WARNING: HRTF not available on this device - spatial audio may not work properly")
            print("   Actual rendering algorithm: \(environmentNode.renderingAlgorithm)")
        } else {
            print("✓ HRTF rendering confirmed active")
        }

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
        let duration: TimeInterval = 2.0  // 2 second loop
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        // Create mono buffer for spatial audio source
        guard let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!, frameCapacity: frameCount) else {
            print("Failed to create audio buffer")
            return
        }
        
        buffer.frameLength = frameCount
        
        // Submarine ping parameters (use class properties)
        let pingFrequency: Double = Double(toneFrequency)  // Use configurable frequency
        let pingDuration: Double = Double(self.pingDuration)
        let pingInterval: Double = Double(self.pingInterval)
        let echoDelay: Double = Double(self.echoDelay)
        let echoAttenuation: Float = self.echoAttenuation
        
        // Fill mono channel
        guard let channelData = buffer.floatChannelData?[0] else {
            print("Failed to get channel data")
            return
        }
        
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            var sample: Float = 0
            
            // Calculate position within the ping interval
            let cycleTime = time.truncatingRemainder(dividingBy: pingInterval)
            
            // Main ping
            if cycleTime < pingDuration {
                let pingTime = cycleTime / pingDuration
                // Exponential envelope for more natural ping sound
                let envelope = Float(exp(-3.0 * pingTime))
                // Sine wave with slight frequency sweep downward
                let frequency = pingFrequency * (1.0 - 0.1 * pingTime)
                sample = sin(Float(2.0 * .pi * frequency * cycleTime)) * envelope * 0.7
            }
            
            // Echo
            let echoStart = echoDelay
            let echoEnd = echoDelay + pingDuration
            if cycleTime >= echoStart && cycleTime < echoEnd {
                let echoTime = (cycleTime - echoStart) / pingDuration
                let envelope = Float(exp(-4.0 * echoTime)) * echoAttenuation
                let frequency = pingFrequency * 0.9 * (1.0 - 0.15 * echoTime)
                sample += sin(Float(2.0 * .pi * frequency * (cycleTime - echoStart))) * envelope
            }
            
            // Apply soft clipping to prevent harsh distortion
            sample = tanh(sample)
            
            channelData[frame] = sample
        }
        
        audioBuffer = buffer
        print("Audio buffer generated: Submarine ping sound (1.5kHz, 150ms ping, 1.5s interval)")
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
        let angleRadians = Float(heading * .pi / 180)

        // POSITION-BASED APPROACH: Place sound source in the direction of north
        // relative to user's current heading
        // This is more direct than listener rotation
        let distance: Float = 20.0  // meters
        let northX = sin(angleRadians) * distance  // East-west component
        let northZ = cos(angleRadians) * distance  // North-south component

        if audioEngine.isRunning {
            playerNode.position = AVAudio3DPoint(x: northX, y: sourceY, z: northZ)
            playerNode.reverbBlend = min(1.0, distance / 50.0)
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
    
    // MARK: - Experimental Controls
    
    func setReverbLevel(_ level: Float) {
        environmentNode.reverbParameters.level = level
    }
    
    func setReverbBlend(_ blend: Float) {
        playerNode.reverbBlend = blend
    }
    
    func setObstruction(_ value: Float) {
        playerNode.obstruction = value
    }
    
    func setOcclusion(_ value: Float) {
        playerNode.occlusion = value
    }
    
    func setToneFrequency(_ frequency: Float) {
        toneFrequency = frequency
    }
    
    func setPingDuration(_ duration: Float) {
        pingDuration = duration
    }
    
    func setPingInterval(_ interval: Float) {
        pingInterval = interval
    }
    
    func setEchoDelay(_ delay: Float) {
        echoDelay = delay
    }
    
    func setEchoAttenuation(_ attenuation: Float) {
        echoAttenuation = attenuation
    }
    
    func setDistanceAttenuation(maxDistance: Float, referenceDistance: Float, rolloffFactor: Float) {
        environmentNode.distanceAttenuationParameters.maximumDistance = maxDistance
        environmentNode.distanceAttenuationParameters.referenceDistance = referenceDistance
        environmentNode.distanceAttenuationParameters.rolloffFactor = rolloffFactor
    }
    
    func regenerateTone() {
        let wasPlaying = isPlaying
        if wasPlaying {
            stopPlayingTone()
        }
        
        generateAudioBuffer()
        
        if wasPlaying {
            startPlayingTone()
        }
    }
    
    deinit {
        audioEngine.stop()
    }
}
