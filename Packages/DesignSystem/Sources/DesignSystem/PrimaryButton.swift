import SwiftUI

public struct PrimaryButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String?
    private let role: ButtonRole?
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
        self.role = role
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.wdHeadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isLoading)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton("Yeni Maç", systemImage: "plus.circle.fill") {}
        PrimaryButton("Yükleniyor", isLoading: true) {}
        PrimaryButton("Hesabı Sil", role: .destructive) {}
    }
    .padding()
}
