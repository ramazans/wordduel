import SwiftUI
import DesignSystem

struct InviteView: View {
    let code: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Bu kodu arkadaşınla paylaş")
                    .font(.wdHeadline)
                    .foregroundStyle(.secondary)

                Text(code)
                    .font(.wdMonoCode)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = code
                    } label: {
                        Label("Kopyala", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    ShareLink(item: code) {
                        Label("Paylaş", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Arkadaş Davet Et")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    InviteView(code: "ABC123")
}
