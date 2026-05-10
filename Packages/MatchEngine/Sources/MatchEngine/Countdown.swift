import Foundation

/// Tur süresi geri sayımı için saf-Swift hesaplayıcı.
/// `TimelineView`'dan çağrılır; SwiftUI/UIKit bağımlılığı yok, test edilebilir.
public struct Countdown: Sendable, Equatable {
    public let startedAt: Date
    public let durationSeconds: Int

    public init(startedAt: Date, durationSeconds: Int) {
        self.startedAt = startedAt
        self.durationSeconds = max(0, durationSeconds)
    }

    /// Kalan saniye (negatif olmaz).
    public func remainingSeconds(now: Date) -> Int {
        let elapsed = max(0, Int(now.timeIntervalSince(startedAt)))
        return max(0, durationSeconds - elapsed)
    }

    public func isExpired(now: Date) -> Bool {
        remainingSeconds(now: now) == 0
    }

    public enum Severity: Sendable, Equatable {
        case normal      // > 10 sn
        case warning     // 1-10 sn
        case expired     // 0 sn
    }

    public func severity(now: Date) -> Severity {
        let remaining = remainingSeconds(now: now)
        if remaining == 0 { return .expired }
        if remaining <= 10 { return .warning }
        return .normal
    }
}
