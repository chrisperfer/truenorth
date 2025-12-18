import Foundation
import CoreMotion
import CoreLocation
import Combine

class OrientationManager: NSObject, ObservableObject {
    @Published var deviceHeading: Double = 0  // Raw device heading
    @Published var smoothedDeviceHeading: Double = 0  // Smoothed for UI display
    @Published var headRotation: CMAttitude?
    @Published var combinedHeading: Double = 0
    @Published var isHeadTrackingActive: Bool = false
    @Published var headingAccuracy: Double = -1
    @Published var calibrationNeeded: Bool = false
    @Published var isPocketMode: Bool = false
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined

    private let motionManager = CMHeadphoneMotionManager()
    private let locationManager = CLLocationManager()
    private let deviceMotion = CMMotionManager()
    private var headTrackingTimer: Timer?

    private let smoothingFactor: Double = 0.4  // Faster response while maintaining smoothness
    private var previousHeading: Double = 0
    private var previousDeviceHeading: Double = 0

    // Pocket mode variables
    private var lockedNorthReference: Double = 0
    private var initialHeadOrientation: CMAttitude?
    private var lastStableHeading: Double = 0
    private var headingStabilityCount: Int = 0
    private let stabilityThreshold: Double = 5.0 // degrees
    private let stabilityCountRequired: Int = 5

    // Location and tone profile stores
    private var locationStore: LocationStore?
    private var toneProfileStore: ToneProfileStore?
    private var locationCancellable: AnyCancellable?
    private var audioEngine: SpatialAudioEngine?

    override init() {
        super.init()
        setupLocationManager()
        setupHeadTracking()
        setupDeviceMotion()
    }
    
    func start() {
        locationManager.startUpdatingHeading()
        startHeadTracking()
        startDeviceMotionTracking()
    }
    
    func stop() {
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
        stopHeadTracking()
        stopDeviceMotionTracking()
    }
    
    func togglePocketMode() {
        isPocketMode.toggle()
        if isPocketMode {
            lockNorthReference()
        }
        print("Pocket mode: \(isPocketMode ? "ON" : "OFF")")
    }

    func calibrateHeadTracking() {
        // Reset head tracking reference to current position
        if let attitude = headRotation {
            initialHeadOrientation = attitude
            print("Head tracking calibrated - current position is now 'forward'")
        }
    }

    func setupLocationUpdates(locationStore: LocationStore, toneProfileStore: ToneProfileStore, audioEngine: SpatialAudioEngine) {
        self.locationStore = locationStore
        self.toneProfileStore = toneProfileStore
        self.audioEngine = audioEngine

        // Subscribe to location changes
        locationCancellable = locationStore.$locations
            .sink { [weak self] locations in
                guard let self = self,
                      let audioEngine = self.audioEngine,
                      let toneProfileStore = self.toneProfileStore else {
                    print("OrientationManager: subscription guard failed")
                    return
                }
                let enabledCount = locations.filter { $0.isEnabled }.count
                print("OrientationManager: locations changed, \(locations.count) total, \(enabledCount) enabled")
                audioEngine.updateLocations(locations, toneProfileStore: toneProfileStore)
            }

        // Initialize audio nodes for already-loaded locations
        let enabledCount = locationStore.locations.filter { $0.isEnabled }.count
        print("OrientationManager: initial load, \(locationStore.locations.count) total, \(enabledCount) enabled")
        audioEngine.updateLocations(locationStore.locations, toneProfileStore: toneProfileStore)
    }

