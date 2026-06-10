import SwiftUI
import CloudKitService
import DesignSystem

struct JoinByCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: JoinByCodeViewModel

    init(syncService: MatchSyncService) {
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

                if case .error(let message) = viewModel.state {
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

                PrimaryButton("Katıl", isLoading: viewModel.state == .joining) {
                    Task { await viewModel.submit() }
                }
                .disabled(!viewModel.canSubmit)

                Spacer()
            }
            .padding()
            .padding(.top, WDSpacing.md)
            .background(Color.wdBackground)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Vazgeç") { dismiss() }
                }
            }
            .onChange(of: viewModel.state) { _, newState in
                if case .joined = newState {
                    dismiss()
                }
            }
        }
    }

    /// Girişi anında normalize eder (büyük harf, karışan karakterler ayıklanır).
    private var codeBinding: Binding<String> {
        Binding(
            get: { viewModel.code },
            set: { viewModel.code = MatchCodeGenerator.normalize($0) }
        )
    }
}

#Preview {
    JoinByCodeView(syncService: MatchSyncService(containerIdentifier: "iCloud.preview"))
}
