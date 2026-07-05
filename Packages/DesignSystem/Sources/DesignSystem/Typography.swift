import SwiftUI

// King Style tipografi: baştan aşağı yuvarlatılmış (rounded) ve dolgun.
// Başlıklar ekstra kalın — şeker oyunu enerjisi; gövde de rounded kalır.
public extension Font {
    // Başlıklar
    static let wdDisplay = Font.system(size: 34, weight: .heavy, design: .rounded)
    static let wdLargeTitle = Font.system(.largeTitle, design: .rounded).weight(.heavy)
    static let wdTitle = Font.system(.title2, design: .rounded).weight(.heavy)
    static let wdHeadline = Font.system(.headline, design: .rounded).weight(.bold)

    // Gövde
    static let wdBody = Font.system(.body, design: .rounded)
    static let wdSubheadline = Font.system(.subheadline, design: .rounded).weight(.medium)
    static let wdCaption = Font.system(.caption, design: .rounded).weight(.medium)
    /// Rozet ve çip etiketleri.
    static let wdLabel = Font.system(.footnote, design: .rounded).weight(.bold)

    // Skor & kod
    static let wdScore = Font.system(size: 56, weight: .black, design: .rounded)
    static let wdMonoCode = Font.system(.largeTitle, design: .monospaced).weight(.bold)
    static let wdMonoSmall = Font.system(.body, design: .monospaced)
}
