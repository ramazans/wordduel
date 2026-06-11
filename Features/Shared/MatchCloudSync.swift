import Foundation
import SwiftData
import OSLog
import CoreModels
import CloudKitService

/// Yerel SwiftData maçı ile public DB'deki revizyon zinciri arasında köprü.
///
/// Disiplin: her cihaz yalnızca KENDİ aksiyonunu push'lar (soran kelimeyi,
/// cevaplayan cevabı, misafir katılımı). Pull, yalnızca yerel revizyondan
/// yüksek uzak revizyonları sırayla uygular — kendi push'larımız zincirde
/// zaten işaretli olduğu için asla yeniden uygulanmaz.
@MainActor
enum MatchCloudSync {
    private static let logger = Logger(subsystem: "club.kadro.wordduel", category: "MatchCloudSync")
    private static let maxRevisionsPerPull = 200

    /// Yerel mutasyonu yeni revizyon olarak yayınlar.
    /// Revizyon çakışırsa (karşı taraf aynı anda yazdıysa) pull ile uzlaşır.
    static func push(_ match: Match, repository: MatchStateRepository, context: ModelContext) async {
        let next = match.syncRevision + 1
        do {
            let payload = try MatchStateSnapshot(match: match, revision: next).encoded()
            try await repository.push(code: match.code, revision: next, payload: payload)
            match.syncRevision = next
            try? context.save()
            logger.info("push ok: \(match.code, privacy: .public) rev=\(next)")
        } catch MatchStateRepository.StateError.revisionConflict {
            logger.warning("push conflict: \(match.code, privacy: .public) rev=\(next) — pull ile uzlaşılıyor")
            _ = await pull(match, repository: repository, context: context)
        } catch {
            logger.error("push failed: \(String(describing: error))")
        }
    }

    /// Uzak zincirde yerelden yeni revizyonları indirir ve uygular.
    /// - Returns: en az bir revizyon uygulandıysa `true`.
    @discardableResult
    static func pull(_ match: Match, repository: MatchStateRepository, context: ModelContext) async -> Bool {
        var applied = false
        var safety = 0
        while safety < maxRevisionsPerPull {
            safety += 1
            let next = match.syncRevision + 1
            let payload: Data?
            do {
                payload = try await repository.fetch(code: match.code, revision: next)
            } catch {
                logger.error("pull fetch failed: \(String(describing: error))")
                break
            }
            guard let payload else { break }

            do {
                let snapshot = try MatchStateSnapshot.decode(payload)
                snapshot.apply(to: match, in: context)
                applied = true
                logger.info("pull applied: \(match.code, privacy: .public) rev=\(next)")
            } catch {
                // Bozuk revizyonu atla ama zinciri kilitleme.
                logger.error("pull decode failed rev=\(next): \(String(describing: error))")
                match.syncRevision = next
                applied = true
            }
        }
        if applied {
            try? context.save()
        }
        return applied
    }

    /// Verilen koddaki maçı yerelde bulur veya boş kabuk oluşturup zinciri indirir.
    /// - Returns: en az 1 revizyon içeren (host'u bilinen) maç; yoksa `nil`.
    static func materialize(code: String, repository: MatchStateRepository, context: ModelContext) async -> Match? {
        let existing = try? context.fetch(
            FetchDescriptor<Match>(predicate: #Predicate { $0.code == code })
        ).first

        let match: Match
        if let existing {
            match = existing
        } else {
            match = Match(code: code)
            context.insert(match)
        }

        await pull(match, repository: repository, context: context)

        guard match.syncRevision >= 1, match.host != nil else {
            // Host henüz ilk durumu yayınlamamış — kabuğu temizle.
            if existing == nil {
                context.delete(match)
                try? context.save()
            }
            return nil
        }
        return match
    }

    /// Misafir katılımı: maçı indir, koltuğu kap, aktifleştir ve yayınla.
    static func join(
        code: String,
        meAppleUserID: String,
        meDisplayName: String,
        meAvatarColor: Int,
        repository: MatchStateRepository,
        context: ModelContext
    ) async -> Bool {
        guard let match = await materialize(code: code, repository: repository, context: context) else {
            return false
        }

        // Zaten bu maçtayım (yeniden katılma) — başarılı say.
        if match.guest?.appleUserID == meAppleUserID || match.host?.appleUserID == meAppleUserID {
            return true
        }
        // Koltuk doluysa katılamam.
        guard match.guest == nil else { return false }

        let snapshot = MatchStateSnapshot.PlayerSnapshot(
            appleUserID: meAppleUserID,
            displayName: meDisplayName,
            avatarColor: meAvatarColor
        )
        var state = MatchStateSnapshot(match: match, revision: match.syncRevision)
        state.guest = snapshot
        state.statusRaw = MatchStatus.active.rawValue
        state.apply(to: match, in: context)
        try? context.save()

        await push(match, repository: repository, context: context)
        return true
    }
}
