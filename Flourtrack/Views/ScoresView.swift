import SwiftUI
import SwiftData

struct ScoresView: View {
    @Environment(\.modelContext) private var context
    @State private var attempts: [GameAttempt] = []
    @State private var best = 0
    @State private var bestCombo = 0

    var body: some View {
        List {
            Section {
                LabeledContent("Best Score", value: "\(best)")
                LabeledContent("Beste Combo", value: "\(bestCombo)")
            }
            Section("Letzte Versuche") {
                if attempts.isEmpty {
                    Text("Noch keine Spiele.")
                        .foregroundStyle(.secondary)
                }
                ForEach(attempts) { a in
                    HStack {
                        Text(a.rating.localizedName)
                            .font(.headline)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(a.score) Pkt").bold()
                            Text("Δ \(a.accuracyMs) ms · Combo \(a.combo)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Scores")
        .task { await load() }
    }

    private func load() async {
        let repo = SwiftDataGameRepository(context: context)
        attempts = (try? repo.recentAttempts(limit: 50)) ?? []
        best = (try? repo.bestScore()) ?? 0
        bestCombo = (try? repo.bestCombo()) ?? 0
    }
}