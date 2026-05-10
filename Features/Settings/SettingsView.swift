import SwiftUI
import L10n
import CloudKitService

struct SettingsView: View {
    @Environment(AppServices.self) private var services
    @AppStorage("language") private var language: String = L10n.Language.system.rawValue
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @State private var notificationStatus: LocalNotificationScheduler.AuthorizationStatus = .notDetermined
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

            Section {
                Toggle("\"Sıra sende\" bildirimleri", isOn: $notificationsEnabled)
                    .disabled(notificationStatus == .denied)
                if notificationStatus == .notDetermined {
                    Button("Bildirimlere izin ver") {
                        Task { await requestNotificationAuthorization() }
                    }
                } else if notificationStatus == .denied {
                    Button("iOS Ayarlarında izin ver") {
                        openAppSettings()
                    }
                }
            } header: {
                Text("Bildirimler")
            } footer: {
                notificationFooter
            }

            Section {
                Button("Hesabı Sil", role: .destructive) {
                    showDeleteConfirm = true
                }
            }

            Section {
                LabeledContent("Sürüm", value: appVersionString)
            } header: {
                Text("Hakkında")
            }
        }
        .navigationTitle("Ayarlar")
        .task { await refreshAuthorizationStatus() }
        .confirmationDialog(
            "Hesabı silmek istediğine emin misin?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) {
                // TODO: CloudKit kayıtlarını temizle, AuthController.signOut çağır.
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Tüm maçların ve geçmişin kalıcı olarak silinecek.")
        }
    }

    @ViewBuilder
    private var notificationFooter: some View {
        switch notificationStatus {
        case .denied:
            Text("Bildirimler iOS Ayarları'ndan kapalı. Açmak için iOS Ayarları'na git.")
        case .notDetermined:
            Text("Sıra sana geldiğinde haberdar olmak için bildirimlere izin ver.")
        case .provisional, .ephemeral, .authorized:
            Text("Sıra sende olduğunda lokal bildirim gönderilir.")
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    private func refreshAuthorizationStatus() async {
        notificationStatus = await services.notificationScheduler.authorizationStatus()
    }

    private func requestNotificationAuthorization() async {
        _ = try? await services.notificationScheduler.requestAuthorization()
        await refreshAuthorizationStatus()
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
