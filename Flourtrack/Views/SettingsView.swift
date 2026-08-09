import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.hapticAudio) private var haptics
    @State private var profile: PlayerProfile?
    @StateObject private var authService = AuthService()
    @StateObject private var syncEngine = SyncEngine()

    var body: some View {
        Form {
            Section("Account") {
                if authService.isAuthenticated {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text("Verbunden")
                                .font(.headline)
                            if let publicId = KeychainTokenStore.publicUserId() {
                                Text(publicId)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Button("Abmelden") {
                            authService.logout()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }

                    if syncEngine.pendingCount > 0 {
                        HStack {
                            Text("Ausstehende Uploads")
                            Spacer()
                            Text("\(syncEngine.pendingCount)")
                                .foregroundStyle(.orange)
                                .font(.headline)
                        }
                    }

                    if syncEngine.isSyncing {
                        HStack {
                            Text("Synchronisiere...")
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    } else if syncEngine.lastSyncError != nil {
                        Button("Synchronisierung wiederholen") {
                            Task {
                                await syncEngine.flushQueue(context: context)
                            }
                        }
                    }
                } else {
                    Button("Anmelden") {
                        // Navigiere zu AuthView
                    }
                    .foregroundStyle(.blue)
                }
            }

            Section("Profil") {
                TextField("Name", text: nameBinding)
            }
            Section("Feedback") {
                Toggle("Haptik", isOn: hapticsBinding)
                Toggle("Audio", isOn: audioBinding)
            }
            Section("Achievements") {
                AchievementsList()
            }
        }
        .navigationTitle("Einstellungen")
        .task { await load() }
        .onAppear {
            syncEngine.refreshPendingCount(context: context)
        }
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { profile?.displayName ?? "" },
            set: { v in profile?.displayName = v; try? context.save() }
        )
    }
    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { profile?.hapticsEnabled ?? true },
            set: { v in
                profile?.hapticsEnabled = v
                try? context.save()
                haptics.configure(haptics: v, audio: profile?.audioEnabled ?? true)
            }
        )
    }
    private var audioBinding: Binding<Bool> {
        Binding(
            get: { profile?.audioEnabled ?? true },
            set: { v in
                profile?.audioEnabled = v
                try? context.save()
                haptics.configure(haptics: profile?.hapticsEnabled ?? true, audio: v)
            }
        )
    }

    private func load() async {
        guard profile == nil else { return }
        profile = try? SwiftDataProfileRepository(context: context).current()
    }
}

struct AchievementsList: View {
    @Environment(\.modelContext) private var context
    @State private var unlocked: Set<String> = []

    var body: some View {
        ForEach(AchievementDefinition.all) { def in
            HStack(spacing: 12) {
                Image(systemName: unlocked.contains(def.code) ? "checkmark.seal.fill" : "lock.fill")
                    .foregroundStyle(unlocked.contains(def.code) ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(def.title).font(.subheadline.weight(.semibold))
                    Text(def.detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        let repo = SwiftDataAchievementRepository(context: context)
        try? repo.seedIfNeeded()
        let all = (try? repo.all()) ?? []
        unlocked = Set(all.filter { $0.unlockedAt != nil }.map(\.code))
    }
}