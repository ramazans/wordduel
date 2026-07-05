import SwiftUI
import SwiftData
import AuthenticationServices
import AuthService
import CloudKitService
import DesignSystem

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthController.self) private var authController
    @Environment(AppServices.self) private var services
    @State private var viewModel: SignInViewModel?
    @State private var page = 0

    private static let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                onboardingPage(
                    title: "WordDuel'e Hoş Geldin",
                    subtitle: "En yakın arkadaşınla İngilizce kelime düellosu. Öğrenmenin en tatlı hâli: rekabet.",
                    systemImage: "figure.fencing"
                )
                .tag(0)

                onboardingPage(
                    title: "Rakibini Davet Et",
                    subtitle: "6 haneli kodu arkadaşına gönder, düello saniyeler içinde başlasın.",
                    systemImage: "qrcode"
                )
                .tag(1)

                onboardingPage(
                    title: "30 Saniyede Cevapla",
                    subtitle: "Bilemediğin kelime tekrar karşına çıkar — bilene kadar puanı rakibin toplar.",
                    systemImage: "timer"
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.snappy, value: page)

            pageDots
                .padding(.bottom, WDSpacing.lg)

            footer
        }
        .background(onboardingBackground)
        .task {
            if viewModel == nil {
                viewModel = SignInViewModel(
                    authController: authController,
                    cloudKitAccount: CloudKitAccount(containerIdentifier: AppConstants.cloudKitContainerID)
                )
            }
            // Container kayıtlı değilse log spam'ini önlemek için kontrolü atla.
            if services.cloudKitEnabled {
                await viewModel?.refreshCloudKitAvailability()
            }
        }
    }

    private var onboardingBackground: some View {
        ZStack {
            LinearGradient.wdScreenGradient
            LinearGradient(
                colors: [Color.wdAccent.opacity(0.12), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
    }

    private var pageDots: some View {
        HStack(spacing: WDSpacing.sm) {
            ForEach(0..<Self.pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.wdAccent : Color.wdSeparator.opacity(0.6))
                    .frame(width: index == page ? 24 : 8, height: 8)
                    .animation(.snappy, value: page)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sayfa \(page + 1) / \(Self.pageCount)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: page = min(page + 1, Self.pageCount - 1)
            case .decrement: page = max(page - 1, 0)
            @unknown default: break
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        // Uyarı bilgilendirir ama girişi engellemez — availability kontrolü
        // best-effort, `.couldNotDetermine` durumunda hiç gösterilmez.
        if let vm = viewModel,
           !vm.iCloudAvailability.isAvailable,
           vm.iCloudAvailability != .couldNotDetermine {
            HStack(spacing: WDSpacing.sm) {
                Image(systemName: "exclamationmark.icloud.fill")
                    .foregroundStyle(Color.wdWarning)
                Text(vm.iCloudAvailability.userMessage)
                    .font(.wdCaption)
                    .foregroundStyle(Color.wdInk)
            }
            .padding(WDSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.wdWarning.opacity(0.12),
                in: RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
            )
            .padding(.horizontal)
            .padding(.bottom, WDSpacing.sm)
        }

        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName]
        } onCompletion: { result in
            viewModel?.handleAppleSignIn(result, modelContext: modelContext)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, WDSpacing.sm)

        #if DEBUG
        debugTestUserSection
        #endif

        if case .signingIn = authController.phase {
            ProgressView()
                .padding(.bottom)
        }

        if case .error(let message) = authController.phase {
            Text(message)
                .font(.wdCaption)
                .foregroundStyle(Color.wdDanger)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, WDSpacing.sm)
        }
    }

    #if DEBUG
    /// Çoklu simülatör testinde Apple Sign In olmadan hızlı giriş.
    @ViewBuilder
    private var debugTestUserSection: some View {
        VStack(spacing: WDSpacing.sm) {
            Text("DEBUG — Test Kullanıcısı")
                .font(.caption2)
                .foregroundStyle(Color.wdInkSecondary)
            HStack(spacing: WDSpacing.sm) {
                ForEach(["Alice", "Bob", "Cem"], id: \.self) { name in
                    Button(name) {
                        authController.signInAsTestUser(
                            userID: name.lowercased(),
                            displayName: name,
                            modelContext: modelContext
                        )
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.bottom, WDSpacing.sm)
    }
    #endif

    @ViewBuilder
    private func onboardingPage(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(spacing: WDSpacing.lg) {
            Image(systemName: systemImage)
                .font(.system(size: 64))
                .foregroundStyle(Color.wdAccent)
                .frame(width: 140, height: 140)
                .background(Color.wdAccent.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            Text(title)
                .font(.wdLargeTitle)
                .foregroundStyle(Color.wdInk)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.wdBody)
                .foregroundStyle(Color.wdInkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, WDSpacing.xl)
        }
        .padding()
    }
}

#Preview {
    OnboardingView()
        .environment(AuthController())
}
