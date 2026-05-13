import Foundation
import Observation
import OSLog
import CloudKitService

@MainActor
@Observable
public final class JoinByCodeViewModel {
    public enum JoinState: Equatable {
        case idle
        case joining
        case joined(code: String)
        case error(String)
    }

    public var code: String = ""
    public private(set) var state: JoinState = .idle

    private let syncService: MatchSyncService
    private let logger = Logger(subsystem: "club.kadro.wordduel", category: "JoinByCode")

    public init(syncService: MatchSyncService) {
        self.syncService = syncService
    }

    public var canSubmit: Bool {
        let normalized = MatchCodeGenerator.normalize(code)
        return MatchCodeGenerator.isValid(normalized) && state != .joining
    }

    public func submit() async {
        let normalized = MatchCodeGenerator.normalize(code)
        logger.info("submit() called with raw='\(self.code, privacy: .public)' normalized='\(normalized, privacy: .public)' canSubmit=\(self.canSubmit)")
        guard MatchCodeGenerator.isValid(normalized) else {
            logger.warning("submit() aborted — invalid code length=\(normalized.count)")
            state = .error("Kod 6 hane olmalı.")
            return
        }
        state = .joining
        logger.info("submit() → state=.joining, calling acceptMatch")
        do {
            let info = try await syncService.acceptMatch(byCode: normalized)
            logger.info("submit() success: code=\(info.code, privacy: .public)")
            state = .joined(code: info.code)
        } catch let error as MatchSyncService.SyncError {
            logger.error("submit() SyncError: \(String(describing: error))")
            state = .error(message(for: error))
        } catch {
            logger.error("submit() unexpected error: \(String(describing: error))")
            state = .error(error.localizedDescription)
        }
    }

    public func reset() {
        state = .idle
    }

    private func message(for error: MatchSyncService.SyncError) -> String {
        switch error {
        case .codeNotFound:
            return "Kod bulunamadı. Tekrar dene."
        case .codeExpired:
            return "Kodun süresi dolmuş."
        case .accountUnavailable:
            return "iCloud kullanılamıyor."
        case .shareAcceptanceFailed(let detail):
            return "Davete katılınamadı: \(detail)"
        case .shareCreationFailed, .matchPersistenceFailed:
            return "Beklenmeyen bir hata oluştu."
        case .underlying(let detail):
            return "Hata: \(detail)"
        }
    }
}
