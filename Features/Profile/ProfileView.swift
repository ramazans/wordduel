import SwiftUI
import SwiftData
import CoreModels
import AuthService
import DesignSystem

struct ProfileView: View {
    @Environment(AuthController.self) private var authController
    @Query private var players: [Player]
    @Query private var matches: [Match]

    var body: some View {
        ScrollView {
            VStack(spacing: WDSpacing.lg) {
                if let me {
                    profileHeader(me)
                    statsCard
                }

                VStack(spacing: 0) {
                    linkRow(
                        title: "Tüm Maçlar",
                        systemImage: "clock.arrow.circlepath",
                        tint: .blue
                    ) {
                        HistoryView()
                    }
                    Divider()
                        .padding(.leading, 60)
                    linkRow(
                        title: "Ayarlar",
                        systemImage: "gearshape.fill",
                        tint: Color.wdInkSecondary
                    ) {
                        SettingsView()
                    }
                }
                .wdCard(padding: WDSpacing.xs)
            }
            .padding()
        }
        .wdScreenBackground()
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func profileHeader(_ me: Player) -> some View {
        VStack(spacing: WDSpacing.sm) {
            AvatarView(name: me.displayName, colorIndex: me.avatarColor, size: 88)
            Text(me.displayName)
                .font(.wdTitle)
                .foregroundStyle(Color.wdInk)
            Text("Üyelik: \(me.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.wdCaption)
                .foregroundStyle(Color.wdInkSecondary)
        }
        .padding(.top, WDSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    private var statsCard: some View {
        let record = MatchStats(myAppleUserID: myAppleUserID).record(for: matches)

        return HStack {
            statColumn(value: record.wins, label: "Galibiyet", tint: .wdSuccess)
            statDivider
            statColumn(value: record.draws, label: "Beraberlik", tint: .wdInkSecondary)
            statDivider
            statColumn(value: record.losses, label: "Mağlubiyet", tint: .wdDanger)
        }
        .wdCard(padding: WDSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.wins) galibiyet, \(record.draws) beraberlik, \(record.losses) mağlubiyet")
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.wdSeparator.opacity(0.4))
            .frame(width: 0.5, height: 40)
    }

    private func statColumn(value: Int, label: String, tint: Color) -> some View {
        VStack(spacing: WDSpacing.xs) {
            Text("\(value)")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(.wdCaption)
                .foregroundStyle(Color.wdInkSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func linkRow(
        title: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        @ViewBuilder destination: () -> some View
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: WDSpacing.md) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(title)
                    .font(.wdHeadline)
                    .foregroundStyle(Color.wdInk)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.wdInkSecondary)
            }
            .padding(12)
        }
        .buttonStyle(WDPressableButtonStyle())
    }

    private var me: Player? {
        guard let myAppleUserID else { return players.first }
        return players.first { $0.appleUserID == myAppleUserID }
    }

    private var myAppleUserID: String? {
        if case .signedIn(let id) = authController.phase { return id }
        return nil
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .modelContainer(for: [Player.self, Match.self, Round.self], inMemory: true)
        .environment(AuthController())
}
