import Foundation

/// Çoktan seçmeli sorular için şık üretici. Saf fonksiyon — soran cihazda
/// bir kez çalışır, üretilen liste Round'a serialize edilip CloudKit'le
/// taşınır; iki cihaz da aynı sırada aynı şıkları görür.
public enum OptionsBuilder {
    /// 4 şık: doğru cevap + aynı türden 3 farklı tanım, karıştırılmış.
    /// Aday önceliği: aynı tür + aynı seviye → aynı tür → tüm havuz.
    /// Havuz yetersizse eldeki kadar şıkla döner; çağıran `count < 4` ise
    /// çoktan seçmeli formatı kapatmalıdır.
    public static func multipleChoiceOptions(
        correct: String,
        kind: SeedKind,
        level: String?,
        pool: [SeedWord],
        using rng: inout some RandomNumberGenerator
    ) -> [String] {
        let normalizedCorrect = normalized(correct)
        var picked: [String] = []
        var pickedNormalized: Set<String> = [normalizedCorrect]

        // Öncelik katmanları: her katmanda karıştırıp eksik kalan şıkları doldur.
        let sameKind = pool.filter { $0.kind == kind }
        let tiers: [[SeedWord]] = [
            level.map { lvl in sameKind.filter { $0.level == lvl } } ?? [],
            sameKind,
            pool
        ]

        for tier in tiers where picked.count < 3 {
            for candidate in tier.shuffled(using: &rng) where picked.count < 3 {
                let key = normalized(candidate.definition)
                if !pickedNormalized.contains(key) {
                    pickedNormalized.insert(key)
                    picked.append(candidate.definition)
                }
            }
        }

        var options = picked + [correct]
        options.shuffle(using: &rng)
        return options
    }

    public static func multipleChoiceOptions(
        correct: String,
        kind: SeedKind,
        level: String?,
        pool: [SeedWord]
    ) -> [String] {
        var rng = SystemRandomNumberGenerator()
        return multipleChoiceOptions(correct: correct, kind: kind, level: level, pool: pool, using: &rng)
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
