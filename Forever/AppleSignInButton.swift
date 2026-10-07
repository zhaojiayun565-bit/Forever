import AuthenticationServices
import SwiftUI
import os

/// Sign in with Apple button that signs into Supabase, reloads app state, then calls `onSignedIn`.
struct AppleSignInButton: View {
    var style: SignInWithAppleButton.Style = .black
    var cornerRadius: CGFloat = 100
    @Binding var isSigningIn: Bool
    var onSignedIn: () async -> Void = {}

    @Environment(AppStateManager.self) private var state
    @State private var currentNonce: String?
    @State private var errorMessage: String?

    var body: some View {
        SignInWithAppleButton(
            onRequest: { request in
                let nonce = AppleAuthHelper.randomNonceString()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = AppleAuthHelper.sha256(nonce)
            },
            onCompletion: handle
        )
        .signInWithAppleButtonStyle(style)
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .disabled(isSigningIn)
        .alert("Sign In Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong.")
        }
    }

    /// Exchanges the Apple identity token for a Supabase session.
    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Apple Sign In did not return valid credentials."
                return
            }
            Task {
                isSigningIn = true
                defer { isSigningIn = false }
                do {
                    try await SupabaseManager.shared.signInWithApple(idToken: idToken, nonce: nonce)
                    await state.initializeApp()
                    await onSignedIn()
                } catch {
                    errorMessage = "Could not sign in right now. Please try again."
                    Log.auth.error("Apple Auth Error: \(String(describing: error))")
                }
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = "Apple Sign In failed. Please try again."
            Log.auth.error("Authorization failed: \(String(describing: error))")
        }
    }
}
