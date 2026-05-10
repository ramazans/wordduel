import Foundation

/// 6 hane, ambiguous karakterler (0/O, 1/I/L) elenmiş davet kodu üretici.
/// Alphabet 32 karakter, 6 hane → ~10⁹ kombinasyon, kısa süreli unique olur.
public enum MatchCodeGenerator {
    public static let alphabet = Array("23456789ABCDEFGHJKMNPQRSTUVWXYZ")
    public static let codeLength = 6

    public static func generate<G: RandomNumberGenerator>(using generator: inout G) -> String {
        var code = ""
        code.reserveCapacity(codeLength)
        for _ in 0..<codeLength {
            let idx = Int.random(in: 0..<alphabet.count, using: &generator)
            code.append(alphabet[idx])
        }
        return code
    }

    public static func generate() -> String {
        var rng = SystemRandomNumberGenerator()
        return generate(using: &rng)
    }

    /// Kullanıcı girişini normalize eder: trim, uppercase, sadece izin verilen karakterler.
    public static func normalize(_ raw: String) -> String {
        let allowed = Set(alphabet)
        let upper = raw.uppercased()
        return String(upper.filter { allowed.contains($0) }).prefix(codeLength).description
    }

    public static func isValid(_ candidate: String) -> Bool {
        guard candidate.count == codeLength else { return false }
        let allowed = Set(alphabet)
        return candidate.allSatisfy { allowed.contains($0) }
    }
}
