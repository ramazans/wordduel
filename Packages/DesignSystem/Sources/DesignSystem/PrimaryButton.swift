import SwiftUI

public struct PrimaryButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String?
    private let variant: WDProminentButtonStyle.Variant
    private let isLoading: Bool
    private let action: () -> Void

    public init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = role == .destructive ? .destructive : .primary
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(WDProminentButtonStyle(variant))
        .disabled(isLoading)
    }
}

public struct SecondaryButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String?
    private let action: () -> Void

    public init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(WDProminentButtonStyle(.secondary))
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton("Yeni Maç", systemImage: "plus.circle.fill") {}
        PrimaryButton("Yükleniyor", isLoading: true) {}
        PrimaryButton("Hesabı Sil", role: .destructive) {}
        SecondaryButton("Kodla Katıl", systemImage: "qrcode.viewfinder") {}
    }
    .padding()
}
