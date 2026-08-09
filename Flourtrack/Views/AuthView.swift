import SwiftUI
import AuthenticationServices

/// Auth-Screen: Zeigt Guest-Button und Apple Sign In Button.
struct AuthView: View {
    @StateObject private var authService = AuthService()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo
            Image(systemName: "timer")
                .font(.system(size: 80, weight: .thin))
                .foregroundStyle(.primary)

            Text("FlourTrack")
                .font(.largeTitle.weight(.bold))

            Text("Melde dich an, um deine Scores zu synchronisieren.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            if authService.isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            } else {
                // Guest Button
                Button {
                    Task { await authService.createGuestAccount() }
                } label: {
                    Label("Als Gast fortfahren", systemImage: "person.fill.questionmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)

                // Apple Sign In Button
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName]
                } onCompletion: { result in
                    // Wird von AuthService uber ASAuthorizationControllerDelegate gehandelt
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .padding(.horizontal, 32)
                .onTapGesture {
                    authService.startAppleSignIn()
                }
            }

            if let error = authService.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}

#Preview {
    AuthView()
}
