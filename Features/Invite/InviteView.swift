import SwiftUI
import DesignSystem

struct InviteView: View {
    let code: String
    var onDismiss: () -> Void = {}

    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: WDSpacing.lg) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(LinearGradient.wdAccentGradient, in: Circle())
                    .shadow(color: Color.wdAccent.opacity(0.3), radius: 10, x: 0, y: 5)
                    .accessibilityHidden(true)

                VStack(spacing: WDSpacing.xs) {
                    Text("Düelloya davet et")
                        .font(.wdTitle)
                        .foregroundStyle(Color.wdInk)
                    Text("Arkadaşın bu kodla maça katılır katılmaz düello başlar.")
                        .font(.wdSubheadline)
                        .foregroundStyle(Color.wdInkSecondary)
                        .multilineTextAlignment(.center)
                }

                CodeDigitsView(code)

                HStack(spacing: WDSpacing.sm) {
                    Button {
                        copyCode()
                    } label: {
                        Label(copied ? "Kopyalandı" : "Kopyala",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(WDProminentButtonStyle(.secondary))
                    .sensoryFeedback(.success, trigger: copied) { _, newValue in newValue }

                    ShareLink(item: shareMessage) {
                        Label("Paylaş", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(WDProminentButtonStyle(.primary))
                }

                Spacer()
            }
            .padding()
            .padding(.top, WDSpacing.md)
            .wdScreenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat", action: onDismiss)
                }
            }
        }
    }

    private var shareMessage: String {
        "WordDuel'de seninle kelime düellosu yapmak istiyorum! Davet kodum: \(code)"
    }

    private func copyCode() {
        UIPasteboard.general.string = code
        withAnimation(.snappy) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.snappy) { copied = false }
        }
    }
}

#Preview {
    InviteView(code: "AB23K9")
}
