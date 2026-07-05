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

    /// Beklenen cevabın eş anlamlı varyantları: "," ve ";" ile bölünmüş
    /// parçalar + tam string. "vazgeçmek, bırakmak" → ["vazgeçmek, bırakmak",
    /// "vazgeçmek", "bırakmak"]. Tek parçalıysa yalnızca tam string döner.
    public static func expectedVariants(_ expected: String) -> [String] {
        let full = expected.trimmingCharacters(in: .whitespacesAndNewlines)
        var variants: [String] = full.isEmpty ? [] : [full]
        let parts = expected
            .components(separatedBy: CharacterSet(charactersIn: ",;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for part in parts where !variants.contains(part) {
            variants.append(part)
        }
        return variants
    }

    /// Beklenen cevap virgül/noktalı virgülle ayrılmış eş anlamlılar içerebilir;
    /// herhangi bir varyant kendi uzunluk toleransı içinde eşleşirse doğru sayılır.
    /// Hiçbiri eşleşmezse (boş cevap hariç) manuel incelemeye düşer — boş olmayan
    /// bir cevap asla otomatik yanlış sayılmaz.
    public static func autoJudge(answer: String, expected: String) -> AutoVerdict {
        let a = normalize(answer)
        if a.isEmpty { return .wrong }

        for variant in expectedVariants(expected) {
            let e = normalize(variant)
            if a == e { return .correct }
            let allowed = tolerance(for: e.count)
            if allowed > 0, levenshtein(a, e) <= allowed { return .correct }
        }
        return .needsManualReview
    }
}
