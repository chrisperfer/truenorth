import Foundation
import Combine

class ToneProfileStore: ObservableObject {
    @Published var profiles: [ToneProfile] = []

    private let storageKey = "SavedToneProfiles"
    private var cancellables = Set<AnyCancellable>()

    // Stable UUIDs for built-in profiles
    static let defaultProfileId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let warmAlternateId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    // Built-in profiles (used as defaults)
    static let builtInProfiles: [ToneProfile] = [
        ToneProfile(
            id: defaultProfileId,
            name: "Default North Tone",
            frequency: 830.0,
            pingDuration: 0.15,
            pingInterval: 5.0,
            echoDelay: 5.0,
            echoAttenuation: 0.28,
            fundamentalAmplitude: 1.0,
            harmonic2Amplitude: 1.0,
            harmonic3Amplitude: 1.0,
            harmonic4Amplitude: 1.0,
            transientFrequency: 3000.0,
            transientAmplitude: 0.3,
            transientDecay: 50.0,
            pingEnvelopeDecay: 3.0,
            echoEnvelopeDecay: 4.0,
            frequencySweepAmount: 0.4
        ),
        ToneProfile(
            id: warmAlternateId,
            name: "Warm Alternate",
            frequency: 600.0,
            pingDuration: 0.15,
            pingInterval: 5.0,
            echoDelay: 5.0,
            echoAttenuation: 0.28,
            fundamentalAmplitude: 1.0,
            harmonic2Amplitude: 0.8,
            harmonic3Amplitude: 0.6,
            harmonic4Amplitude: 0.4,
            transientFrequency: 2400.0,
            transientAmplitude: 0.25,
            transientDecay: 50.0,
            pingEnvelopeDecay: 3.0,
            echoEnvelopeDecay: 4.0,
            frequencySweepAmount: 0.4
        )
    ]

    init() {
        load()

        // Auto-save on changes
        $profiles
            .dropFirst() // Skip initial load
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.save()
            }
            .store(in: &cancellables)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ToneProfile].self, from: data),
              !decoded.isEmpty else {
            // No saved profiles - use built-in defaults
            profiles = ToneProfileStore.builtInProfiles
            return
        }
        profiles = decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(profiles) else {
            print("Failed to encode tone profiles")
            return
        }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }

    // MARK: - CRUD Operations

    func add(_ profile: ToneProfile) {
        profiles.append(profile)
    }

    func update(_ profile: ToneProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        }
    }

    func delete(_ profile: ToneProfile) {
        profiles.removeAll { $0.id == profile.id }
    }

    // MARK: - Lookup

    func profile(withId id: UUID) -> ToneProfile? {
        profiles.first { $0.id == id }
    }

    var defaultProfile: ToneProfile {
        profiles.first ?? ToneProfileStore.builtInProfiles[0]
    }
}
