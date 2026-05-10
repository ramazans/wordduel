import Foundation
import Observation
import CloudKitService

/// Uygulama düzeyinde paylaşılan servisler. Environment üzerinden view'lara geçer.
@Observable
@MainActor
public final class AppServices {
    public let matchSyncService: MatchSyncService

    public init(cloudKitContainerID: String) {
        self.matchSyncService = MatchSyncService(containerIdentifier: cloudKitContainerID)
    }
}
