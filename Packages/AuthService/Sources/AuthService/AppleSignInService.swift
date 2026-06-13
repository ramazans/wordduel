import Foundation
import AuthenticationServices
#if canImport(UIKit)
import UIKit
#endif

/// Sign in with Apple akışı için ASAuthorizationController köprüsü.
/// `signIn()` modal flow'u tetikler ve sonucu async olarak döner.
/// SwiftUI `SignInWithAppleButton` kullanan kodlar `processAuthorization(_:)` ile direkt
/// credential'ı işleyebilir; manuel tetikleme isteyen kodlar `signIn()` çağırır.
@MainActor
public final class AppleSignInService: NSObject {
    public enum AuthError: Error, Sendable, Equatable {
        case canceled
        case missingCredential
        case invalidCredential
        case credentialRevoked
        case unknown(String)
    }

    public struct Result: Sendable, Equatable {
        public let appleUserID: String
        public let displayName: String
        public let identityTokenData: Data?
        public let isFirstTime: Bool

        public init(
            appleUserID: String,
            displayName: String,
            identityTokenData: Data?,
            isFirstTime: Bool
        ) {
            self.appleUserID = appleUserID
            self.displayName = displayName
            self.identityTokenData = identityTokenData
            self.isFirstTime = isFirstTime
        }
    }

    private var continuation: CheckedContinuation<Result, Error>?
    private var presentationProvider: PresentationProvider?

    public override init() {
        super.init()
    }

    // MARK: - Public API

    /// Modal Sign in with Apple flow'u başlatır.
    public func signIn() async throws -> Result {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            let provider = PresentationProvider()
            self.presentationProvider = provider
            controller.presentationContextProvider = provider
            controller.performRequests()
        }
    }

    /// `SignInWithAppleButton.onCompletion` callback'inden gelen `ASAuthorization`'u işler.
    public func processAuthorization(_ authorization: ASAuthorization) throws -> Result {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.invalidCredential
        }
        return try makeResult(from: credential)
    }

    /// Daha önce sign-in yapmış kullanıcının credential durumunu doğrular.
    public func currentCredentialState(for appleUserID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: appleUserID) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }

    // MARK: - Private

    fileprivate func makeResult(from credential: ASAuthorizationAppleIDCredential) throws -> Result {
        let userID = credential.user
        guard !userID.isEmpty else { throw AuthError.invalidCredential }

        // Görünen ad olarak ön adı tercih et ("Ramazan Sağır" → "Ramazan");
        // ön ad yoksa soyadına düş. Apple `fullName`'i YALNIZCA ilk onayda
        // gönderir — sonraki girişlerde boş gelir, bu durumda PlayerUpsert
        // `Player-XXXX` atar.
        let givenName = credential.fullName?.givenName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let familyName = credential.fullName?.familyName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayName = givenName.isEmpty ? familyName : givenName
        let isFirstTime = !displayName.isEmpty

        return Result(
            appleUserID: userID,
            displayName: displayName,
            identityTokenData: credential.identityToken,
            isFirstTime: isFirstTime
        )
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInService: ASAuthorizationControllerDelegate {
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AuthError.invalidCredential)
            continuation = nil
            return
        }
        do {
            let result = try makeResult(from: credential)
            continuation?.resume(returning: result)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
        presentationProvider = nil
    }

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let mapped: AuthError = {
            if let auth = error as? ASAuthorizationError {
                switch auth.code {
                case .canceled: return .canceled
                case .invalidResponse, .notHandled: return .invalidCredential
                default: return .unknown(error.localizedDescription)
                }
            }
            return .unknown(error.localizedDescription)
        }()
        continuation?.resume(throwing: mapped)
        continuation = nil
        presentationProvider = nil
    }
}

// MARK: - Presentation provider

private final class PresentationProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    @MainActor
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if canImport(UIKit)
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.keyWindow ?? UIWindow()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
