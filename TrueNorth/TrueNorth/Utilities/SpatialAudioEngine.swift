import AVFoundation
import Combine
import CoreLocation

class SpatialAudioEngine: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var volume: Float = 1.0  // Increased to match other audio sources
    
    // Position for sound source (now public for experimental view)
    // Optimized distance: 4m for better presence and spatial localization
    @Published var sourceX: Float = 0
    @Published var sourceY: Float = 0
    @Published var sourceZ: Float = -4
    
    // Tone parameters
    private var toneFrequency: Float = 830.0
    private var pingDuration: Float = 0.15
    private var pingInterval: Float = 5.0
    private var echoDelay: Float = 5.0
    private var echoAttenuation: Float = 0.28

    // Harmonic parameters
    private var fundamentalAmplitude: Float = 1.0
    private var harmonic2Amplitude: Float = 1.0
    private var harmonic3Amplitude: Float = 1.0
    private var harmonic4Amplitude: Float = 1.0

    // Transient parameters
    private var transientFrequency: Float = 3000.0
    private var transientAmplitude: Float = 0.3
    private var transientDecay: Float = 50.0

    // Envelope parameters
    private var pingEnvelopeDecay: Float = 3.0
    private var echoEnvelopeDecay: Float = 4.0
    private var frequencySweepAmount: Float = 0.4  // 40% sweep
    
    private var audioEngine = AVAudioEngine()
    private var environmentNode = AVAudioEnvironmentNode()
    private var playerNode = AVAudioPlayerNode()
    private var audioBuffer: AVAudioPCMBuffer?
    
    private let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    private var cancellables = Set<AnyCancellable>()

    // Multi-source management
    private var playerNodes: [UUID: AVAudioPlayerNode] = [:]
    private var audioBuffers: [UUID: AVAudioPCMBuffer] = [:]

    // North special case
    private let northId = UUID() // Static identifier for north direction
    
    init() {
        setupAudioSession()
        setupAudioEngine()

        // Generate audio buffer asynchronously to avoid blocking startup
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.generateAudioBuffer()
        }

        // Initialize north as the default source
        let defaultProfile = ToneProfileStore().defaultProfile
        _ = createPlayerNode(for: northId, profile: defaultProfile)
    }
    
    // Removed testBasicAudio() - it was causing slow startup by creating/starting/stopping
    // a whole audio engine on every app launch for no functional benefit
    
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
        // Optimized for 4m source distance for better front/back differentiation
        // Reference distance at 2m means sound is full volume within 2m, then attenuates
        // Rolloff factor of 1.0 provides moderate attenuation - slightly louder in front, softer behind
        environmentNode.distanceAttenuationParameters.maximumDistance = 50.0
        environmentNode.distanceAttenuationParameters.referenceDistance = 2.0
        environmentNode.distanceAttenuationParameters.rolloffFactor = 1.0
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
        // Using .smallRoom for shorter decay time and better directional clarity
        // Shorter decay prevents blurring of spatial cues while maintaining externalization
        environmentNode.reverbParameters.enable = true
        environmentNode.reverbParameters.level = -20
        environmentNode.reverbParameters.loadFactoryReverbPreset(.smallRoom)
        
        // Set listener at origin facing forward (north)
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environmentNode.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: 0, pitch: 0, roll: 0)
        
        // Position sound source north of listener
        // In AVAudio3D: +X is right, +Y is up, -Z is forward (north)
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
    
    private func generateAudioBuffer(for profile: ToneProfile) -> AVAudioPCMBuffer? {
        let sampleRate: Double = 44100
        let duration: TimeInterval = max(Double(profile.pingInterval), 2.0)
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!,
            frameCapacity: frameCount
        ) else {
            print("Failed to create audio buffer")
            return nil
        }

        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData?[0] else {
            print("Failed to get channel data")
            return nil
        }

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            var sample: Float = 0

            let cycleTime = time.truncatingRemainder(dividingBy: Double(profile.pingInterval))

            // Main ping with harmonics
            if cycleTime < Double(profile.pingDuration) {
                let pingTime = cycleTime / Double(profile.pingDuration)
                let envelope = Float(exp(-Double(profile.pingEnvelopeDecay) * pingTime))
                let frequency = Double(profile.frequency) * (1.0 - Double(profile.frequencySweepAmount) * pingTime)

                let fundamental = sin(Float(2.0 * .pi * frequency * cycleTime)) * envelope * profile.fundamentalAmplitude
                let harmonic2 = sin(Float(2.0 * .pi * frequency * 2.0 * cycleTime)) * envelope * profile.harmonic2Amplitude
                let harmonic3 = sin(Float(2.0 * .pi * frequency * 3.0 * cycleTime)) * envelope * profile.harmonic3Amplitude
                let harmonic4 = sin(Float(2.0 * .pi * frequency * 4.0 * cycleTime)) * envelope * profile.harmonic4Amplitude

                let transientEnvelope = Float(exp(-Double(profile.transientDecay) * pingTime))
                let transient = sin(Float(2.0 * .pi * Double(profile.transientFrequency) * cycleTime)) * transientEnvelope * profile.transientAmplitude

                sample = fundamental + harmonic2 + harmonic3 + harmonic4 + transient
            }

            // Echo
            let echoStart = Double(profile.echoDelay)
            let echoEnd = echoStart + Double(profile.pingDuration)
            if cycleTime >= echoStart && cycleTime < echoEnd {
                let echoTime = (cycleTime - echoStart) / Double(profile.pingDuration)
                let envelope = Float(exp(-Double(profile.echoEnvelopeDecay) * echoTime)) * profile.echoAttenuation
                let frequency = Double(profile.frequency) * 0.9 * (1.0 - Double(profile.frequencySweepAmount) * 1.5 * echoTime)

                let fundamental = sin(Float(2.0 * .pi * frequency * (cycleTime - echoStart))) * envelope * profile.fundamentalAmplitude
                let harmonic2 = sin(Float(2.0 * .pi * frequency * 2.0 * (cycleTime - echoStart))) * envelope * profile.harmonic2Amplitude * 0.75
                let harmonic3 = sin(Float(2.0 * .pi * frequency * 3.0 * (cycleTime - echoStart))) * envelope * profile.harmonic3Amplitude * 0.6

                sample += fundamental + harmonic2 + harmonic3
            }

            sample = tanh(sample)
            channelData[frame] = sample
        }

        return buffer
    }

    private func generateAudioBuffer() {
        // Create default tone profile from current instance properties
        let profile = ToneProfile(
            name: "Default",
            frequency: toneFrequency,
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

        audioBuffer = generateAudioBuffer(for: profile)

        if audioBuffer != nil {
            print("Audio buffer generated: Enhanced spatial ping")
        }
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
        // OPTIMIZED: 4m distance for better presence and externalization (was 20m)
        // Research shows 1-5m is optimal for spatial audio localization
        let distance: Float = 4.0  // meters
        // CRITICAL: X-axis needs to be NEGATED for correct left/right positioning
        // When facing east (90°), north should be to the LEFT (negative X), not right
        let northX = -sin(angleRadians) * distance  // East-west component (NEGATED!)
        let northZ = -cos(angleRadians) * distance  // North-south component (negative Z = forward)

        // Use Y-axis (elevation) to disambiguate north vs south
        // North = elevated (like north star), South = at/below ear level
        // This makes it easy to distinguish: ahead+above = north, behind+level = south
        let elevationFactor: Float = 1.5  // Height variation (scaled with distance)
        let northY = cos(angleRadians) * elevationFactor  // Positive when facing north, negative when facing south

        if audioEngine.isRunning {
            playerNode.position = AVAudio3DPoint(x: northX, y: northY, z: northZ)
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
        
        // Configure audio session for spatial audio with background and mixing support
        do {
            let session = AVAudioSession.sharedInstance()
            // Use .playback category with options for background, mixing, and spatial audio
            // .mixWithOthers allows concurrent audio (music, podcasts, directions)
            // .allowBluetoothA2DP allows AirPods Pro spatial audio
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetoothA2DP, .allowAirPlay])

            // Enable spatial audio playback
            if #available(iOS 15.0, *) {
                try session.setSupportsMultichannelContent(true)
            }

            try session.setActive(true)
            print("Audio session configured for background spatial playback with mixing")
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

        // Start all multi-source player nodes
        for (id, node) in playerNodes {
            if !node.isPlaying {
                node.play()
                print("Started player node for \(id)")
            }
        }

        isPlaying = true
        print("Playback started with position: (\(sourceX), \(sourceY), \(sourceZ))")
    }
    
    func stopPlayingTone() {
        playerNode.stop()

        // Stop all multi-source player nodes
        for (id, node) in playerNodes {
            node.stop()
            print("Stopped player node for \(id)")
        }

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

    // Harmonic controls
    func setFundamentalAmplitude(_ amplitude: Float) {
        fundamentalAmplitude = amplitude
    }

    func setHarmonic2Amplitude(_ amplitude: Float) {
        harmonic2Amplitude = amplitude
    }

    func setHarmonic3Amplitude(_ amplitude: Float) {
        harmonic3Amplitude = amplitude
    }

    func setHarmonic4Amplitude(_ amplitude: Float) {
        harmonic4Amplitude = amplitude
    }

    // Transient controls
    func setTransientFrequency(_ frequency: Float) {
        transientFrequency = frequency
    }

    func setTransientAmplitude(_ amplitude: Float) {
        transientAmplitude = amplitude
    }

    func setTransientDecay(_ decay: Float) {
        transientDecay = decay
    }

    // Envelope controls
    func setPingEnvelopeDecay(_ decay: Float) {
        pingEnvelopeDecay = decay
    }

    func setEchoEnvelopeDecay(_ decay: Float) {
        echoEnvelopeDecay = decay
    }

    func setFrequencySweepAmount(_ amount: Float) {
        frequencySweepAmount = amount
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

    // MARK: - Multi-Source Management

    private func createPlayerNode(for id: UUID, profile: ToneProfile) -> AVAudioPlayerNode? {
        let node = AVAudioPlayerNode()

        // Generate buffer for this profile
        guard let buffer = generateAudioBuffer(for: profile) else {
            print("Failed to generate buffer for \(id)")
            return nil
        }

        // Attach and connect node
        audioEngine.attach(node)

        let monoFormat = AVAudioFormat(
            standardFormatWithSampleRate: audioEngine.outputNode.outputFormat(forBus: 0).sampleRate,
            channels: 1
        )!

        audioEngine.connect(node, to: environmentNode, format: monoFormat)

        // Configure node
        node.position = AVAudio3DPoint(x: 0, y: 0, z: -4)
        node.renderingAlgorithm = .HRTFHQ
        node.volume = volume

        // Schedule looping playback
        node.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)

        // Store
        playerNodes[id] = node
        audioBuffers[id] = buffer

        print("Created player node for \(id)")
        return node
    }

    private func removePlayerNode(for id: UUID) {
        guard let node = playerNodes[id] else { return }

        node.stop()
        audioEngine.detach(node)
        playerNodes.removeValue(forKey: id)
        audioBuffers.removeValue(forKey: id)

        print("Removed player node for \(id)")
    }

    func updateLocations(_ locations: [Location], toneProfileStore: ToneProfileStore) {
        // Get IDs of enabled locations
        let enabledIds = Set(locations.filter { $0.isEnabled }.map { $0.id })

        // Remove nodes for disabled/deleted locations
        let currentIds = Set(playerNodes.keys).subtracting([northId])
        let toRemove = currentIds.subtracting(enabledIds)
        toRemove.forEach { removePlayerNode(for: $0) }

        // Add nodes for newly enabled locations
        let toAdd = enabledIds.subtracting(currentIds)
        for id in toAdd {
            guard let location = locations.first(where: { $0.id == id }),
                  let profile = toneProfileStore.profile(withId: location.toneProfileId),
                  let node = createPlayerNode(for: id, profile: profile) else {
                continue
            }

            // Start playback if engine is running
            if audioEngine.isRunning && isPlaying {
                node.play()
            }
        }
    }

    func updatePositions(
        heading: Double,
        userLocation: CLLocationCoordinate2D?,
        locations: [Location]
    ) {
        guard audioEngine.isRunning else { return }

        // Update north position (existing behavior)
        updateNorthPosition(heading: heading)

        // Update waypoint positions
        guard let userLocation = userLocation else { return }

        for location in locations where location.isEnabled {
            guard let node = playerNodes[location.id] else { continue }

            let bearing = BearingCalculator.calculateBearing(
                from: userLocation,
                to: location.coordinate
            )
            let relativeBearing = BearingCalculator.relativeBearing(
                userHeading: heading,
                destinationBearing: bearing
            )

            let position = calculateAudioPosition(relativeBearing: relativeBearing)
            node.position = position
        }
    }

    private func updateNorthPosition(heading: Double) {
        let angleRadians = Float(heading * .pi / 180)
        let distance: Float = 4.0
        let northX = -sin(angleRadians) * distance
        let northZ = -cos(angleRadians) * distance
        let elevationFactor: Float = 1.5
        let northY = cos(angleRadians) * elevationFactor

        if let northNode = playerNodes[northId] {
            northNode.position = AVAudio3DPoint(x: northX, y: northY, z: northZ)
        } else {
            // Fallback to original playerNode for backward compatibility
            playerNode.position = AVAudio3DPoint(x: northX, y: northY, z: northZ)
        }
    }

    private func calculateAudioPosition(relativeBearing: Double) -> AVAudio3DPoint {
        let angleRadians = Float(relativeBearing * .pi / 180)
        let distance: Float = 4.0
        let x = sin(angleRadians) * distance
        let z = -cos(angleRadians) * distance
        let elevationFactor: Float = 1.5
        let y = cos(angleRadians) * elevationFactor

        return AVAudio3DPoint(x: x, y: y, z: z)
    }

    deinit {
        audioEngine.stop()
    }
}
