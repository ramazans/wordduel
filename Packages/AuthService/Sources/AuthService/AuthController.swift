import Foundation
import Observation
import SwiftData
import AuthenticationServices
import CoreModels

/// Sign-in durumunu UI'ya yansıtan @Observable yöneticisi.
/// Apple credential state'i kalıcı (UserDefaults), Player kaydı SwiftData'da.
@MainActor
@Observable
public final class AuthController {
    public enum Phase: Equatable {
        case idle
        case signingIn
        case signedIn(appleUserID: String)
        case revoked
        case error(String)
    }

    public private(set) var phase: Phase = .idle

    private let signInService: AppleSignInService
    private let userDefaults: UserDefaults
    private let storageKey: String

    public init(
        signInService: AppleSignInService = AppleSignInService(),
        userDefaults: UserDefaults = .standard,
        storageKey: String = "wordduel.appleUserID"
    ) {
        self.signInService = signInService
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    public var storedAppleUserID: String? {
        get { userDefaults.string(forKey: storageKey) }
        set {
            if let newValue {
                userDefaults.set(newValue, forKey: storageKey)
            } else {
                userDefaults.removeObject(forKey: storageKey)
            }
        }
    }

    // MARK: - Bootstrap (uygulama açılışında)

    /// Saklı kullanıcı varsa credential state'i kontrol eder. Revoke edilmişse temizler.
    public func bootstrap(modelContext: ModelContext) async {
        guard let storedID = storedAppleUserID else {
            phase = .idle
            return
        }
        let state = await signInService.currentCredentialState(for: storedID)
        switch state {
        case .authorized:
            phase = .signedIn(appleUserID: storedID)
        case .revoked, .notFound:
            try? PlayerUpsert.delete(appleUserID: storedID, in: modelContext)
            storedAppleUserID = nil
            phase = .revoked
        case .transferred:
            phase = .signedIn(appleUserID: storedID)
        @unknown default:
            phase = .signedIn(appleUserID: storedID)
        }
    }

    // MARK: - Sign in

    /// Modal sign-in flow'unu tetikler ve Player'ı upsert eder.
    public func signIn(modelContext: ModelContext) async {
        phase = .signingIn
        do {
            let result = try await signInService.signIn()
            try persist(result: result, modelContext: modelContext)
        } catch let error as AppleSignInService.AuthError {
            handle(error: error)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    /// `SignInWithAppleButton.onCompletion` callback için.
    public func handle(
        authorizationResult: Result<ASAuthorization, Error>,
        modelContext: ModelContext
    ) {
        switch authorizationResult {
        case .success(let authorization):
            do {
                let result = try signInService.processAuthorization(authorization)
                try persist(result: result, modelContext: modelContext)
            } catch let error as AppleSignInService.AuthError {
                handle(error: error)
            } catch {
                phase = .error(error.localizedDescription)
            }
        case .failure(let error):
            if let auth = error as? ASAuthorizationError, auth.code == .canceled {
                phase = .idle
            } else {
                phase = .error(error.localizedDescription)
            }
        }
    }

    public func signOut(modelContext: ModelContext) {
        if let storedID = storedAppleUserID {
            try? PlayerUpsert.delete(appleUserID: storedID, in: modelContext)
        }
        storedAppleUserID = nil
        phase = .idle
    }

    // MARK: - Private

    private func persist(
        result: AppleSignInService.Result,
        modelContext: ModelContext
    ) throws {
        _ = try PlayerUpsert.upsert(
            appleUserID: result.appleUserID,
            displayName: result.displayName,
            in: modelContext
        )
        storedAppleUserID = result.appleUserID
        phase = .signedIn(appleUserID: result.appleUserID)
    }

    private func handle(error: AppleSignInService.AuthError) {
        switch error {
        case .canceled:
            phase = .idle
        default:
            phase = .error(String(describing: error))
        }
    }
}
