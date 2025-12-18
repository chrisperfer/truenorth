import SwiftUI

struct LocationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationStore: LocationStore
    @EnvironmentObject var toneProfileStore: ToneProfileStore

    let location: Location
    @ObservedObject var audioEngine: SpatialAudioEngine

    @State private var name: String = ""
    @State private var selectedProfileId: UUID = UUID()

    var body: some View {
        NavigationView {
            Form {
                Section("Name") {
                    TextField("Location Name", text: $name)
                }

                Section("Tone") {
                    Picker("Tone Profile", selection: $selectedProfileId) {
                        ForEach(toneProfileStore.profiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Coordinates") {
                    Text(String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Location")
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
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                name = location.name
                selectedProfileId = location.toneProfileId
            }
        }
    }

    private func saveLocation() {
        var updatedLocation = location
        updatedLocation.name = name

        let profileChanged = updatedLocation.toneProfileId != selectedProfileId
        updatedLocation.toneProfileId = selectedProfileId

        locationStore.update(updatedLocation)

        // If profile changed and location is enabled, update the audio
        if profileChanged && updatedLocation.isEnabled {
            // Remove and recreate the audio node with new profile
            audioEngine.updateLocations(locationStore.locations, toneProfileStore: toneProfileStore)
        }

        dismiss()
    }
}

#Preview {
    LocationEditorView(
        location: Location(
            name: "Home",
            coordinate: .init(latitude: 37.7749, longitude: -122.4194),
            toneProfileId: UUID()
        ),
        audioEngine: SpatialAudioEngine()
    )
    .environmentObject(LocationStore())
    .environmentObject(ToneProfileStore())
}