    private func lockNorthReference() {
        lockedNorthReference = deviceHeading
        initialHeadOrientation = headRotation
        print("North reference locked at: \(Int(lockedNorthReference))°")
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.headingFilter = 1
        // Request always authorization for background audio navigation
        locationManager.requestAlwaysAuthorization()
        // Enable background location updates
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    private func setupHeadTracking() {
        checkHeadphoneConnection()
    }
    
    private func setupDeviceMotion() {
        deviceMotion.deviceMotionUpdateInterval = 0.1
    }
    
    private func startDeviceMotionTracking() {
        guard deviceMotion.isDeviceMotionAvailable else { return }
        
        deviceMotion.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            // Detect significant phone movement
            let rotationRate = motion.rotationRate
            let totalRotation = abs(rotationRate.x) + abs(rotationRate.y) + abs(rotationRate.z)
            
            // If phone is moving significantly and we're in pocket mode, maintain locked reference
            if totalRotation > 0.5 && self.isPocketMode {
                // Phone is moving - use locked reference
                return
            }
            
            // Check for heading stability when not in pocket mode
            if !self.isPocketMode {
                self.checkHeadingStability()
            }
        }
    }
    
    private func stopDeviceMotionTracking() {
        deviceMotion.stopDeviceMotionUpdates()
    }
    
    private func checkHeadingStability() {
        let headingDifference = abs(deviceHeading - lastStableHeading)
        
        if headingDifference < stabilityThreshold {
            headingStabilityCount += 1
            if headingStabilityCount >= stabilityCountRequired {
                lastStableHeading = deviceHeading
            }
        } else {
            headingStabilityCount = 0
            lastStableHeading = deviceHeading
        }
    }
    
    private func checkHeadphoneConnection() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Headphone motion not available")
            return
        }
        startHeadTracking()
    }
    
    private func startHeadTracking() {
        guard !motionManager.isDeviceMotionActive else { return }

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }

            self.headRotation = motion.attitude
            self.isHeadTrackingActive = true
            self.updateCombinedOrientation()
        }

        // Enable user location tracking for waypoint bearings
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }
    
    private func stopHeadTracking() {
        motionManager.stopDeviceMotionUpdates()
        isHeadTrackingActive = false
    }
    
    private func updateCombinedOrientation() {
        var finalHeading: Double
        
        if isPocketMode {
            // In pocket mode, use locked reference + head rotation only
            if let attitude = headRotation, let initial = initialHeadOrientation {
                // Calculate relative rotation from initial orientation
                let relativeYaw = (attitude.yaw - initial.yaw) * 180 / .pi
                finalHeading = normalizeAngle(lockedNorthReference - relativeYaw)
                
            } else {
                finalHeading = lockedNorthReference
            }
        } else {
            // Normal mode - use device heading + head rotation
            finalHeading = deviceHeading
            
            if let attitude = headRotation {
                let headYaw = attitude.yaw * 180 / .pi
                finalHeading = normalizeAngle(deviceHeading - headYaw)
            }
        }
        
        combinedHeading = smoothHeading(finalHeading)
    }
    
    private func smoothHeading(_ newHeading: Double) -> Double {
        var delta = newHeading - previousHeading

        if delta > 180 {
            delta -= 360
        } else if delta < -180 {
            delta += 360
        }

        let smoothedDelta = delta * smoothingFactor
        previousHeading = normalizeAngle(previousHeading + smoothedDelta)

        return previousHeading
    }

    private func smoothDeviceHeading(_ newHeading: Double) -> Double {
        var delta = newHeading - previousDeviceHeading

        if delta > 180 {
            delta -= 360
        } else if delta < -180 {
            delta += 360
        }

        let smoothedDelta = delta * smoothingFactor
        previousDeviceHeading = normalizeAngle(previousDeviceHeading + smoothedDelta)

        return previousDeviceHeading
    }

    private func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle.truncatingRemainder(dividingBy: 360)
        if normalized < 0 {
            normalized += 360
        }
        return normalized
    }
}

extension OrientationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading

        deviceHeading = heading
        smoothedDeviceHeading = smoothDeviceHeading(heading)
        headingAccuracy = newHeading.headingAccuracy
        calibrationNeeded = newHeading.headingAccuracy < 0 || newHeading.headingAccuracy > 25
        updateCombinedOrientation()
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        return true
    }
}

// MARK: - User Location Updates
extension OrientationManager {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last?.coordinate
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationAuthorizationStatus = manager.authorizationStatus
    }
}