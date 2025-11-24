import SwiftUI
import CoreLocation

struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationStore: LocationStore
    @EnvironmentObject var toneProfileStore: ToneProfileStore

    @State private var searchAddress = ""
    @State private var locationName = ""
    @State private var searchResult: CLLocationCoordinate2D?
    @State private var selectedProfileId: UUID
    @State private var isSearching = false
    @State private var errorMessage: String?

    private let locationService = LocationService()

    init() {
        // Default to first profile
        _selectedProfileId = State(initialValue: ToneProfileStore().profiles.first?.id ?? UUID())
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Address") {
                    TextField("123 Main St, City, State", text: $searchAddress)
                        .textContentType(.fullStreetAddress)
                        .autocapitalization(.words)

                    Button(action: searchAddress_action) {
                        if isSearching {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                                Text("Searching...")
                            }
                        } else {
                            Text("Search")
                        }
                    }
                    .disabled(searchAddress.isEmpty || isSearching)

                    if let result = searchResult {
                        Text("Found: \(locationService.formatCoordinate(result))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                if searchResult != nil {
                    Section("Details") {
                        TextField("Location Name", text: $locationName)
                            .textContentType(.name)

                        Picker("Tone", selection: $selectedProfileId) {
                            ForEach(toneProfileStore.profiles) { profile in
                                Text(profile.name).tag(profile.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLocation()
                    }
                    .disabled(searchResult == nil || locationName.isEmpty)
                }
            }
        }
    }

    private func searchAddress_action() {
        Task {
            isSearching = true
            errorMessage = nil

            let result = await locationService.geocode(address: searchAddress)

            await MainActor.run {
                switch result {
                case .success(let coordinate):
                    searchResult = coordinate
                    if locationName.isEmpty {
                        locationName = searchAddress.components(separatedBy: ",").first ?? searchAddress
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
                isSearching = false
            }
        }
    }

    private func saveLocation() {
        guard let coordinate = searchResult else { return }

        let location = Location(
            name: locationName,
            coordinate: coordinate,
            toneProfileId: selectedProfileId
        )

        locationStore.add(location)
        dismiss()
    }
}

#Preview {
    AddLocationView()
        .environmentObject(LocationStore())
        .environmentObject(ToneProfileStore())
}
