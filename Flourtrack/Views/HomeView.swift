import SwiftUI

struct HomeView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        VStack(spacing: 28) {
            FlourTrackLogoView()
                .frame(width: 250, height: 250)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("FlourTrack")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Timing ist alles.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                if vm.bestScore > 0 {
                    Text("Best: \(vm.bestScore)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)

            Button {
                vm.start()
            } label: {
                Label("Start", systemImage: "timer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: 280)
            .accessibilityHint("Startet den Precision Timer.")
        }
        .padding(32)
    }
}