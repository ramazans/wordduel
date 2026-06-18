import XCTest
import SwiftData
import CoreModels
@testable import AuthService

final class AuthServiceTests: XCTestCase {
    @MainActor
    func testServiceCanBeInstantiated() {
        let service = AppleSignInService()
        XCTAssertNotNil(service)
    }
}

/// Testler için bellek-içi `ProfileNameStore`.
final class FakeProfileNameStore: ProfileNameStore, @unchecked Sendable {
    private var storage: [String: String] = [:]

    func displayName(for appleUserID: String) -> String? {
        storage[appleUserID]
    }

    func setDisplayName(_ name: String, for appleUserID: String) {
        storage[appleUserID] = name
    }

    func removeDisplayName(for appleUserID: String) {
        storage[appleUserID] = nil
    }
}

final class ResolveDisplayNameTests: XCTestCase {
    func testFirstSignInStoresAndReturnsAppleName() {
        let store = FakeProfileNameStore()
        let result = AppleSignInService.resolveDisplayName(
            rawAppleName: "Ramazan",
            appleUserID: "u-1",
            store: store
        )
        XCTAssertEqual(result.displayName, "Ramazan")
        XCTAssertTrue(result.isFirstTime)
        XCTAssertEqual(store.displayName(for: "u-1"), "Ramazan")
    }

    func testReinstallRecoversNameFromStoreWhenAppleSendsNothing() {
        let store = FakeProfileNameStore()
        // İlk giriş Apple ismi gönderdi → cache'lendi
        _ = AppleSignInService.resolveDisplayName(
            rawAppleName: "Ramazan", appleUserID: "u-1", store: store
        )
        // Reinstall: Apple boş gönderir → cache'ten kurtarılır
        let result = AppleSignInService.resolveDisplayName(
            rawAppleName: "", appleUserID: "u-1", store: store
        )
        XCTAssertEqual(result.displayName, "Ramazan")
        XCTAssertFalse(result.isFirstTime)
    }

    func testEmptyNameWithEmptyStoreFallsBackToEmpty() {
        let store = FakeProfileNameStore()
        let result = AppleSignInService.resolveDisplayName(
            rawAppleName: "", appleUserID: "u-1", store: store
        )
        XCTAssertEqual(result.displayName, "")
        XCTAssertFalse(result.isFirstTime)
    }

    func testWhitespaceNameIsTreatedAsEmpty() {
        let store = FakeProfileNameStore()
        let result = AppleSignInService.resolveDisplayName(
            rawAppleName: "   ", appleUserID: "u-1", store: store
        )
        XCTAssertEqual(result.displayName, "")
        XCTAssertNil(store.displayName(for: "u-1"))
    }

    func testForgetRemovesCachedName() {
        let store = FakeProfileNameStore()
        _ = AppleSignInService.resolveDisplayName(
            rawAppleName: "Ramazan", appleUserID: "u-1", store: store
        )
        store.removeDisplayName(for: "u-1")
        let result = AppleSignInService.resolveDisplayName(
            rawAppleName: "", appleUserID: "u-1", store: store
        )
        XCTAssertEqual(result.displayName, "")
    }
}

final class RememberProfileNameTests: XCTestCase {
    @MainActor
    func testRemembersRealName() {
        let store = FakeProfileNameStore()
        let service = AppleSignInService(profileStore: store)
        service.rememberProfileName("Ramazan", for: "u-1")
        XCTAssertEqual(store.displayName(for: "u-1"), "Ramazan")
    }

    @MainActor
    func testIgnoresPlaceholder() {
        let store = FakeProfileNameStore()
        let service = AppleSignInService(profileStore: store)
        service.rememberProfileName("Player-0427", for: "u-1")
        XCTAssertNil(store.displayName(for: "u-1"))
    }

    @MainActor
    func testIgnoresEmpty() {
        let store = FakeProfileNameStore()
        let service = AppleSignInService(profileStore: store)
        service.rememberProfileName("   ", for: "u-1")
        XCTAssertNil(store.displayName(for: "u-1"))
    }

    func testIsPlaceholderNameMatchesPatternOnly() {
        XCTAssertTrue(AppleSignInService.isPlaceholderName("Player-0427"))
        XCTAssertFalse(AppleSignInService.isPlaceholderName("Ramazan"))
        XCTAssertFalse(AppleSignInService.isPlaceholderName("Player-42"))
        XCTAssertFalse(AppleSignInService.isPlaceholderName("Player-Ali"))
    }
}

final class PlayerUpsertTests: XCTestCase {
    @MainActor
    func makeContext() throws -> ModelContext {
        let container = try SchemaContainer.makeContainer(cloudKit: false, inMemory: true)
        return ModelContext(container)
    }

    @MainActor
    func testUpsertCreatesPlayerWhenMissing() throws {
        let context = try makeContext()
        let player = try PlayerUpsert.upsert(
            appleUserID: "001234.abcd",
            displayName: "Ali",
            in: context
        )
        XCTAssertEqual(player.appleUserID, "001234.abcd")
        XCTAssertEqual(player.displayName, "Ali")
    }

