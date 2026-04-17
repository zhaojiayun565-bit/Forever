import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AppStateManager.self) private var state
    @State private var currentNonce: String?
    @State private var authErrorMessage: String?

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
                    .font(.headline.design(.rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

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
                                do {
                                    try await SupabaseManager.shared.signInWithApple(idToken: idTokenString, nonce: nonce)
                                    await state.initializeApp()
                                } catch {
                                    authErrorMessage = "Could not sign in right now. Please try again."
                                    print("Apple Auth Error: \(error)")
                                }
                            }
                        } else {
                            authErrorMessage = "Apple Sign In did not return valid credentials."
                        }
                    case .failure(let error):
                        authErrorMessage = "Apple Sign In was cancelled or failed. Please try again."
                        print("Authorization failed: \(error)")
                    }
                }
            )
            .signInWithAppleButtonStyle(.whiteOutline)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .alert("Sign In Failed", isPresented: Binding(
            get: { authErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    authErrorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                authErrorMessage = nil
            }
        } message: {
            Text(authErrorMessage ?? "Something went wrong.")
        }
    }
}
