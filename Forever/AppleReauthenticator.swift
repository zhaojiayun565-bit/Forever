import AuthenticationServices
import UIKit

/// Presents the system Sign in with Apple sheet without a button and returns the credential.
/// Used to re-confirm identity for sensitive actions (e.g. account deletion token revocation).
@MainActor
final class AppleReauthenticator: NSObject {
    enum ReauthError: LocalizedError {
        case missingAuthorizationCode

        var errorDescription: String? {
            "Apple didn't return a confirmation code. Please try again."
        }
    }

    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    /// Requests a fresh Apple ID authorization and returns its one-time authorization code.
    func authorizationCode() async throws -> String {
        let credential = try await requestCredential()
        guard let data = credential.authorizationCode, let code = String(data: data, encoding: .utf8) else {
            throw ReauthError.missingAuthorizationCode
        }
        return code
    }

    private func requestCredential() async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
}

extension AppleReauthenticator: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        MainActor.assumeIsolated {
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                continuation?.resume(returning: credential)
            } else {
                continuation?.resume(throwing: ReauthError.missingAuthorizationCode)
            }
            continuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        MainActor.assumeIsolated {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

extension AppleReauthenticator: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}
