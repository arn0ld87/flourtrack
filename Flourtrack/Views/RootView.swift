import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.hapticAudio) private var haptics
    @State private var gameVM: GameViewModel?
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            tab("Spielen", "play.fill") {
                if let vm = gameVM {
                    PlayView(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .tag(0)

            tab("Scores", "list.bullet.rectangle") {
                ScoresView()
            }
            .tag(1)

            tab("Einstellungen", "gearshape") {
                SettingsView()
            }
            .tag(2)
        }
        .task {
            if gameVM == nil {
                let gameRepo = SwiftDataGameRepository(context: context)
                let achRepo = SwiftDataAchievementRepository(context: context)
                try? achRepo.seedIfNeeded()
                gameVM = GameViewModel(gameRepo: gameRepo, achievementRepo: achRepo, haptics: haptics)
            }
            let profile = (try? SwiftDataProfileRepository(context: context).current()) ?? PlayerProfile()
            haptics.configure(haptics: profile.hapticsEnabled, audio: profile.audioEnabled)
        }
    }

    @ViewBuilder
    private func tab<V: View>(_ title: String, _ system: String, @ViewBuilder content: () -> V) -> some View {
        NavigationStack { content() }
            .tabItem { Label(title, systemImage: system) }
    }
}