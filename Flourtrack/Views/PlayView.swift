import SwiftUI
import SwiftData

struct PlayView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        ZStack {
            FlourTrackBackground()
            switch vm.phase {
            case .idle:
                HomeView(vm: vm)
            case .counting, .waitingTap:
                GameView(vm: vm)
            case .result:
                ResultView(vm: vm)
            }
        }
    }
}