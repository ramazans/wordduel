import Foundation

/// İçerik türü. CoreModels'teki `ContentKind` ile bilinçli kopya —
/// WordRepository, SwiftData bağımlılığı Linux testlerini kıracağı için
/// CoreModels'e bağlanmaz; Features katmanı rawValue ile eşler.
public enum SeedKind: String, Codable, Sendable, CaseIterable {
    case word
    case idiom
    case phrasal
}

public struct SeedWord: Codable, Hashable, Sendable {
    public let text: String
    public let definition: String
    public let level: String
    public let kind: SeedKind

    public init(text: String, definition: String, level: String, kind: SeedKind = .word) {
        self.text = text
        self.definition = definition
        self.level = level
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey {
        case text, definition, level, kind
    }

    // `kind` alanı olmayan eski girişler `.word` sayılır; ileride eklenecek
    // bilinmeyen türler de dosyayı patlatmak yerine `.word`a düşer.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        definition = try container.decode(String.self, forKey: .definition)
        level = try container.decode(String.self, forKey: .level)
        let rawKind = try container.decodeIfPresent(String.self, forKey: .kind) ?? SeedKind.word.rawValue
        kind = SeedKind(rawValue: rawKind) ?? .word
    }
}

public enum SeedLoader {
    public enum LoadError: Error, Sendable {
        case resourceNotFound
        case decodeFailed(Error)
    }

    /// Paketin gömülü `SeedWords.json` dosyasını yükler.
    public static func load() throws -> [SeedWord] {
        try load(from: .module)
    }

    public static func load(from bundle: Bundle) throws -> [SeedWord] {
        guard let url = bundle.url(forResource: "SeedWords", withExtension: "json") else {
            throw LoadError.resourceNotFound
        }
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode([SeedWord].self, from: data)
        } catch {
            throw LoadError.decodeFailed(error)
        }
    }

    public static func decode(_ data: Data) throws -> [SeedWord] {
        do {
            return try JSONDecoder().decode([SeedWord].self, from: data)
        } catch {
            throw LoadError.decodeFailed(error)
        }
    }
}
