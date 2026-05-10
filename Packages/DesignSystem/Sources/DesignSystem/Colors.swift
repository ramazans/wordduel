import SwiftUI

public extension Color {
    static let wdAccent = Color("AccentColor", bundle: .main)
    static let wdBackground = Color(.systemBackground)
    static let wdSecondaryBackground = Color(.secondarySystemBackground)
    static let wdSeparator = Color(.separator)

    static let wdSuccess = Color.green
    static let wdWarning = Color.orange
    static let wdDanger = Color.red

    static let wdTimerNormal = Color.primary
    static let wdTimerCritical = Color.red
}

public enum AvatarPalette {
    public static let colors: [Color] = [
        .blue, .purple, .pink, .orange, .yellow, .green, .teal, .indigo
    ]

    public static func color(for index: Int) -> Color {
        colors[((index % colors.count) + colors.count) % colors.count]
    }
}
