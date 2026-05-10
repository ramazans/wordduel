import Foundation
import Observation
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

    public init(syncService: MatchSyncService) {
        self.syncService = syncService
    }

    public var canSubmit: Bool {
        let normalized = MatchCodeGenerator.normalize(code)
        return MatchCodeGenerator.isValid(normalized) && state != .joining
    }

    public func submit() async {
        state = .joining
        let normalized = MatchCodeGenerator.normalize(code)
        do {
            let info = try await syncService.acceptMatch(byCode: normalized)
            state = .joined(code: info.code)
        } catch let error as MatchSyncService.SyncError {
            state = .error(message(for: error))
        } catch {
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
        case .shareCreationFailed, .matchPersistenceFailed, .underlying:
            return "Beklenmeyen bir hata oluştu."
        }
    }
}
