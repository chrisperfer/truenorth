import SwiftUI

struct LocationRow: View {
    let location: Location
    let profileName: String
    @Binding var isEnabled: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Toggle(isOn: $isEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.headline)

                    Text(profileName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
    }
}

#Preview {
    LocationRow(
        location: Location(
            name: "Home",
            coordinate: .init(latitude: 37.7749, longitude: -122.4194),
            toneProfileId: UUID()
        ),
        profileName: "Default Tone",
        isEnabled: .constant(true),
        onDelete: {}
    )
}
