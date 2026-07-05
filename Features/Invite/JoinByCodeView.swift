import SwiftUI
import SwiftData
import CoreModels
import AuthService
import CloudKitService
import DesignSystem

struct JoinByCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthController.self) private var authController
    @Query private var players: [Player]
    @State private var viewModel: JoinByCodeViewModel
    @State private var isFinalizing = false
    @State private var finalizeError: String?

    private let syncService: MatchSyncService

    init(syncService: MatchSyncService) {
        self.syncService = syncService
        _viewModel = State(initialValue: JoinByCodeViewModel(syncService: syncService))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: WDSpacing.lg) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.wdAccent)
                    .frame(width: 64, height: 64)
                    .background(Color.wdAccent.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(spacing: WDSpacing.xs) {
                    Text("Davet kodunu gir")
                        .font(.wdTitle)
                        .foregroundStyle(Color.wdInk)
                    Text("Arkadaşının gönderdiği 6 haneli kodu yaz.")
                        .font(.wdSubheadline)
                        .foregroundStyle(Color.wdInkSecondary)
                        .multilineTextAlignment(.center)
                }

                CodeInputField(code: codeBinding)

                if let message = errorMessage {
                    HStack(spacing: WDSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.wdDanger)
                        Text(message)
                            .font(.wdCaption)
                            .foregroundStyle(Color.wdInk)
                    }
                    .padding(WDSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color.wdDanger.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
                    )
                }

                PrimaryButton("Katıl", isLoading: viewModel.state == .joining || isFinalizing) {
                    Task { await viewModel.submit() }
                }
                .disabled(!viewModel.canSubmit || isFinalizing)

                Spacer()
            }
            .padding()
            .padding(.top, WDSpacing.md)
            .wdScreenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Vazgeç") { dismiss() }
                }
            }
            .onChange(of: viewModel.state) { _, newState in
                if case .joined(let code) = newState {
                    Task { await finalizeJoin(code: code) }
                }
            }
        }
    }

    private var errorMessage: String? {
        if let finalizeError { return finalizeError }
        if case .error(let message) = viewModel.state { return message }
        return nil
    }

    /// Girişi anında normalize eder (büyük harf, karışan karakterler ayıklanır).
    private var codeBinding: Binding<String> {
        Binding(
            get: { viewModel.code },
            set: { viewModel.code = MatchCodeGenerator.normalize($0) }
        )
    }

    /// Kod doğrulandıktan sonra maç durumunu indirir, misafir koltuğunu kapar
    /// ve katılımı yayınlar. Başarılıysa sheet kapanır, maç Home'da belirir.
    private func finalizeJoin(code: String) async {
        guard case .signedIn(let myID) = authController.phase,
              let me = players.first(where: { $0.appleUserID == myID }) else {
            finalizeError = "Oturum bulunamadı. Yeniden giriş yapıp tekrar dene."
            return
        }

        isFinalizing = true
        finalizeError = nil
        let joined = await MatchCloudSync.join(
            code: code,
            meAppleUserID: me.appleUserID,
            meDisplayName: me.displayName,
            meAvatarColor: me.avatarColor,
            repository: syncService.stateRepository,
            context: modelContext
        )
        isFinalizing = false

        if joined {
            dismiss()
        } else {
            finalizeError = "Maça katılınamadı — koltuk dolu olabilir ya da maç verisi henüz ulaşmadı. Birkaç saniye sonra tekrar dene."
            viewModel.reset()
        }
    }
}

#Preview {
    JoinByCodeView(syncService: MatchSyncService(containerIdentifier: "iCloud.preview"))
        .modelContainer(for: [Player.self, Match.self, Round.self], inMemory: true)
        .environment(AuthController())
}
