import Foundation
import SwiftData

@Model
public final class WordEntry {
    @Attribute(.unique) public var text: String
    public var definition: String
    public var levelRaw: String
    public var language: String

    public var level: CEFRLevel {
        get { CEFRLevel(rawValue: levelRaw) ?? .b1 }
        set { levelRaw = newValue.rawValue }
    }

    public init(
        text: String,
        definition: String,
        level: CEFRLevel = .b1,
        language: String = "en"
    ) {
        self.text = text
        self.definition = definition
        self.levelRaw = level.rawValue
        self.language = language
    }
}
