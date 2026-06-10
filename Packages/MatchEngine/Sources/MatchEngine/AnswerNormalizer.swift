import Foundation

public enum AnswerNormalizer {
    public static func normalize(_ raw: String) -> String {
        let lowered = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "en_US"))
            .lowercased()
        return lowered
    }

    /// Levenshtein toleransı kelime uzunluğuna göre belirlenir.
    /// < 5 → 0 (tam eşleşme), 5–7 → 1, 8+ → 2.
    public static func tolerance(for expectedLength: Int) -> Int {
        switch expectedLength {
        case ..<5: return 0
        case 5...7: return 1
        default: return 2
        }
    }

    public static func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count
        if m == 0 { return n }
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                curr[j] = min(
                    curr[j - 1] + 1,         // insertion
                    prev[j] + 1,              // deletion
                    prev[j - 1] + cost        // substitution
                )
            }
            swap(&prev, &curr)
        }
        return prev[n]
    }

    public enum AutoVerdict: Equatable, Sendable {
        case correct
        case wrong
        case needsManualReview
    }

    public static func autoJudge(answer: String, expected: String) -> AutoVerdict {
        let a = normalize(answer)
        let e = normalize(expected)
        if a.isEmpty { return .wrong }
        if a == e { return .correct }
        let allowed = tolerance(for: e.count)
        if allowed == 0 { return .needsManualReview }
        let distance = levenshtein(a, e)
        if distance <= allowed { return .correct }
        return .needsManualReview
    }
}
