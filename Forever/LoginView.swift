import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AppStateManager.self) private var state
    @State private var currentNonce: String?
    @State private var authErrorMessage: String?
    @State private var isLoading = false
    @State private var showError = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: .pink.opacity(0.3), radius: 20, x: 0, y: 10)

                Text("Forever")
                    .font(.system(size: 42, weight: .black, design: .rounded))

                Text("Stay connected, no matter the distance.")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task {
                        isLoading = true
                        defer { isLoading = false }
                        do {
                            _ = try await SupabaseManager.shared.signInAnonymously()
                            await state.initializeApp()
                        } catch {
                            authErrorMessage = "Anonymous test login failed. Please try again."
                            showError = true
                            print("Anonymous Sign In Error: \(error)")
                        }
                    }
                } label: {
                    Text(isLoading ? "Signing In..." : "Anonymous Test")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
                }
                .disabled(isLoading)

                SignInWithAppleButton(
                    onRequest: { request in
                        let nonce = AppleAuthHelper.randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = AppleAuthHelper.sha256(nonce)
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                               let nonce = currentNonce,
                               let appleIDToken = appleIDCredential.identityToken,
                               let idTokenString = String(data: appleIDToken, encoding: .utf8) {
                                Task {
                                    isLoading = true
                                    defer { isLoading = false }
                                    do {
                                        try await SupabaseManager.shared.signInWithApple(idToken: idTokenString, nonce: nonce)
                                        await state.initializeApp()
                                    } catch {
                                        authErrorMessage = "Could not sign in right now. Please try again."
                                        showError = true
                                        print("Apple Auth Error: \(error)")
                                    }
                                }
                            } else {
                                authErrorMessage = "Apple Sign In did not return valid credentials."
                                showError = true
                            }
                        case .failure(let error):
                            authErrorMessage = "Apple Sign In was cancelled or failed. Please try again."
                            showError = true
                            print("Authorization failed: \(error)")
                        }
                    }
                )
                .signInWithAppleButtonStyle(.whiteOutline)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
                .disabled(isLoading)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .alert("Sign In Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {
                authErrorMessage = nil
                showError = false
            }
        } message: {
            Text(authErrorMessage ?? "Something went wrong.")
        }
    }
}
