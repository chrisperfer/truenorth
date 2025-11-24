import Foundation
import Combine
import CoreLocation

class LocationStore: ObservableObject {
    @Published var locations: [Location] = []

    private let storageKey = "SavedLocations"
    private var cancellables = Set<AnyCancellable>()

    init() {
        load()

        // Auto-save on changes
        $locations
            .dropFirst() // Skip initial load
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.save()
            }
            .store(in: &cancellables)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Location].self, from: data) else {
            locations = []
            return
        }
        locations = decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(locations) else {
            print("Failed to encode locations")
            return
        }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }

    func add(_ location: Location) {
        locations.append(location)
    }

    func update(_ location: Location) {
        if let index = locations.firstIndex(where: { $0.id == location.id }) {
            locations[index] = location
        }
    }

    func delete(_ location: Location) {
        locations.removeAll { $0.id == location.id }
    }

    func toggle(_ location: Location) {
        if let index = locations.firstIndex(where: { $0.id == location.id }) {
            locations[index].isEnabled.toggle()
        }
    }
}
