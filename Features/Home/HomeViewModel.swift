import Foundation
import Observation
import SwiftData
import CoreModels
import CloudKitService

@MainActor
@Observable
public final class HomeViewModel {
    public enum CreateState: Equatable {
        case idle
        case creating
        case created(code: String, shareURL: URL)
        case error(String)
    }

    public private(set) var createState: CreateState = .idle

    private let syncService: MatchSyncService

    public init(syncService: MatchSyncService) {
        self.syncService = syncService
    }

    public func createMatch(host: Player, modelContext: ModelContext) async {
        createState = .creating
        do {
            let result = try await syncService.createMatch(host: host, modelContext: modelContext)
            createState = .created(code: result.code, shareURL: result.shareURL)
        } catch let error as MatchSyncService.SyncError {
            createState = .error(message(for: error))
        } catch {
            createState = .error(error.localizedDescription)
        }
    }

    public func dismissCreatedSheet() {
        createState = .idle
    }

    private func message(for error: MatchSyncService.SyncError) -> String {
        switch error {
        case .accountUnavailable:
            return "iCloud kullanılamıyor."
        case .shareCreationFailed(let detail):
            return "Davet oluşturulamadı: \(detail)"
        case .matchPersistenceFailed(let detail):
            return "Maç kaydedilemedi: \(detail)"
        case .codeNotFound, .codeExpired, .shareAcceptanceFailed, .underlying:
            return "Beklenmeyen bir hata oluştu."
        }
    }
}
