import AuthenticationServices
import SwiftUI

/// Sign-in screen for returning users who already finished onboarding (e.g. after signing out).
struct LoginView: View {
    @Environment(AppStateManager.self) private var state
    @State private var isLoading = false
    @State private var debugErrorMessage: String?

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
                    .font(ForeverFont.header(size: 42, relativeTo: .largeTitle))

                Text("Stay connected, no matter the distance.")
                    .font(ForeverFont.subheader(.headline))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                #if DEBUG
                Button {
                    Task {
                        isLoading = true
                        defer { isLoading = false }
                        do {
                            _ = try await SupabaseManager.shared.signInAnonymously()
                            await state.initializeApp()
                        } catch {
                            debugErrorMessage = "Anonymous test login failed. Please try again."
                            print("Anonymous Sign In Error: \(error)")
                        }
                    }
                } label: {
                    Text(isLoading ? "Signing In..." : "Anonymous Test")
                        .font(ForeverFont.cta(.headline))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
                }
                .disabled(isLoading)
                .alert("Sign In Failed", isPresented: Binding(
                    get: { debugErrorMessage != nil },
                    set: { if !$0 { debugErrorMessage = nil } }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(debugErrorMessage ?? "")
                }
                #endif

                AppleSignInButton(style: .whiteOutline, isSigningIn: $isLoading)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}
