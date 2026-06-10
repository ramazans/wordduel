import SwiftUI
import SwiftData
import L10n
import CoreModels
import CloudKitService
import AuthService
import DesignSystem

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var services
    @Environment(AuthController.self) private var authController
    @AppStorage("language") private var language: String = L10n.Language.system.rawValue
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @State private var notificationStatus: LocalNotificationScheduler.AuthorizationStatus = .notDetermined
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false

    var body: some View {
        Form {
            Section("Dil") {
                Picker(selection: $language) {
                    ForEach(L10n.Language.allCases, id: \.rawValue) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                } label: {
                    settingsLabel("Dil", systemImage: "globe", tint: .blue)
                }
                .pickerStyle(.menu)
            }

            Section {
                Toggle(isOn: $notificationsEnabled) {
                    settingsLabel("\"Sıra sende\" bildirimleri", systemImage: "bell.badge.fill", tint: .wdAccent)
                }
                .disabled(notificationStatus == .denied)

                if notificationStatus == .notDetermined {
                    Button {
                        Task { await requestNotificationAuthorization() }
                    } label: {
                        settingsLabel("Bildirimlere izin ver", systemImage: "checkmark.circle.fill", tint: .wdSuccess)
                    }
                } else if notificationStatus == .denied {
                    Button {
                        openAppSettings()
                    } label: {
                        settingsLabel("iOS Ayarlarında izin ver", systemImage: "arrow.up.forward.app.fill", tint: .wdInkSecondary)
                    }
                }
            } header: {
                Text("Bildirimler")
            } footer: {
                notificationFooter
            }

            Section {
                LabeledContent {
                    Text(appVersionString)
                } label: {
                    settingsLabel("Sürüm", systemImage: "info.circle.fill", tint: .wdInkSecondary)
                }
            } header: {
                Text("Hakkında")
            }

            Section {
                Button {
                    showSignOutConfirm = true
                } label: {
                    settingsLabel("Çıkış Yap", systemImage: "rectangle.portrait.and.arrow.right", tint: .wdInkSecondary)
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    settingsLabel("Hesabı Sil", systemImage: "trash.fill", tint: .wdDanger)
                        .foregroundStyle(Color.wdDanger)
                }
            } header: {
                Text("Hesap")
            } footer: {
                Text("Hesap silme tüm maçlarını ve geçmişini kalıcı olarak siler.")
            }
        }
        .navigationTitle("Ayarlar")
        .task { await refreshAuthorizationStatus() }
        .confirmationDialog(
            "Çıkış yapmak istediğine emin misin?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Çıkış Yap") {
                authController.signOut(modelContext: modelContext)
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Maçların silinmez; tekrar giriş yaptığında kaldığın yerden devam edersin.")
        }
        .confirmationDialog(
            "Hesabı silmek istediğine emin misin?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) {
                deleteAccount()
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Tüm maçların ve geçmişin kalıcı olarak silinecek.")
        }
    }

    /// Yerel + senkronize verileri siler ve oturumu kapatır. SwiftData'nın
    /// CloudKit aynası silmeleri private DB'ye de yansıtır.
    private func deleteAccount() {
        try? modelContext.delete(model: Match.self)
        try? modelContext.delete(model: Player.self)
        try? modelContext.save()
        authController.signOut(modelContext: modelContext)
    }

    /// iOS Ayarlar tarzı: renkli yuvarlatılmış karede ikon + başlık.
    private func settingsLabel(_ title: LocalizedStringKey, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.footnote)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(title)
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
        .modelContainer(for: [Player.self, Match.self, Round.self], inMemory: true)
        .environment(AuthController())
}
