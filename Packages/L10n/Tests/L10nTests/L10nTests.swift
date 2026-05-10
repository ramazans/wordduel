import XCTest
@testable import L10n

final class L10nTests: XCTestCase {
    func testSystemLocaleIsNil() {
        XCTAssertNil(L10n.locale(for: .system))
    }

    func testTurkishLocale() {
        XCTAssertEqual(L10n.locale(for: .turkish)?.identifier, "tr_TR")
    }

    func testEnglishLocale() {
        XCTAssertEqual(L10n.locale(for: .english)?.identifier, "en_US")
    }

    func testAllCases() {
        XCTAssertEqual(L10n.Language.allCases.count, 3)
    }
}
