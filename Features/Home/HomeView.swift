import SwiftUI
import SwiftData
import CoreModels
import CloudKitService
import AuthService
import DesignSystem

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var services
    @Environment(AuthController.self) private var authController
    @Query(sort: \Match.createdAt, order: .reverse) private var matches: [Match]
    @Query private var players: [Player]
    @State private var viewModel: HomeViewModel?
    @State private var showJoinSheet = false
    @State private var reinvite: ReinviteCode?
    /// Rakip koda katılınca host cihazında otomatik açılacak maç.
    @State private var openedMatch: Match?
    /// Rekabet slider'ında o an görünen rakip (sayfa noktaları için).
    @State private var activeRivalID: String?

    private struct ReinviteCode: Identifiable {
        let code: String
        var id: String { code }
    }

    var body: some View {
        NavigationStack {
            content
                .background(Color.wdBackground)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { profileToolbar }
                .safeAreaInset(edge: .bottom) { actionBar }
                .sheet(isPresented: createdBinding) {
                    if case .created(let code, _) = viewModel?.createState {
                        InviteView(code: code) {
                            viewModel?.dismissCreatedSheet()
                        }
                        .presentationDetents([.medium])
                    }
                }
                .sheet(item: $reinvite) { invite in
                    InviteView(code: invite.code) {
                        reinvite = nil
                    }
                    .presentationDetents([.medium])
                }
                .sheet(isPresented: $showJoinSheet) {
                    JoinByCodeView(syncService: services.matchSyncService)
                        .presentationDetents([.medium])
                }
                .navigationDestination(item: $openedMatch) { match in
                    MatchDetailView(match: match) {
                        Task { await createNewMatch() }
                    }
                }
                .task {
                    if viewModel == nil {
                        viewModel = HomeViewModel(syncService: services.matchSyncService)
                    }
                    // Rakibin hamleleri (katılım, maç bitişi) anasayfadayken de
                    // görünsün diye periyodik yoklama — maç bitince skor kartı
                    // ve Ezeli Rekabet anında güncellenir.
                    while !Task.isCancelled {
                        await pullRemoteUpdates()
                        handleHostMatchActivation()
                        await scheduleTurnNotifications()
                        try? await Task.sleep(for: .seconds(5))
                    }
                }
                .task {
                    for await _ in services.pushUpdates {
                        await pullRemoteUpdates()
                        handleHostMatchActivation()
                        await scheduleTurnNotifications()
                    }
                }
        }
    }

    // MARK: - Layout

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WDSpacing.lg) {
                greetingHeader

                rivalrySection

                if case .error(let message) = viewModel?.createState {
                    errorBanner(message)
                }

                matchSections
            }
            .padding(.horizontal)
            .padding(.bottom, WDSpacing.md)
        }
        .refreshable {
            await pullRemoteUpdates()
            await scheduleTurnNotifications()
        }
    }

    @ToolbarContentBuilder
    private var profileToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
                ProfileView()
            } label: {
                Image(systemName: "ellipsis")
                    .fontWeight(.semibold)
            }
            .accessibilityLabel("Profil ve ayarlar")
        }
    }

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: WDSpacing.xs) {
            Text(greetingTitle)
                .font(.wdDisplay)
                .foregroundStyle(Color.wdInk)
            Text(greetingSubtitle)
                .font(.wdSubheadline)
                .foregroundStyle(Color.wdInkSecondary)
        }
        .padding(.top, WDSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    /// Her rakip için ayrı bir kafa kafaya kartı; birden fazla rakip varsa
    /// yatay kaydırılabilir slider olarak gösterilir (en son oynanan başta).
    @ViewBuilder
    private var rivalrySection: some View {
        let rivals = MatchStats(myAppleUserID: myAppleUserID()).rivals(from: matches)

        if rivals.isEmpty {
            inviteTeaserCard
        } else if rivals.count == 1 {
            rivalryCard(rivals[0])
        } else {
            rivalrySlider(rivals)
        }
    }

    /// Ekran kenarındaki yatay iç boşluk (içerik VStack'inin `.padding(.horizontal)`'ı).
    private var screenInset: CGFloat { WDSpacing.md }
    /// Kartın iç içeriği için sabit yükseklik — tüm sayfalar eşit görünsün ve
    /// "X beraberlik" satırı eklendiğinde içerik kırpılmasın diye.
    private var rivalryContentHeight: CGFloat { 208 }
    /// Kart gölgesinin (radius 12) kırpılmadan görünmesi için bırakılan boşluk.
    private var rivalryShadowPadding: CGFloat { WDSpacing.md }

    /// Yatay, sayfalı rekabet slider'ı. Bir sonraki kartın bir kısmı görünür
    /// kalır ki kullanıcı kaydırılabileceğini anlasın; gölgelerin kırpılmaması
    /// için scroll içeriği hem dikey hem yatay yönde nefes payıyla yerleştirilir.
    private func rivalrySlider(_ rivals: [MatchStats.RivalRecord]) -> some View {
        // Kartın toplam yüksekliği = iç içerik + .wdCard'ın dikey padding'i (2×lg).
        let cardHeight = rivalryContentHeight + WDSpacing.lg * 2
        let active = activeRivalID ?? rivals.first?.id

        return VStack(spacing: WDSpacing.sm) {
            GeometryReader { geo in
                // Bir sonraki kartın ucu görünsün diye karta tam genişlikten
                // biraz dar bir genişlik veriyoruz.
                let peek = WDSpacing.xl + WDSpacing.sm // ~40pt
                let cardWidth = max(0, geo.size.width - screenInset * 2 - peek)

                ScrollView(.horizontal) {
                    HStack(spacing: WDSpacing.md) {
                        ForEach(rivals) { rival in
                            rivalryCard(rival, fixedContentHeight: rivalryContentHeight)
                                .frame(width: cardWidth)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, rivalryShadowPadding)
                }
                .contentMargins(.horizontal, screenInset, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $activeRivalID, anchor: .leading)
                .scrollIndicators(.hidden)
            }
            .frame(height: cardHeight + rivalryShadowPadding * 2)
            // İçerik VStack'inin yatay padding'ini iptal et: scroll tam ekran
            // genişliğinde olsun, kenar kartların gölgesi kırpılmasın.
            .padding(.horizontal, -screenInset)

            rivalryPageDots(rivals: rivals, active: active)
        }
    }

    /// Slider'ın altındaki sayfa noktaları — açık zeminde görünür olsun diye
    /// TabView'ın varsayılan noktaları yerine token renkleriyle çizilir.
    private func rivalryPageDots(rivals: [MatchStats.RivalRecord], active: String?) -> some View {
        HStack(spacing: WDSpacing.xs + 2) {
            ForEach(rivals) { rival in
                Circle()
                    .fill(rival.id == active ? Color.wdAccent : Color.wdInkSecondary.opacity(0.25))
                    .frame(width: 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: active)
        .accessibilityHidden(true)
    }

    /// Kafa kafaya rekabet kartı: ben vs tek bir rakip, o rakiple galibiyetler.
    /// `fixedContentHeight` verilirse iç içerik o yüksekliğe sabitlenir (slider'da
    /// tüm sayfaların eşit görünmesi için).
    private func rivalryCard(_ rival: MatchStats.RivalRecord, fixedContentHeight: CGFloat? = nil) -> some View {
        let opponent = rival.opponent

        return VStack(spacing: WDSpacing.md) {
            Text("Ezeli Rekabet")
                .font(.wdLabel)
                .foregroundStyle(Color.wdInkSecondary)
                .textCase(.uppercase)

            HStack(alignment: .top) {
                rivalryColumn(
                    name: me?.displayName ?? "Sen",
                    colorIndex: me?.avatarColor ?? 0,
                    wins: rival.wins,
                    isLeading: rival.wins > rival.losses
                )
                .frame(maxWidth: .infinity)

                Text("VS")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.wdInkSecondary)
                    .padding(.top, WDSpacing.md)
                    .accessibilityHidden(true)

                rivalryColumn(
                    name: opponent.displayName,
                    colorIndex: opponent.avatarColor,
                    wins: rival.losses,
                    isLeading: rival.losses > rival.wins
                )
                .frame(maxWidth: .infinity)
            }

            if rival.draws > 0 {
                Text("\(rival.draws) beraberlik")
                    .font(.wdCaption)
                    .foregroundStyle(Color.wdInkSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: fixedContentHeight)
        .wdCard(padding: WDSpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Rekabet: \(me?.displayName ?? "Sen") \(rival.wins) galibiyet, \(opponent.displayName) \(rival.losses) galibiyet, \(rival.draws) beraberlik"
        )
    }

    private func rivalryColumn(name: String, colorIndex: Int, wins: Int, isLeading: Bool) -> some View {
        VStack(spacing: WDSpacing.sm) {
            AvatarView(name: name, colorIndex: colorIndex, size: 64, isHighlighted: isLeading)
            Text(name)
                .font(.wdHeadline)
                .foregroundStyle(Color.wdInk)
                .lineLimit(1)
            Text("\(wins)")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(isLeading ? Color.wdAccent : Color.wdInk)
                .contentTransition(.numericText())
        }
    }

    /// Henüz rakip yokken gösterilen davet kartı.
    private var inviteTeaserCard: some View {
        VStack(alignment: .leading, spacing: WDSpacing.sm) {
            Image(systemName: "figure.fencing")
                .font(.system(size: 36))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
            Text("Rakibini davet et")
                .font(.wdTitle)
                .foregroundStyle(.white)
            Text("Yeni maç başlat, 6 haneli kodu arkadaşına gönder. Kim daha çok kelime biliyor, görelim.")
                .font(.wdSubheadline)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WDSpacing.lg)
        .background(
            LinearGradient.wdAccentGradient,
            in: RoundedRectangle(cornerRadius: WDRadius.lg, style: .continuous)
        )
        .shadow(color: Color.wdAccent.opacity(0.3), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var matchSections: some View {
        let active = matches.filter { $0.status == .active }
        let myTurn = active.filter { isMyTurn($0) }
        let waiting = active.filter { !isMyTurn($0) }
        let pending = matches.filter { $0.status == .pending }

        if !myTurn.isEmpty {
            section("Sıra sende") {
                ForEach(myTurn) { match in
                    matchCard(match, isMyTurn: true)
                }
            }
        }

        if !waiting.isEmpty {
            section("Rakip oynuyor") {
                ForEach(waiting) { match in
                    matchCard(match, isMyTurn: false)
                }
            }
        }

        if !pending.isEmpty {
            section("Davet bekleyenler") {
                ForEach(pending) { match in
                    pendingCard(match)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
        }

        if matches.isEmpty {
            VStack(spacing: WDSpacing.sm) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.wdInkSecondary)
                Text("Henüz maç yok")
                    .font(.wdHeadline)
                    .foregroundStyle(Color.wdInk)
                Text("Aşağıdan yeni maç başlat veya arkadaşının koduyla katıl.")
                    .font(.wdCaption)
                    .foregroundStyle(Color.wdInkSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, WDSpacing.xl)
        }
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: WDSpacing.sm) {
            Text(title)
                .font(.wdTitle)
                .foregroundStyle(Color.wdInk)
            rows()
        }
        .animation(.default, value: matches.count)
    }

    private func matchCard(_ match: Match, isMyTurn: Bool) -> some View {
        NavigationLink {
            MatchDetailView(match: match) {
                Task { await createNewMatch() }
            }
        } label: {
            matchCardLabel(match, isMyTurn: isMyTurn)
        }
        .buttonStyle(WDPressableButtonStyle())
    }

    private func matchCardLabel(_ match: Match, isMyTurn: Bool) -> some View {
        let stats = MatchStats(myAppleUserID: myAppleUserID())
        let opponent = stats.opponent(in: match)

        return HStack(spacing: WDSpacing.md) {
            AvatarView(
                name: opponent?.displayName ?? "?",
                colorIndex: opponent?.avatarColor ?? 1,
                size: 44
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(opponent?.displayName ?? "Rakip")
                    .font(.wdHeadline)
                    .foregroundStyle(Color.wdInk)
                Text("Tur \(match.currentRoundIndex + 1)/\(match.totalRounds)")
                    .font(.wdCaption)
                    .foregroundStyle(Color.wdInkSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(stats.myScore(in: match)) – \(stats.opponentScore(in: match))")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.wdInk)
                if isMyTurn {
                    Text("Sıra sende")
                        .font(.wdLabel)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.wdAccent, in: Capsule())
                }
            }
        }
        .wdCard()
        .overlay {
            if isMyTurn {
                RoundedRectangle(cornerRadius: WDRadius.lg, style: .continuous)
                    .strokeBorder(Color.wdAccent.opacity(0.5), lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel(for: match, isMyTurn: isMyTurn))
    }

    /// Rakibin katılmasını bekleyen maç — sola kaydırınca sil, dokununca kodu yeniden paylaşır.
    private func pendingCard(_ match: Match) -> some View {
        SwipeToDeleteCard(
            onTap: { reinvite = ReinviteCode(code: match.code) },
            onDelete: { deletePendingMatch(match) }
        ) {
            HStack(spacing: WDSpacing.md) {
                Image(systemName: "hourglass")
                    .font(.title3)
                    .foregroundStyle(Color.wdWarning)
                    .frame(width: 44, height: 44)
                    .background(Color.wdWarning.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Rakip bekleniyor")
                        .font(.wdHeadline)
                        .foregroundStyle(Color.wdInk)
                    Text("Kod: \(match.code) · Paylaşmak için dokun")
                        .font(.wdCaption)
                        .foregroundStyle(Color.wdInkSecondary)
                }

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Color.wdInkSecondary)
            }
            .wdCard()
        }
        .accessibilityLabel("Rakip bekleniyor, kod \(match.code.map(String.init).joined(separator: " ")), sola kaydırarak sil")
        .accessibilityAction(named: "Daveti Sil") { deletePendingMatch(match) }
    }

    /// Daveti hem yerelden hem public DB'den kaldırır — uzak kayıt silinmezse
    /// arkadaş eski kodla hayalet bir maça katılabiliyordu.
    private func deletePendingMatch(_ match: Match) {
        let code = match.code
        withAnimation(.spring(duration: 0.4)) {
            modelContext.delete(match)
            try? modelContext.save()
        }
        Task {
            try? await services.matchSyncService.inviteRepository.delete(code: code)
        }
    }

    private var actionBar: some View {
        HStack(spacing: WDSpacing.sm) {
            PrimaryButton(
                "Yeni Maç",
                systemImage: "plus",
                isLoading: isCreating
            ) {
                Task { await createNewMatch() }
            }
            SecondaryButton("Kodla Katıl", systemImage: "qrcode.viewfinder") {
                showJoinSheet = true
            }
        }
        .padding(.horizontal)
        .padding(.top, WDSpacing.sm)
        .padding(.bottom, WDSpacing.xs)
        .background(.ultraThinMaterial)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: WDSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.wdDanger)
            Text(message)
                .font(.wdCaption)
                .foregroundStyle(Color.wdInk)
            Spacer()
        }
        .padding(WDSpacing.md)
        .background(
            Color.wdDanger.opacity(0.1),
            in: RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
        )
    }

    // MARK: - Helpers

    private var me: Player? {
        guard let myID = myAppleUserID() else { return players.first }
        return players.first { $0.appleUserID == myID }
    }

    private var rival: Player? {
        guard let myID = myAppleUserID() else { return nil }
        return players.first { $0.appleUserID != myID }
    }

    private var greetingTitle: String {
        if let name = me?.displayName, !name.isEmpty {
            return "Selam, \(name) 👋"
        }
        return "Selam 👋"
    }

    private var greetingSubtitle: String {
        guard rival != nil else { return "Bugün düelloya hazır mısın?" }
        let record = MatchStats(myAppleUserID: myAppleUserID()).record(for: matches)
        if record.wins > record.losses { return "Liderliği bırakma, seri devam etsin!" }
        if record.wins < record.losses { return "Rövanş zamanı — farkı kapat!" }
        return "Skorlar eşit. İpleri kim koparacak?"
    }

    private var isCreating: Bool {
        if case .creating = viewModel?.createState { return true }
        return false
    }

    private var createdBinding: Binding<Bool> {
        Binding(
            get: {
                if case .created = viewModel?.createState { return true }
                return false
            },
            set: { newValue in
                if !newValue { viewModel?.dismissCreatedSheet() }
            }
        )
    }

    private func createNewMatch() async {
        guard let host = me else { return }
        await viewModel?.createMatch(host: host, modelContext: modelContext)
    }

    private func myAppleUserID() -> String? {
        if case .signedIn(let id) = authController.phase { return id }
        return nil
    }

    private func myRole(in match: Match) -> AskerRole? {
        MatchStats(myAppleUserID: myAppleUserID()).role(in: match)
    }

    private func currentRound(of match: Match) -> Round? {
        (match.rounds ?? []).first { $0.index == match.currentRoundIndex }
    }

    /// Faza göre aksiyon bende mi: kelime seçme, cevaplama veya değerlendirme.
    private func isMyTurn(_ match: Match) -> Bool {
        guard let me = myRole(in: match) else { return false }
        let flow = MatchFlow(match: match)
        switch flow.phase {
        case .picking(let asker):
            return asker == me
        case .answering:
            return flow.currentRound?.askerRole != me
        case .reviewing:
            return flow.currentRound?.askerRole == me
        case .waitingForOpponent, .finished:
            return false
        }
    }

    private func rowAccessibilityLabel(for match: Match, isMyTurn: Bool) -> String {
        let stats = MatchStats(myAppleUserID: myAppleUserID())
        let opponentName = stats.opponent(in: match)?.displayName ?? "Rakip"
        let turnNote = isMyTurn ? ", sıra sende" : ""
        return "Maç: \(opponentName) ile, tur \(match.currentRoundIndex + 1) / \(match.totalRounds), skor \(stats.myScore(in: match)) - \(stats.opponentScore(in: match))\(turnNote)"
    }

    /// Paylaşım ekranı açıkken rakip koda katıldıysa (maç `.pending` → `.active`):
    /// paylaşım sayfasını kapat ve ilgili maç ekranını otomatik aç.
    private func handleHostMatchActivation() {
        guard case .created(let code, _) = viewModel?.createState else { return }
        guard let match = matches.first(where: { $0.code == code }),
              match.status == .active else { return }
        viewModel?.dismissCreatedSheet()
        // Sheet kapanış animasyonu bitsin, sonra push et — aynı runloop'ta
        // present/dismiss çakışıp navigasyonun düşmesini önler.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            openedMatch = match
        }
    }

    /// Bitmemiş maçların uzak revizyonlarını indirir (misafir katılımı,
    /// rakibin hamleleri). Maç ekranı açıkken ayrıca kendi polling'i çalışır.
    private func pullRemoteUpdates() async {
        let repository = services.matchSyncService.stateRepository
        for match in matches where match.status != .finished {
            await MatchCloudSync.pull(match, repository: repository, context: modelContext)
        }
    }

    private func scheduleTurnNotifications() async {
        let stats = MatchStats(myAppleUserID: myAppleUserID())
        let active: [TurnNotifier.ActiveMatch] = matches.compactMap { match in
            guard match.status == .active else { return nil }
            guard myRole(in: match) != nil else { return nil }
            return TurnNotifier.ActiveMatch(
                code: match.code,
                isMyTurnToAnswer: isMyTurn(match),
                opponentDisplayName: stats.opponent(in: match)?.displayName ?? "Rakip"
            )
        }

        let toSchedule = TurnNotifier().notifications(for: active)
        for notification in toSchedule {
            await services.notificationScheduler.scheduleTurn(notification)
        }
        // Sıra başkasındaysa eski bildirimi temizle
        for match in active where !match.isMyTurnToAnswer {
            await services.notificationScheduler.cancel(matchCode: match.code)
        }
    }
}

// MARK: - Swipe to Delete

/// Sola kaydırma ile silme (iOS Mail tarzı). Hem açılan kırmızı butona
/// dokunma hem de tam kaydırma DOĞRUDAN `onDelete`'i çağırır; satırın
/// kaybolma animasyonunu üst kattaki ForEach transition'ı üstlenir.
private struct SwipeToDeleteCard<Content: View>: View {
    let onTap: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    init(
        onTap: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onTap = onTap
        self.onDelete = onDelete
        self.content = content
    }

    @State private var offset: CGFloat = 0
    /// Dinlenme konumu: 0 kapalı, -revealWidth açık.
    @State private var rest: CGFloat = 0
    /// Sürükleme yönü kilidi: dikey başlayan hareket ScrollView'a bırakılır.
    @State private var axis: Axis?
    @State private var armed = false

    private enum Axis { case horizontal, vertical }
    private let revealWidth: CGFloat = 96
    private let fullSwipe: CGFloat = 200

    var body: some View {
        ZStack(alignment: .trailing) {
            // Kırmızı arka plan içeriğin ALTINDA: içerik sola kayınca arkadan
            // ortaya çıkar (iOS Mail tarzı reveal). Üste alınırsa içeriğin
            // üzerine biniyormuş gibi görünüyordu.
            deleteBackground

            content()
                .offset(x: offset)
                .contentShape(Rectangle())
                .onTapGesture {
                    if rest != 0 { close() } else { onTap() }
                }
                .simultaneousGesture(dragGesture)

            // Açıkken sil bölgesi için saydam dokunuş yakalayıcı. İçeriğin
            // drag/tap jest alanı `.offset`'e rağmen tam genişlikte kaldığından
            // arka plana doğrudan dokunmak içeriğe takılıyordu; bu üst katman
            // dokunuşu görseli bozmadan garanti onDelete'e yönlendirir.
            if rest != 0 {
                Color.clear
                    .frame(width: revealWidth)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { onDelete() }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: armed) { _, a in a }
    }

    /// Açılan boşluğu dolduran kırmızı arka plan (yalnızca görsel). Dokunuş,
    /// üstteki saydam yakalayıcı veya tam kaydırma ile yönetilir.
    private var deleteBackground: some View {
        let exposed = max(0, -offset)
        let nearFull = exposed >= fullSwipe * 0.85

        return ZStack {
            RoundedRectangle(cornerRadius: WDRadius.lg, style: .continuous)
                .fill(Color.wdDanger)
            Image(systemName: "trash.fill")
                .font(.system(size: 18, weight: .semibold))
                .scaleEffect(nearFull ? 1.25 : 1)
                .animation(.spring(duration: 0.2), value: nearFull)
                .foregroundStyle(.white)
        }
        .frame(width: max(revealWidth, exposed))
        .frame(maxHeight: .infinity)
        .opacity(exposed > 1 ? 1 : 0)
        .accessibilityHidden(true)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                if axis == nil {
                    axis = abs(value.translation.width) > abs(value.translation.height)
                        ? .horizontal : .vertical
                }
                guard axis == .horizontal else { return }

                var dx = rest + value.translation.width
                dx = min(0, dx)
                if dx < -fullSwipe {
                    // Tam kaydırma bölgesinin ötesinde hafif direnç
                    dx = -fullSwipe - (-dx - fullSwipe) * 0.35
                }
                offset = dx
                armed = -offset >= fullSwipe * 0.85
            }
            .onEnded { _ in
                let wasHorizontal = axis == .horizontal
                axis = nil
                guard wasHorizontal else { return }

                if armed {
                    armed = false
                    onDelete()
                } else if -offset > revealWidth / 2 {
                    open()
                } else {
                    close()
                }
            }
    }

    private func open() {
        rest = -revealWidth
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            offset = -revealWidth
        }
    }

    private func close() {
        rest = 0
        armed = false
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            offset = 0
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Match.self, Player.self, Round.self], inMemory: true)
        .environment(AuthController())
}