    @MainActor
    func testUpsertReturnsExistingWhenSameID() throws {
        let context = try makeContext()
        _ = try PlayerUpsert.upsert(appleUserID: "u-1", displayName: "Ali", in: context)
        let again = try PlayerUpsert.upsert(appleUserID: "u-1", displayName: "Ali", in: context)
        XCTAssertEqual(again.displayName, "Ali")

        let descriptor = FetchDescriptor<Player>(predicate: #Predicate { $0.appleUserID == "u-1" })
        let count = try context.fetchCount(descriptor)
        XCTAssertEqual(count, 1)
    }

    @MainActor
    func testUpsertDoesNotOverrideExistingNameWithEmpty() throws {
        let context = try makeContext()
        _ = try PlayerUpsert.upsert(appleUserID: "u-1", displayName: "Ali", in: context)
        let again = try PlayerUpsert.upsert(appleUserID: "u-1", displayName: "", in: context)
        XCTAssertEqual(again.displayName, "Ali")
    }

    @MainActor
    func testUpsertFillsEmptyNameLater() throws {
        let context = try makeContext()
        _ = try PlayerUpsert.upsert(appleUserID: "u-1", displayName: "", in: context)
        let again = try PlayerUpsert.upsert(appleUserID: "u-1", displayName: "Ayşe", in: context)
        XCTAssertEqual(again.displayName, "Ayşe")
    }

    @MainActor
    func testDefaultDisplayNameFormat() {
        let name = PlayerUpsert.defaultDisplayName(for: "001234.abcd")
        // "Player-" + sabit 4 hane
        XCTAssertTrue(name.hasPrefix("Player-"))
        XCTAssertTrue(PlayerUpsert.isAutoGenerated(name))
        // Deterministik: aynı kimlik → aynı ad
        XCTAssertEqual(name, PlayerUpsert.defaultDisplayName(for: "001234.abcd"))
    }

    @MainActor
    func testIsAutoGeneratedDetectsPlaceholderOnly() {
        XCTAssertTrue(PlayerUpsert.isAutoGenerated("Player-0427"))
        XCTAssertFalse(PlayerUpsert.isAutoGenerated("Ali"))
        XCTAssertFalse(PlayerUpsert.isAutoGenerated("Player-Ali"))
        XCTAssertFalse(PlayerUpsert.isAutoGenerated("Player-42"))
    }

    @MainActor
    func testAppleNameUpgradesAutoPlaceholderLater() throws {
        let context = try makeContext()
        // İlk giriş: Apple isim vermedi → placeholder
        let first = try PlayerUpsert.upsert(appleUserID: "u-1", displayName: "", in: context)
        XCTAssertTrue(PlayerUpsert.isAutoGenerated(first.displayName))
        // Sonraki onayda Apple ismi geldi → placeholder gerçek isimle değişir
        let upgraded = try PlayerUpsert.upsert(appleUserID: "u-1", displayName: "Ayşe", in: context)
        XCTAssertEqual(upgraded.displayName, "Ayşe")
    }

    @MainActor
    func testManualNameIsNotOverriddenByApple() throws {
        let context = try makeContext()
        // Kullanıcı elle "Reis" koymuş
        let player = try PlayerUpsert.upsert(appleUserID: "u-1", displayName: "Reis", in: context)
        XCTAssertEqual(player.displayName, "Reis")
        // Apple sonradan farklı bir isim verse de elle konan ad korunur
        let again = try PlayerUpsert.upsert(appleUserID: "u-1", displayName: "Ahmet", in: context)
        XCTAssertEqual(again.displayName, "Reis")
    }

    @MainActor
    func testStableAvatarIndexIsDeterministic() {
        let a = PlayerUpsert.stableAvatarIndex(for: "user-1")
        let b = PlayerUpsert.stableAvatarIndex(for: "user-1")
        XCTAssertEqual(a, b)
        XCTAssertTrue((0..<8).contains(a))
    }

    @MainActor
    func testDeleteRemovesPlayer() throws {
        let context = try makeContext()
        _ = try PlayerUpsert.upsert(appleUserID: "u-1", displayName: "Ali", in: context)
        try PlayerUpsert.delete(appleUserID: "u-1", in: context)

        let descriptor = FetchDescriptor<Player>(predicate: #Predicate { $0.appleUserID == "u-1" })
        XCTAssertEqual(try context.fetchCount(descriptor), 0)
    }
}

final class AuthControllerTests: XCTestCase {
    @MainActor
    func testInitialPhaseIsIdleWhenNoStoredID() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let controller = AuthController(userDefaults: defaults, storageKey: "k")
        XCTAssertEqual(controller.phase, .idle)
        XCTAssertNil(controller.storedAppleUserID)
    }

    @MainActor
    func testStoredAppleUserIDPersists() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let controller = AuthController(userDefaults: defaults, storageKey: "k")
        controller.storedAppleUserID = "user-123"
        XCTAssertEqual(controller.storedAppleUserID, "user-123")
        controller.storedAppleUserID = nil
        XCTAssertNil(controller.storedAppleUserID)
    }
}
