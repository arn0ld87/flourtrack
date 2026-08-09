import SwiftUI

struct GameView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                // Touch-Down statt Tap-Release erfassen: sonst wandert die Press-Dauer in accuracyMs
                // und ein früh aufgesetzter, bei 0 losgelassener Finger löst keinen Early-Miss aus (Codex P1).
                .gesture(DragGesture(minimumDistance: 0).onChanged { _ in vm.tap() })
                .accessibilityElement()
                .accessibilityLabel(vm.phase == .waitingTap ? "Jetzt tippen" : "Spielfläche")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { vm.tap() }

            VStack(spacing: 24) {
                Spacer()
                if vm.phase == .waitingTap {
                    Text("JETZT TAPPEN")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(.blue)
                } else {
                    Text("\(vm.countdownValue)")
                        .font(.system(size: 120, weight: .black, design: .rounded))
                        .contentTransition(.numericText())
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text(vm.phase == .waitingTap ? "Tippe irgendwo" : "Warte auf 0 …")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("game-tap-area")
    }
}