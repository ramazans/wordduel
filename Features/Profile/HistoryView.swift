import SwiftUI
import SwiftData
import CoreModels

struct HistoryView: View {
    @Query(filter: #Predicate<Match> { $0.statusRaw == "finished" },
           sort: \Match.finishedAt, order: .reverse)
    private var finishedMatches: [Match]

    var body: some View {
        Group {
            if finishedMatches.isEmpty {
                ContentUnavailableView(
                    "Geçmiş yok",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Henüz tamamlanmış maç yok.")
                )
            } else {
                List(finishedMatches) { match in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(match.code)
                                .font(.system(.body, design: .monospaced))
                            if let date = match.finishedAt {
                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("\(match.hostScore) — \(match.guestScore)")
                            .monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle("Geçmiş")
    }
}

#Preview {
    NavigationStack { HistoryView() }
        .modelContainer(for: [Match.self], inMemory: true)
}
