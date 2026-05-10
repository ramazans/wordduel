import XCTest

/// XCUITest iskeleti — gerçek akışlar Faz 6'da doldurulacak.
final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingShowsSignInButton() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-resetState"]
        app.launch()

        let signInButton = app.buttons["Sign in with Apple"].firstMatch
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
    }
}
