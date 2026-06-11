import Foundation
import Observation
import OSLog
import SwiftData
import AuthenticationServices
import CoreModels

/// Sign-in durumunu UI'ya yansıtan @Observable yöneticisi.
/// Login durumu UserDefaults'ta saklanır — uygulama yeniden açıldığında
/// `bootstrap` otomatik olarak `.signedIn` durumuna geçer. Logout sadece
/// `signOut(modelContext:)` ile temizlenir.
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
    private let logger = Logger(subsystem: "club.kadro.wordduel", category: "AuthController")

    public init(
        signInService: AppleSignInService = AppleSignInService(),
        userDefaults: UserDefaults = .standard,
        storageKey: String = "wordduel.appleUserID"
    ) {
        self.signInService = signInService
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        if let existing = userDefaults.string(forKey: storageKey), !existing.isEmpty {
            self.phase = .signedIn(appleUserID: existing)
        }
    }

    public var storedAppleUserID: String? {
        get { userDefaults.string(forKey: storageKey) }
        set {
            if let newValue, !newValue.isEmpty {
                userDefaults.set(newValue, forKey: storageKey)
            } else {
                userDefaults.removeObject(forKey: storageKey)
            }
            userDefaults.synchronize()
        }
    }

    // MARK: - Bootstrap (uygulama açılışında)

    /// Saklı kullanıcı varsa anında `.signedIn`. Apple credential state
    /// kontrolü best-effort: yalnızca `.revoked` (kullanıcı Apple ID
    /// Ayarları'ndan app'i kaldırdı) durumunda otomatik logout tetiklenir.
    /// Simülatör'ün `.notFound` quirk'i ve diğer durumlar yok sayılır.
    public func bootstrap(modelContext: ModelContext) async {
        guard let storedID = storedAppleUserID, !storedID.isEmpty else {
            logger.info("No stored Apple user ID; staying in onboarding.")
            phase = .idle
            return
        }
        logger.info("Bootstrap: trusting stored Apple user ID, phase=signedIn.")
        phase = .signedIn(appleUserID: storedID)

        let state = await signInService.currentCredentialState(for: storedID)
        logger.info("Background credential state: \(String(describing: state)).")
        if state == .revoked {
            logger.warning("Credential revoked by user — signing out.")
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
            persist(result: result, modelContext: modelContext)
        } catch let error as AppleSignInService.AuthError {
            handle(error: error)
        } catch {
            logger.error("signIn() unknown error: \(String(describing: error))")
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
                persist(result: result, modelContext: modelContext)
            } catch let error as AppleSignInService.AuthError {
                handle(error: error)
            } catch {
                logger.error("processAuthorization unknown error: \(String(describing: error))")
                phase = .error(error.localizedDescription)
            }
        case .failure(let error):
            if let auth = error as? ASAuthorizationError, auth.code == .canceled {
                phase = .idle
            } else {
                logger.error("Authorization failure: \(String(describing: error))")
                phase = .error(error.localizedDescription)
            }
        }
    }

    public func signOut(modelContext: ModelContext) {
        if let storedID = storedAppleUserID {
            try? PlayerUpsert.delete(appleUserID: storedID, in: modelContext)
        }
        storedAppleUserID = nil
        logger.info("Sign out — stored Apple user ID cleared.")
        phase = .idle
    }

    #if DEBUG
    /// Geliştirme ortamında, Apple Sign In olmadan hızlıca "test kullanıcısı"
    /// olarak login olmak için. Production'da çağrılmaz (#if DEBUG ile gate'li).
    /// Aynı `userID` her simulator'da farklı olabilir — farklı test kimlikleri
    /// için iki cihazda iki farklı string kullan.
    public func signInAsTestUser(
        userID: String,
        displayName: String,
        modelContext: ModelContext
    ) {
        let fakeResult = AppleSignInService.Result(
            appleUserID: "test." + userID,
            displayName: displayName,
            identityTokenData: nil,
            isFirstTime: true
        )
        persist(result: fakeResult, modelContext: modelContext)
        logger.info("Signed in as test user: \(userID).")
    }
    #endif

    // MARK: - Private

    /// Sign-in başarılı olduğunda çağırılır.
    /// **Sıra önemli**: önce login state persist edilir, sonra phase güncellenir,
    /// Player upsert ise best-effort (hata atarsa login state kaybolmaz).
    private func persist(
        result: AppleSignInService.Result,
        modelContext: ModelContext
    ) {
        // 1) Login state'i ÖNCE persist et — bu sonraki açılışta auto-login için kritik
        storedAppleUserID = result.appleUserID
        phase = .signedIn(appleUserID: result.appleUserID)
        logger.info("Stored Apple user ID persisted; phase=signedIn.")

        // 2) Player kaydı (SwiftData / CloudKit) best-effort
        do {
            _ = try PlayerUpsert.upsert(
                appleUserID: result.appleUserID,
                displayName: result.displayName,
                in: modelContext
            )
        } catch {
            logger.error("PlayerUpsert failed (login still persisted): \(String(describing: error))")
        }
    }

    private func handle(error: AppleSignInService.AuthError) {
        switch error {
        case .canceled:
            phase = .idle
        default:
            logger.error("Auth error: \(String(describing: error))")
            phase = .error(String(describing: error))
        }
    }
}
