import XCTest
@testable import CloudKitService

final class CloudKitServiceTests: XCTestCase {
    func testServiceCanBeInstantiated() {
        let service = MatchSyncService(containerIdentifier: "iCloud.com.example.wordduel.test")
        XCTAssertNotNil(service)
    }
}
