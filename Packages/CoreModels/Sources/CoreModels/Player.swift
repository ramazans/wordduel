import Foundation
import SwiftData

@Model
public final class Player {
    public var appleUserID: String = ""
    public var displayName: String = ""
    public var avatarColor: Int = 0
    public var createdAt: Date = Date()

    // Inverse relationships for CloudKit-compatibility (Match.host / Match.guest)
    @Relationship(inverse: \Match.host)
    public var hostedMatches: [Match]? = nil

    @Relationship(inverse: \Match.guest)
    public var guestedMatches: [Match]? = nil

    public init(
        appleUserID: String,
        displayName: String,
        avatarColor: Int = 0,
        createdAt: Date = .now
    ) {
        self.appleUserID = appleUserID
        self.displayName = displayName
        self.avatarColor = avatarColor
        self.createdAt = createdAt
    }
}
