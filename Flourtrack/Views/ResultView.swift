import SwiftUI

struct ResultView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 12)

            Text(vm.rating?.localizedName ?? "")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(color(for: vm.rating))

            Text("\(vm.score) Punkte")
                .font(.title2.bold())

            HStack(spacing: 28) {
                stat("Combo", "\(vm.combo)")
                stat("Δ", "\(vm.accuracyMs) ms")
                stat("Best", "\(vm.bestScore)")
            }

            if !vm.newlyUnlocked.isEmpty {
                VStack(spacing: 8) {
                    ForEach(vm.newlyUnlocked) { a in
                        Label(a.title, systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.top, 4)
            }

            Spacer()

            Button {
                vm.start()
            } label: {
                Label("Nochmal", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Zurück zum Start") { vm.reset() }
                .buttonStyle(.bordered)
        }
        .padding(28)
    }

    @ViewBuilder
    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func color(for rating: Rating?) -> Color {
        switch rating {
        case .perfect:   return .green
        case .excellent: return .blue
        case .good:      return .cyan
        case .okay:      return .yellow
        case .tooSlow:   return .orange
        case .tooEarly:  return .red
        default:         return .primary
        }
    }
}