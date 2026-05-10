import Foundation
import Observation
import SwiftData
import AuthenticationServices
import AuthService
import CloudKitService

/// Onboarding ekranı için thin view model — AuthController + CloudKitAccount köprüsü.
@MainActor
@Observable
public final class SignInViewModel {
    public let authController: AuthController
    public let cloudKitAccount: CloudKitAccount

    public private(set) var iCloudAvailability: CloudKitAccount.Availability = .couldNotDetermine
    public private(set) var isCheckingCloudKit = false

    public init(authController: AuthController, cloudKitAccount: CloudKitAccount) {
        self.authController = authController
        self.cloudKitAccount = cloudKitAccount
    }

    public func refreshCloudKitAvailability() async {
        isCheckingCloudKit = true
        iCloudAvailability = await cloudKitAccount.availability()
        isCheckingCloudKit = false
    }

    public func handleAppleSignIn(
        _ result: Result<ASAuthorization, Error>,
        modelContext: ModelContext
    ) {
        authController.handle(authorizationResult: result, modelContext: modelContext)
    }
}
