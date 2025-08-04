import Foundation
import CoreMotion
import CoreLocation
import Combine

class OrientationManager: NSObject, ObservableObject {
    @Published var deviceHeading: Double = 0
    @Published var headRotation: CMAttitude?
    @Published var combinedHeading: Double = 0
    @Published var isHeadTrackingActive: Bool = false
    @Published var headingAccuracy: Double = -1
    @Published var calibrationNeeded: Bool = false
    
    private let motionManager = CMHeadphoneMotionManager()
    private let locationManager = CLLocationManager()
    private var headTrackingTimer: Timer?
    
    private let smoothingFactor: Double = 0.1
    private var previousHeading: Double = 0
    
    override init() {
        super.init()
        setupLocationManager()
        setupHeadTracking()
    }
    
    func start() {
        locationManager.startUpdatingHeading()
        startHeadTracking()
    }
    
    func stop() {
        locationManager.stopUpdatingHeading()
        stopHeadTracking()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.headingFilter = 1
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func setupHeadTracking() {
        checkHeadphoneConnection()
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
    }
    
    private func stopHeadTracking() {
        motionManager.stopDeviceMotionUpdates()
        isHeadTrackingActive = false
    }
    
    private func updateCombinedOrientation() {
        var finalHeading = deviceHeading
        
        if let attitude = headRotation {
            let headYaw = attitude.yaw * 180 / .pi
            finalHeading = normalizeAngle(deviceHeading - headYaw)
            
            // Debug output
            if abs(headYaw) > 5 {
                print("Head tracking: Device: \(Int(deviceHeading))°, Head Yaw: \(Int(headYaw))°, Combined: \(Int(finalHeading))°")
            }
        } else {
            // Debug when no head tracking
            if Int(deviceHeading) % 30 == 0 {
                print("No head tracking active, using device heading: \(Int(deviceHeading))°")
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
        headingAccuracy = newHeading.headingAccuracy
        calibrationNeeded = newHeading.headingAccuracy < 0 || newHeading.headingAccuracy > 25
        updateCombinedOrientation()
    }
    
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        return true
    }
}