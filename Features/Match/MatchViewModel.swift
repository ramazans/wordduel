import Foundation
import Observation
import CoreModels
import MatchEngine

/// UI state + MatchEngine köprüsü. Faz 3'te ve Faz 4'te genişletilecek.
@MainActor
@Observable
public final class MatchViewModel {
    public enum Phase: Equatable {
        case waiting
        case asking
        case answering
        case reviewing
        case finished
    }

    public var phase: Phase = .waiting
    public var currentWord: String = ""
    public var currentExpected: String = ""
    public var answerDraft: String = ""
    public var hostScore: Int = 0
    public var guestScore: Int = 0
    public var roundIndex: Int = 0
    public var totalRounds: Int = 10
    public var timerSeconds: Int = 30

    private let engine: MatchEngine

    public init(config: MatchEngine.Config = .init()) {
        self.engine = MatchEngine(config: config)
        self.totalRounds = config.totalRounds
    }

    public func submitAnswer() async {
        // TODO Faz 3: engine.resolve(...) çağır, snapshot ile state güncelle.
    }
}
