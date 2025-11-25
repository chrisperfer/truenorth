import SwiftUI

@main
struct TrueNorthApp: App {
    @StateObject private var locationStore = LocationStore()
    @StateObject private var toneProfileStore = ToneProfileStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationStore)
                .environmentObject(toneProfileStore)
        }
    }
}