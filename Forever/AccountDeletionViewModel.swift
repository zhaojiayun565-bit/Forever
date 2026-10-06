import AuthenticationServices
import Foundation
import Observation

/// Drives the Delete Account flow: confirmation, Apple re-auth, server deletion, local reset.
@MainActor
@Observable
final class AccountDeletionViewModel {
    var isConfirming = false
    private(set) var isDeleting = false
    var errorMessage: String?

    private let supabase: SupabaseManager
    private let reauthenticator = AppleReauthenticator()

    init(supabase: SupabaseManager = .shared) {
        self.supabase = supabase
    }

    /// Shows the destructive confirmation alert.
    func requestDeletion() {
        isConfirming = true
    }

    /// Re-confirms with Apple (when applicable), deletes the account, then resets local state.
    func confirmDeletion(appState: AppStateManager) async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            var appleCode: String?
            if await supabase.isSignedInWithApple() {
                appleCode = try await reauthenticator.authorizationCode()
            }
            try await supabase.deleteAccount(appleAuthorizationCode: appleCode)
            await appState.handleAccountDeleted()
        } catch let error as ASAuthorizationError where error.code == .canceled {
            return
        } catch {
            errorMessage = "We couldn't delete your account. Please check your connection and try again."
            print("🚨 Account deletion failed: \(error)")
        }
    }
}
