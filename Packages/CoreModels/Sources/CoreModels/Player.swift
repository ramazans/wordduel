import Foundation
import SwiftData

@Model
public final class Player {
    @Attribute(.unique) public var appleUserID: String
    public var displayName: String
    public var avatarColor: Int
    public var createdAt: Date

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
