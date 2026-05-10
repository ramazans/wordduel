import SwiftUI
import DesignSystem

struct AskingView: View {
    @State private var mode: AskMode = .list
    @State private var searchText: String = ""
    @State private var customWord: String = ""
    @State private var customAnswer: String = ""

    enum AskMode: String, CaseIterable, Identifiable {
        case list, custom
        var id: Self { self }
        var label: String {
            switch self {
            case .list: return "Listeden seç"
            case .custom: return "Kendin yaz"
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Mod", selection: $mode) {
                ForEach(AskMode.allCases) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            switch mode {
            case .list:
                listMode
            case .custom:
                customMode
            }
        }
        .navigationTitle("Tur 4 / 10")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var listMode: some View {
        // TODO Faz 4: WordRepository üzerinden CEFR filtreli liste.
        List {
            Text("Kelime listesi (Faz 4)")
                .foregroundStyle(.secondary)
        }
        .searchable(text: $searchText)
    }

    private var customMode: some View {
        Form {
            TextField("Kelime", text: $customWord)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Beklenen anlam", text: $customAnswer)
            PrimaryButton("Sor") {
                // TODO: gönder.
            }
            .disabled(customWord.isEmpty || customAnswer.isEmpty)
        }
    }
}

#Preview {
    NavigationStack { AskingView() }
}
