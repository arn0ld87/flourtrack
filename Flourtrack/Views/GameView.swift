import SwiftUI

struct GameView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { vm.tap() }

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