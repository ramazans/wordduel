import SwiftUI
import SwiftData
import CoreModels
import AuthService
import DesignSystem

/// Giriş sonrası, gerçek bir ad belirlenememişse (Apple ad göndermedi ve
/// Keychain'de kayıt yok) gösterilen tek alanlı isim ekranı. Kullanıcı her
/// zaman gerçek bir adla devam eder; girdiği ad SwiftData'ya ve Keychain'e
/// yazılır (reinstall'da kurtarılır). Ad gerçekleşince `AppRoot` HomeView'a geçer.
struct NameEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthController.self) private var authController
    @Bindable var player: Player

    @State private var name: String = ""
    @FocusState private var focused: Bool

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var canContinue: Bool {
        Player.isRealName(trimmed)
    }

    var body: some View {
        VStack(spacing: WDSpacing.lg) {
            Spacer()

            AvatarView(
                name: canContinue ? trimmed : "?",
                colorIndex: player.avatarColor,
                size: 96
            )
            .animation(.snappy, value: trimmed)

            VStack(spacing: WDSpacing.sm) {
                Text("Adın ne?")
                    .font(.wdLargeTitle)
                    .foregroundStyle(Color.wdInk)
                Text("Rakiplerin seni bu adla görecek. İstediğin zaman Ayarlar'dan değiştirebilirsin.")
                    .font(.wdBody)
                    .foregroundStyle(Color.wdInkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, WDSpacing.xl)
            }

            TextField("Adın", text: $name)
                .font(.wdTitle)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focused)
                .padding()
                .background(
                    Color.wdSurface,
                    in: RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
                )
                .padding(.horizontal)
                .onSubmit(commit)

            Spacer()

            Button(action: commit) {
                Text("Devam Et")
                    .font(.wdHeadline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        canContinue ? Color.wdAccent : Color.wdSeparator,
                        in: RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
                    )
                    .foregroundStyle(.white)
            }
            .disabled(!canContinue)
            .padding(.horizontal)
            .padding(.bottom, WDSpacing.lg)
        }
        .background(onboardingBackground)
        .onAppear {
            // Placeholder ile başlama — kullanıcı temiz bir alan görsün.
            if Player.isRealName(player.displayName) {
                name = player.displayName
            }
            focused = true
        }
    }

    private func commit() {
        guard canContinue else { return }
        player.displayName = trimmed
        try? modelContext.save()
        authController.rememberDisplayName(trimmed)
    }

    private var onboardingBackground: some View {
        ZStack {
            Color.wdBackground
            LinearGradient(
                colors: [Color.wdAccent.opacity(0.1), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
    }
}
