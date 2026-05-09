import SwiftUI
import AuthenticationServices
import DesignSystem

struct OnboardingView: View {
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

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { _ in
                // TODO Faz 2: AuthService köprüsü.
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding()
        }
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
}
