import SwiftUI
import SwiftData
import AuthenticationServices
import AuthService
import CloudKitService
import DesignSystem

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthController.self) private var authController
    @State private var viewModel: SignInViewModel?
    @State private var page = 0

    var body: some View {
        VStack {
            TabView(selection: $page) {
                onboardingPage(
                    title: "WordDuel'e Hoş Geldin",
                    subtitle: "Arkadaşınla İngilizce kelime düellosu.",
                    systemImage: "text.book.closed.fill"
                )
                .tag(0)

                onboardingPage(
                    title: "Davet Kodu Paylaş",
                    subtitle: "6 haneli kod ile arkadaşını çağır.",
                    systemImage: "qrcode"
                )
                .tag(1)

                onboardingPage(
                    title: "Sıra Sende",
                    subtitle: "30 saniye içinde cevapla, puanı kaptır.",
                    systemImage: "timer"
                )
                .tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            footer
        }
        .task {
            if viewModel == nil {
                viewModel = SignInViewModel(
                    authController: authController,
                    cloudKitAccount: CloudKitAccount(containerIdentifier: AppConstants.cloudKitContainerID)
                )
            }
            await viewModel?.refreshCloudKitAvailability()
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let vm = viewModel,
           !vm.iCloudAvailability.isAvailable,
           vm.iCloudAvailability != .couldNotDetermine {
            iCloudWarning(vm.iCloudAvailability)
        }

        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName]
        } onCompletion: { result in
            viewModel?.handleAppleSignIn(result, modelContext: modelContext)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .padding()

        if case .signingIn = authController.phase {
            ProgressView()
                .padding(.bottom)
        }

        if case .error(let message) = authController.phase {
            Text(message)
                .font(.wdCaption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func iCloudWarning(_ availability: CloudKitAccount.Availability) -> some View {
        VStack(spacing: 6) {
            Label("iCloud kullanılamıyor", systemImage: "exclamationmark.icloud")
                .font(.wdCaption)
                .foregroundStyle(.orange)
            Text(availability.userMessage)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func onboardingPage(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: systemImage)
                .font(.system(size: 80))
                .foregroundStyle(.tint)
            Text(title)
                .font(.wdLargeTitle)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.wdBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}

#Preview {
    OnboardingView()
        .environment(AuthController())
}
