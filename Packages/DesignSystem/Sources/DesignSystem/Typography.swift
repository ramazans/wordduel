import SwiftUI

public extension Font {
    static let wdLargeTitle = Font.largeTitle.weight(.bold)
    static let wdTitle = Font.title.weight(.semibold)
    static let wdHeadline = Font.headline
    static let wdBody = Font.body
    static let wdCaption = Font.caption
    static let wdMonoCode = Font.system(.largeTitle, design: .monospaced).weight(.bold)
    static let wdMonoSmall = Font.system(.body, design: .monospaced)
}
