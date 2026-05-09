import XCTest
@testable import AuthService

final class AuthServiceTests: XCTestCase {
    @MainActor
    func testServiceCanBeInstantiated() {
        let service = AppleSignInService()
        XCTAssertNotNil(service)
    }
}
