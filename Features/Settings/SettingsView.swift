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
    @Query private var players: [Player]
    @AppStorage("language") private var language: String = L10n.Language.system.rawValue
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @State private var notificationStatus: LocalNotificationScheduler.AuthorizationStatus = .notDetermined
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false

    var body: some View {
        Form {
            if let me {
                @Bindable var player = me
                Section {
                    HStack(spacing: 12) {
                        AvatarView(name: player.displayName, colorIndex: player.avatarColor, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Görünen Ad")
                                .font(.wdCaption)
                                .foregroundStyle(Color.wdInkSecondary)
                            TextField("Adını gir", text: $player.displayName)
                                .font(.wdHeadline)
                                .foregroundStyle(Color.wdInk)
                                .submitLabel(.done)
                        }
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: WDSpacing.sm) {
                        Label("Avatar Rengi", systemImage: "paintpalette.fill")
                            .font(.wdCaption)
                            .foregroundStyle(Color.wdInkSecondary)
                        HStack(spacing: WDSpacing.sm) {
                            ForEach(0..<AvatarPalette.colors.count, id: \.self) { i in
                                Button {
                                    player.avatarColor = i
                                } label: {
                                    Circle()
                                        .fill(AvatarPalette.colors[i])
                                        .frame(width: 32, height: 32)
                                        .overlay {
                                            if player.avatarColor == i {
                                                Circle()
                                                    .strokeBorder(.white, lineWidth: 2.5)
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .shadow(color: AvatarPalette.colors[i].opacity(0.4), radius: 4, x: 0, y: 2)
                                }
                                .buttonStyle(.plain)
                                .animation(.spring(duration: 0.2), value: player.avatarColor)
                            }
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Profil")
                }
            }

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

    private var me: Player? {
        guard let myAppleUserID else { return players.first }
        return players.first { $0.appleUserID == myAppleUserID }
    }

    private var myAppleUserID: String? {
        if case .signedIn(let id) = authController.phase { return id }
        return nil
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
