import XCTest
import CloudKit
@testable import CloudKitService

final class CloudKitServiceTests: XCTestCase {
    func testServiceCanBeInstantiated() {
        let service = MatchSyncService(containerIdentifier: "iCloud.com.example.wordduel.test")
        XCTAssertNotNil(service)
    }

    func testCloudKitAccountExposesContainerIdentifier() {
        let account = CloudKitAccount(containerIdentifier: "iCloud.test")
        XCTAssertEqual(account.containerIdentifier, "iCloud.test")
    }
}

final class CloudKitAccountAvailabilityTests: XCTestCase {
    func testAvailableMaps() {
        XCTAssertEqual(CloudKitAccount.map(.available), .available)
    }

    func testNoAccountMaps() {
        XCTAssertEqual(CloudKitAccount.map(.noAccount), .noAccount)
    }

    func testRestrictedMaps() {
        XCTAssertEqual(CloudKitAccount.map(.restricted), .restricted)
    }

    func testCouldNotDetermineMaps() {
        XCTAssertEqual(CloudKitAccount.map(.couldNotDetermine), .couldNotDetermine)
    }

    func testTemporarilyUnavailableMaps() {
        XCTAssertEqual(CloudKitAccount.map(.temporarilyUnavailable), .temporarilyUnavailable)
    }

    func testIsAvailableOnlyForAvailable() {
        XCTAssertTrue(CloudKitAccount.Availability.available.isAvailable)
        XCTAssertFalse(CloudKitAccount.Availability.noAccount.isAvailable)
        XCTAssertFalse(CloudKitAccount.Availability.restricted.isAvailable)
    }

    func testUserMessageEmptyOnlyWhenAvailable() {
        XCTAssertTrue(CloudKitAccount.Availability.available.userMessage.isEmpty)
        XCTAssertFalse(CloudKitAccount.Availability.noAccount.userMessage.isEmpty)
        XCTAssertFalse(CloudKitAccount.Availability.restricted.userMessage.isEmpty)
    }
}
