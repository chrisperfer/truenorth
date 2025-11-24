import Foundation
import CoreLocation

enum LocationServiceError: Error, LocalizedError {
    case noResults
    case invalidAddress
    case geocodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noResults:
            return "No results found for this address"
        case .invalidAddress:
            return "Invalid address format"
        case .geocodingFailed(let error):
            return "Geocoding failed: \(error.localizedDescription)"
        }
    }
}

class LocationService {
    private let geocoder = CLGeocoder()

    func geocode(address: String) async -> Result<CLLocationCoordinate2D, LocationServiceError> {
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)

            guard let coordinate = placemarks.first?.location?.coordinate else {
                return .failure(.noResults)
            }

            return .success(coordinate)
        } catch {
            return .failure(.geocodingFailed(error))
        }
    }

    func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }
}
