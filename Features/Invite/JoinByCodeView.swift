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
        @Bindable var vm = viewModel

        NavigationStack {
            Form {
                Section {
                    TextField("6 haneli kod", text: $vm.code)
                        .font(.wdMonoSmall)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .onChange(of: vm.code) { _, newValue in
                            let normalized = MatchCodeGenerator.normalize(newValue)
                            if normalized != newValue {
                                vm.code = normalized
                            }
                        }
                } footer: {
                    Text("Sadece harf ve rakam. Karıştırılan karakterler (0/O, 1/I) kullanılmıyor.")
                        .font(.wdCaption)
                }

                Section {
                    PrimaryButton("Katıl", isLoading: viewModel.state == .joining) {
                        Task { await viewModel.submit() }
                    }
                    .disabled(!viewModel.canSubmit)
                } footer: {
                    Text("Normalized kod: \"\(MatchCodeGenerator.normalize(vm.code))\" — canSubmit: \(viewModel.canSubmit ? "evet" : "hayır")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if case .error(let message) = viewModel.state {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Kodla Katıl")
            .navigationBarTitleDisplayMode(.inline)
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
}

#Preview {
    JoinByCodeView(syncService: MatchSyncService(containerIdentifier: "iCloud.preview"))
}
