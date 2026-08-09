import SwiftUI
import SwiftData

@main
struct FlourTrackApp: App {
    let modelContainer = FlourTrackModelContainer.make()
    @State private var haptics = HapticAudioManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.hapticAudio, haptics)
                .modelContainer(modelContainer)
        }
    }
}