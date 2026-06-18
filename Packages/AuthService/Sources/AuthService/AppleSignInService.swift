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
    private let profileStore: ProfileNameStore

    public init(profileStore: ProfileNameStore = KeychainProfileStore()) {
        self.profileStore = profileStore
        super.init()
    }

    /// `appleUserID` için saklanan görünen adı kalıcı depodan siler.
    /// Yalnızca gerçek hesap sıfırlamada (credential revoke / hesabı sil)
    /// çağrılmalı — logout'ta çağrılmaz ki re-login'de isim geri gelsin.
    public func forgetProfile(appleUserID: String) {
        profileStore.removeDisplayName(for: appleUserID)
    }

    /// Kullanıcının elle belirlediği gerçek adı kalıcı depoya yazar. Apple ismi
    /// yalnızca ilk onayda gönderdiğinden, kullanıcı adını uygulama içinde
    /// (isim ekranı / Ayarlar) girdiğinde de Keychain'e yazıyoruz ki yeniden
    /// kurulumda kurtarılabilsin. Boş/placeholder adlar yazılmaz.
    public func rememberProfileName(_ name: String, for appleUserID: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !Self.isPlaceholderName(trimmed) else { return }
        profileStore.setDisplayName(trimmed, for: appleUserID)
    }

    /// `Player-1234` kalıbı mı? (CoreModels'a bağımlılık eklememek için yerel kopya.)
    nonisolated static func isPlaceholderName(_ name: String) -> Bool {
        let prefix = "Player-"
        guard name.hasPrefix(prefix) else { return false }
        let suffix = name.dropFirst(prefix.count)
        return suffix.count == 4 && suffix.allSatisfy(\.isNumber)
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
        // ön ad yoksa soyadına düş.
        let givenName = credential.fullName?.givenName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let familyName = credential.fullName?.familyName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawAppleName = givenName.isEmpty ? familyName : givenName

        let resolved = Self.resolveDisplayName(
            rawAppleName: rawAppleName,
            appleUserID: userID,
            store: profileStore
        )

        return Result(
            appleUserID: userID,
            displayName: resolved.displayName,
            identityTokenData: credential.identityToken,
            isFirstTime: resolved.isFirstTime
        )
    }

    /// Apple'dan gelen ham adı kalıcı depoyla uzlaştırır (saf, test edilebilir).
    ///
    /// - Apple gerçek bir ad gönderdiyse (ilk onay): depoya yaz ve onu kullan.
    /// - Apple ad göndermediyse (reinstall / sonraki girişler): depodan kurtar.
    ///   Böylece uygulama silinip yeniden kurulsa bile, sabit `appleUserID`
    ///   üzerinden gerçek ad geri gelir.
    /// - Hiçbir ad yoksa boş döner; downstream `PlayerUpsert` `Player-XXXX`
    ///   atar (son çare).
    nonisolated static func resolveDisplayName(
        rawAppleName: String,
        appleUserID: String,
        store: ProfileNameStore
    ) -> (displayName: String, isFirstTime: Bool) {
        let trimmed = rawAppleName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            store.setDisplayName(trimmed, for: appleUserID)
            return (trimmed, true)
        }
        if let cached = store.displayName(for: appleUserID), !cached.isEmpty {
            return (cached, false)
        }
        return ("", false)
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
