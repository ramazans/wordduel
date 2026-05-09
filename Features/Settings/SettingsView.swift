import SwiftUI
import L10n

struct SettingsView: View {
    @AppStorage("language") private var language: String = L10n.Language.system.rawValue
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @State private var showDeleteConfirm = false

    var body: some View {
        Form {
            Section("Dil") {
                Picker("Dil", selection: $language) {
                    ForEach(L10n.Language.allCases, id: \.rawValue) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Bildirimler") {
                Toggle("\"Sıra sende\" bildirimleri", isOn: $notificationsEnabled)
            }

            Section {
                Button("Hesabı Sil", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
        }
        .navigationTitle("Ayarlar")
        .confirmationDialog(
            "Hesabı silmek istediğine emin misin?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) {
                // TODO Faz 6: CloudKit kayıtlarını temizle.
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Tüm maçların ve geçmişin kalıcı olarak silinecek.")
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
