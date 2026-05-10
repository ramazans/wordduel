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
    func testDefaultDisplayNameUsesSuffix() {
        XCTAssertEqual(PlayerUpsert.defaultDisplayName(for: "001234.abcd"), "Player-abcd")
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
