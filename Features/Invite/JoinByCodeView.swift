import SwiftUI
import DesignSystem

struct JoinByCodeView: View {
    @State private var code: String = ""
    @State private var isJoining = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("6 haneli kod", text: $code)
                        .font(.wdMonoSmall)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                }

                Section {
                    PrimaryButton("Katıl", isLoading: isJoining) {
                        join()
                    }
                    .disabled(code.count != 6)
                }
            }
            .navigationTitle("Kodla Katıl")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func join() {
        isJoining = true
        // TODO Faz 4: CloudKitService.acceptMatch(byCode:) çağır.
    }
}

#Preview {
    JoinByCodeView()
}
