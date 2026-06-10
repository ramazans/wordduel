import SwiftUI

public extension Font {
    // Başlıklar — yuvarlatılmış (rounded) tasarım, sıcak ve oyunsu.
    static let wdDisplay = Font.system(size: 34, weight: .bold, design: .rounded)
    static let wdLargeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let wdTitle = Font.system(.title2, design: .rounded).weight(.bold)
    static let wdHeadline = Font.system(.headline, design: .rounded)

    // Gövde
    static let wdBody = Font.body
    static let wdSubheadline = Font.subheadline
    static let wdCaption = Font.caption
    /// Rozet ve çip etiketleri.
    static let wdLabel = Font.system(.footnote, design: .rounded).weight(.semibold)

    // Skor & kod
    static let wdScore = Font.system(size: 56, weight: .heavy, design: .rounded)
    static let wdMonoCode = Font.system(.largeTitle, design: .monospaced).weight(.bold)
    static let wdMonoSmall = Font.system(.body, design: .monospaced)
}
