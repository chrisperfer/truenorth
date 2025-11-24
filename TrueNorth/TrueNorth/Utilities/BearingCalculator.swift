import Foundation
import CoreLocation

struct BearingCalculator {
    /// Calculate bearing from user location to destination in degrees (0-360)
    /// 0° = North, 90° = East, 180° = South, 270° = West
    static func calculateBearing(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi

        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Calculate relative bearing from user heading to destination bearing
    /// Returns angle in degrees (-180 to 180) where 0 = straight ahead
    static func relativeBearing(
        userHeading: Double,
        destinationBearing: Double
    ) -> Double {
        var relative = destinationBearing - userHeading

        // Normalize to -180 to 180
        if relative > 180 {
            relative -= 360
        } else if relative < -180 {
            relative += 360
        }

        return relative
    }
}
