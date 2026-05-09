import XCTest
@testable import DesignSystem

final class DesignSystemTests: XCTestCase {
    func testAvatarPaletteWraps() {
        XCTAssertEqual(AvatarPalette.color(for: 0), AvatarPalette.colors[0])
        XCTAssertEqual(AvatarPalette.color(for: 8), AvatarPalette.colors[0])
        XCTAssertEqual(AvatarPalette.color(for: -1), AvatarPalette.colors[7])
    }
}
