import SwiftUI
import Playgrounds

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        ZStack {
            FlourTrackBackground()

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
                }
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)

                Button {
                } label: {
                    Label("Start", systemImage: "timer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: 280)
                .accessibilityHint("Startet spaeter den Precision Timer.")
            }
            .padding(32)
        }
    }
}

private struct FlourTrackBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: [
                colorScheme == .dark ? Color(red: 0.02, green: 0.03, blue: 0.06) : Color(red: 0.97, green: 0.98, blue: 1.0),
                Color.blue.opacity(0.16),
                colorScheme == .dark ? Color(red: 0.05, green: 0.06, blue: 0.09) : Color(red: 0.92, green: 0.94, blue: 0.97)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct FlourTrackLogoView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(colorScheme == .dark ? 0.26 : 0.16))
                .blur(radius: 32)

            StopwatchMark()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.03, green: 0.08, blue: 0.18), Color(red: 0.04, green: 0.15, blue: 0.36)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    StopwatchMark()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 2)
                }
                .frame(width: 158, height: 158)
                .offset(y: -8)

            FlourSwipe()
                .fill(
                    LinearGradient(
                        colors: [.blue, .cyan, .white, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .blue.opacity(0.78), radius: 18)
                .frame(width: 224, height: 96)
                .offset(y: 18)

            FlourSparkles()
                .fill(.white)
                .frame(width: 160, height: 92)
                .offset(y: 26)

            Image(systemName: "sparkle")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color(red: 0.03, green: 0.08, blue: 0.18))
                .offset(x: 94, y: -2)

            Image(systemName: "sparkle")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.blue)
                .offset(x: 116, y: 30)
        }
        .compositingGroup()
        .shadow(color: .blue.opacity(0.34), radius: 24, y: 10)
    }
}

private struct StopwatchMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.05)
        let radius = min(rect.width, rect.height) * 0.42

        path.addEllipse(
            in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )

        path.addRoundedRect(
            in: CGRect(
                x: rect.midX - rect.width * 0.12,
                y: rect.minY + rect.height * 0.02,
                width: rect.width * 0.24,
                height: rect.height * 0.16
            ),
            cornerSize: CGSize(width: 8, height: 8)
        )

        path.move(to: CGPoint(x: rect.midX + rect.width * 0.33, y: rect.minY + rect.height * 0.22))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.14))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + rect.height * 0.42))
        path.closeSubpath()

        path.move(to: center)
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY + rect.height * 0.32))

        return path
    }
}

private struct FlourSwipe: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.midY + rect.height * 0.22))
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.02, y: rect.minY + rect.height * 0.04),
            control1: CGPoint(x: rect.width * 0.34, y: rect.minY - rect.height * 0.1),
            control2: CGPoint(x: rect.width * 0.74, y: rect.maxY + rect.height * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.06, y: rect.maxY - rect.height * 0.04),
            control1: CGPoint(x: rect.width * 0.78, y: rect.maxY + rect.height * 0.34),
            control2: CGPoint(x: rect.width * 0.36, y: rect.midY + rect.height * 0.22)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.midY + rect.height * 0.22),
            control1: CGPoint(x: rect.width * 0.2, y: rect.maxY - rect.height * 0.18),
            control2: CGPoint(x: rect.width * 0.08, y: rect.midY + rect.height * 0.12)
        )

        return path
    }
}

private struct FlourSparkles: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let dots: [(CGFloat, CGFloat, CGFloat)] = [
            (0.08, 0.36, 2.4),
            (0.18, 0.28, 1.8),
            (0.31, 0.24, 2.2),
            (0.43, 0.66, 3.4),
            (0.55, 0.72, 5.4),
            (0.67, 0.58, 2.8),
            (0.78, 0.46, 3.8),
            (0.9, 0.3, 2.0)
        ]

        for dot in dots {
            path.addEllipse(
                in: CGRect(
                    x: rect.minX + rect.width * dot.0,
                    y: rect.minY + rect.height * dot.1,
                    width: dot.2,
                    height: dot.2
                )
            )
        }

        return path
    }
}

#Preview {
    ContentView()
}

#Playground {
    _ = 1 + 2
}
