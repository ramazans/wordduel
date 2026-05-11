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

    /// Saklı kullanıcı varsa anında `.signedIn` olur. Apple credential state
    /// kontrolü arka planda yapılır; yalnızca `.revoked` durumunda otomatik
    /// logout tetiklenir. `.notFound` (simülatör quirk'ı) ve diğer durumlarda
    /// kullanıcıya güveniriz — explicit logout'la çıkar.
    public func bootstrap(modelContext: ModelContext) async {
        guard let storedID = storedAppleUserID else {
            phase = .idle
            return
        }
        phase = .signedIn(appleUserID: storedID)

        let state = await signInService.currentCredentialState(for: storedID)
        if state == .revoked {
            try? PlayerUpsert.delete(appleUserID: storedID, in: modelContext)
            storedAppleUserID = nil
            phase = .revoked
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
