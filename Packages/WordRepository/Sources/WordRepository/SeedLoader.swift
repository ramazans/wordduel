import Foundation

public struct SeedWord: Codable, Hashable, Sendable {
    public let text: String
    public let definition: String
    public let level: String

    public init(text: String, definition: String, level: String) {
        self.text = text
        self.definition = definition
        self.level = level
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
