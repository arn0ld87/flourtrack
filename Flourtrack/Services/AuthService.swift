import Foundation
import UIKit
import AuthenticationServices
import SwiftData
import Combine

/// Orchestriert den Auth-Flow: Guest-Account erstellen, Apple Sign In, JWT speichern.
@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    private let api: FlourTrackAPI

    init(api: FlourTrackAPI = FlourTrackAPI()) {
        self.api = api
        super.init()
        checkExistingSession()
    }

    // MARK: - Session State

    private func checkExistingSession() {
        isAuthenticated = KeychainTokenStore.isAuthenticated
    }

    /// Stellt sicher, dass ein Guest-Account existiert (lazy auth beim ersten Upload).
    func ensureGuestAccount() async {
        guard !isAuthenticated else { return }
        await createGuestAccount()
    }

    // MARK: - Guest Auth

    func createGuestAccount(displayName: String? = nil) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let response = try await api.createGuest(displayName: displayName)
            saveSession(response: response)
        } catch {
            lastError = "Guest-Account konnte nicht erstellt werden: \(error.localizedDescription)"
        }
    }

    // MARK: - Apple Sign In

    func startAppleSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private func handleAppleCredential(_ credential: ASAuthorizationAppleIDCredential) {
        guard let identityToken = credential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8),
              let authorizationCode = credential.authorizationCode,
              let authCodeString = String(data: authorizationCode, encoding: .utf8) else {
            lastError = "Apple Sign In: Ungultige Credentials"
            return
        }

        isLoading = true
        lastError = nil

        Task {
            do {
                let guestToken = KeychainTokenStore.token()
                let response = try await api.signInWithApple(
                    identityToken: identityTokenString,
                    authorizationCode: authCodeString,
                    guestToken: guestToken
                )
                saveSession(response: response)

                // Update display_name if Apple provided fullName
                if let fullName = credential.fullName {
                    let displayName = [fullName.givenName, fullName.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    if !displayName.isEmpty {
                        // Optional: PATCH /profile/me
                        _ = try? await api.fetchProfile()
                    }
                }
            } catch {
                lastError = "Apple Sign In fehlgeschlagen: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    // MARK: - Logout

    func logout() {
        KeychainTokenStore.clear()
        isAuthenticated = false
        lastError = nil
    }

    // MARK: - Private Helpers

    private func saveSession(response: AuthResponse) {
        KeychainTokenStore.save(
            token: response.token,
            publicUserId: response.user.public_user_id,
            provider: response.user.account_provider
        )
        isAuthenticated = true
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            Task { @MainActor in
                self.lastError = "Apple Sign In: Ungultiger Credential-Typ"
            }
            return
        }
        Task { @MainActor in
            self.handleAppleCredential(credential)
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            self.lastError = "Apple Sign In: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Ermittle das Hauptfenster synchron
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        return scenes.first?.windows.first ?? UIWindow()
    }
}
