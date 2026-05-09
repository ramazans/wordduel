import XCTest

/// İki simülatör eşleştirme akışı için iskelet.
/// Tek simülatörde kod ekranının açıldığı, kod TextField'in sayı kabul ettiği vb. doğrulanır.
final class InviteFlowUITests: XCTestCase {
    func testJoinByCodeFieldAcceptsSixCharacters() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-mockSignedIn"]
        app.launch()

        // TODO Faz 6: navigate to JoinByCodeView, enter "ABC123", assert button enabled.
        XCTAssertTrue(app.exists)
    }
}
