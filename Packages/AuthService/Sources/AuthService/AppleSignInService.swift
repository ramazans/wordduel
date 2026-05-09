import Foundation
import AuthenticationServices
import CoreModels

/// Sign in with Apple + iCloud user eşleme.
/// Faz 2'de doldurulacak.
@MainActor
public final class AppleSignInService: NSObject {
    public enum AuthError: Error, Sendable {
        case canceled
        case missingCredential
        case credentialRevoked
    }

    public struct SignInResult: Sendable {
        public let appleUserID: String
        public let displayName: String
    }

    public override init() {
        super.init()
    }

    public func signIn() async throws -> SignInResult {
        // TODO Faz 2: ASAuthorizationAppleIDProvider + delegate köprüsü.
        throw AuthError.missingCredential
    }

    public func currentCredentialState(for userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }
}
