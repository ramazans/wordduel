import SwiftUI
import CoreModels
import MatchEngine
import WordRepository
import DesignSystem

struct AskingView: View {
    var roundNumber: Int = 1
    var totalRounds: Int = 10
    var dueRepeats: [PendingRepeatItem] = []
    var onAsk: (AskRequest) -> Void = { _ in }
    var onAskRepeat: (_ item: PendingRepeatItem, _ format: AnswerFormat, _ options: [String]) -> Void = { _, _, _ in }

    @State private var mode: AskMode = .list
    @State private var format: AnswerFormat = .text
    @State private var selectedKind: SeedKind = .word
    @State private var searchText: String = ""
    @State private var selectedLevel: String?
    @State private var words: [SeedWord] = []
    @State private var loadFailed = false
    @State private var pendingWord: SeedWord?
    @State private var pendingRepeat: PendingRepeatItem?
    @State private var customWord: String = ""
    @State private var customAnswer: String = ""

    enum AskMode: String, CaseIterable, Identifiable {
        case list, custom
        var id: Self { self }
        var label: String {
            switch self {
            case .list: return "Listeden seç"
            case .custom: return "Kendin yaz"
            }
        }
    }

    var body: some View {
        VStack(spacing: WDSpacing.md) {
            if !dueRepeats.isEmpty {
                repeatsSection
            }

            Picker("Mod", selection: $mode) {
                ForEach(AskMode.allCases) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            formatPicker

            switch mode {
            case .list:
                listMode
            case .custom:
                customMode
            }
        }
        .wdScreenBackground()
        .navigationTitle("Tur \(roundNumber) / \(totalRounds)")
        .navigationBarTitleDisplayMode(.inline)
        .task { loadWords() }
        .confirmationDialog(
            pendingWord.map { "\"\($0.text)\" sorulsun mu?" } ?? "",
            isPresented: askConfirmBinding,
            titleVisibility: .visible
        ) {
            Button("Bunu sor") {
                if let word = pendingWord {
                    onAsk(makeRequest(for: word))
                }
                pendingWord = nil
            }
            Button("Vazgeç", role: .cancel) { pendingWord = nil }
        } message: {
            if let word = pendingWord {
                Text("Beklenen cevap: \(word.definition) • Format: \(formatLabel)")
            }
        }
    }

    /// Cevap formatı seçici: rakip yazarak mı cevaplasın, şıklardan mı seçsin?
    private var formatPicker: some View {
        Picker("Cevap formatı", selection: $format) {
            Text("Yazarak").tag(AnswerFormat.text)
            Text("Test (4 seçenek)").tag(AnswerFormat.multipleChoice)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private var formatLabel: String {
        format == .multipleChoice ? "Test (4 seçenek)" : "Yazarak"
    }

    // MARK: - Tekrar kuyruğu

    /// Vakti gelmiş tekrarlar: rakibin bilemediği kelimeler artık daha çok
    /// puan değerinde — oyunun ana mekaniği olduğu için en üstte ve vurgulu.
    private var repeatsSection: some View {
        VStack(alignment: .leading, spacing: WDSpacing.sm) {
            Label("Tekrar zamanı", systemImage: "arrow.clockwise")
                .font(.wdLabel)
                .foregroundStyle(Color.wdWarning)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: WDSpacing.sm) {
                    ForEach(dueRepeats, id: \.self) { item in
                        repeatCard(item)
                    }
                }
                .padding(.horizontal)
            }
        }
        .confirmationDialog(
            pendingRepeat.map { "\"\($0.word)\" tekrar sorulsun mu?" } ?? "",
            isPresented: repeatConfirmBinding,
            titleVisibility: .visible
        ) {
            Button("Tekrar sor") {
                if let item = pendingRepeat {
                    let (effectiveFormat, options) = repeatFormatAndOptions(for: item)
                    onAskRepeat(item, effectiveFormat, options)
                }
                pendingRepeat = nil
            }
            Button("Vazgeç", role: .cancel) { pendingRepeat = nil }
        } message: {
            if let item = pendingRepeat {
                Text("Yine bilemezse +\(Scoring.points(forWeight: item.weight)) puan kazanırsın. • Format: \(formatLabel)")
            }
        }
    }

    private func repeatCard(_ item: PendingRepeatItem) -> some View {
        Button {
            pendingRepeat = item
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.word)
                    .font(.wdHeadline)
                    .foregroundStyle(Color.wdInk)
                    .lineLimit(1)
                Text("+\(Scoring.points(forWeight: item.weight)) puan değerinde")
                    .font(.wdLabel)
                    .foregroundStyle(Color.wdWarning)
            }
            .padding(12)
            .background(
                Color.wdWarning.opacity(0.1),
                in: RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
                    .strokeBorder(Color.wdWarning.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(WDPressableButtonStyle())
        .accessibilityLabel(
            "Tekrar: \(item.word), bilemezse \(Scoring.points(forWeight: item.weight)) puan. Sormak için dokun."
        )
    }

    private var repeatConfirmBinding: Binding<Bool> {
        Binding(
            get: { pendingRepeat != nil },
            set: { if !$0 { pendingRepeat = nil } }
        )
    }

    // MARK: - Liste modu

    private var listMode: some View {
        VStack(spacing: WDSpacing.sm) {
            kindPicker
            searchField
            levelChips

            if loadFailed {
                ContentUnavailableView(
                    "Kelimeler yüklenemedi",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Kelime havuzuna ulaşılamadı. \"Kendin yaz\" modunu kullanabilirsin.")
                )
            } else if filteredWords.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ScrollView {
                    LazyVStack(spacing: WDSpacing.sm) {
                        ForEach(filteredWords, id: \.text) { word in
                            wordRow(word)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, WDSpacing.md)
                }
            }
        }
    }

    /// İçerik türü sekmeleri: Kelime / Deyim / Phrasal Verb.
    private var kindPicker: some View {
        Picker("İçerik türü", selection: $selectedKind) {
            Text("Kelime").tag(SeedKind.word)
            Text("Deyim").tag(SeedKind.idiom)
            Text("Phrasal Verb").tag(SeedKind.phrasal)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .onChange(of: selectedKind) {
            // Seçili seviye yeni türde yoksa filtreyi sıfırla.
            if let level = selectedLevel, !availableLevels.contains(level) {
                selectedLevel = nil
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: WDSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.wdInkSecondary)
            TextField("Kelime ara…", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(12)
        .background(
            Color.wdSurfaceSecondary,
            in: RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
        )
        .padding(.horizontal)
    }

    private var levelChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WDSpacing.sm) {
                levelChip(title: "Tümü", level: nil)
                ForEach(availableLevels, id: \.self) { level in
                    levelChip(title: level.uppercased(), level: level)
                }
            }
            .padding(.horizontal)
        }
    }

    private func levelChip(title: String, level: String?) -> some View {
        let isSelected = selectedLevel == level
        return Button {
            withAnimation(.snappy) { selectedLevel = level }
        } label: {
            Text(title)
                .font(.wdLabel)
                .foregroundStyle(isSelected ? .white : Color.wdInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.wdInk : Color.wdSurfaceSecondary,
                    in: Capsule()
                )
        }
        .buttonStyle(WDPressableButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func wordRow(_ word: SeedWord) -> some View {
        Button {
            pendingWord = word
        } label: {
            HStack(spacing: WDSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(word.text)
                        .font(.wdHeadline)
                        .foregroundStyle(Color.wdInk)
                    Text(word.definition)
                        .font(.wdCaption)
                        .foregroundStyle(Color.wdInkSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(word.level.uppercased())
                    .font(.wdLabel)
                    .foregroundStyle(levelColor(word.level))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(levelColor(word.level).opacity(0.12), in: Capsule())
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.wdSurfaceSecondary,
                in: RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
            )
        }
        .buttonStyle(WDPressableButtonStyle())
        .accessibilityLabel("\(word.text), \(word.definition), seviye \(word.level.uppercased())")
        .accessibilityHint("Bu kelimeyi sormak için dokun")
    }

    // MARK: - Kendin yaz modu

    private var customMode: some View {
        VStack(spacing: WDSpacing.md) {
            customField("Kelime (İngilizce)", text: $customWord)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            customField("Beklenen Türkçe karşılık", text: $customAnswer)

            Label("İpucu: Geçen hafta öğrendiğiniz kelimeleri sorarak rakibini test et.", systemImage: "lightbulb")
                .font(.wdCaption)
                .foregroundStyle(Color.wdInkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            PrimaryButton("Sor", systemImage: "paperplane.fill") {
                onAsk(makeCustomRequest())
            }
            .disabled(
                customWord.trimmingCharacters(in: .whitespaces).isEmpty ||
                customAnswer.trimmingCharacters(in: .whitespaces).isEmpty
            )

            Spacer()
        }
        .padding(.horizontal)
    }

    private func customField(_ placeholder: LocalizedStringKey, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.wdBody)
            .padding(14)
            .background(
                Color.wdSurfaceSecondary,
                in: RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
            )
    }

    // MARK: - Veri

    private func loadWords() {
        guard words.isEmpty else { return }
        do {
            words = try SeedLoader.load().sorted { $0.text < $1.text }
        } catch {
            loadFailed = true
        }
    }

    private var availableLevels: [String] {
        Array(Set(words.filter { $0.kind == selectedKind }.map(\.level))).sorted()
    }

    private var filteredWords: [SeedWord] {
        words.filter { word in
            let kindMatches = word.kind == selectedKind
            let levelMatches = selectedLevel == nil || word.level == selectedLevel
            let searchMatches = searchText.isEmpty
                || word.text.localizedCaseInsensitiveContains(searchText)
                || word.definition.localizedCaseInsensitiveContains(searchText)
            return kindMatches && levelMatches && searchMatches
        }
    }

    // MARK: - Soru kurma

    /// Listeden seçilen giriş için soru: Test formatında şıklar burada, soran
    /// cihazda bir kez üretilir (Round'a yazılıp senkronla taşınır).
    private func makeRequest(for word: SeedWord) -> AskRequest {
        let (effectiveFormat, options) = formatAndOptions(
            correct: word.definition,
            kind: word.kind,
            level: word.level
        )
        return AskRequest(
            word: word.text,
            expectedAnswer: word.definition,
            kind: ContentKind(rawValue: word.kind.rawValue) ?? .word,
            format: effectiveFormat,
            options: options
        )
    }

    /// Kendin-yaz sorusu hep kelime türünde; Test seçiliyse çeldiriciler
    /// kelime havuzundan gelir, havuz yoksa sessizce yazma formatına düşer.
    private func makeCustomRequest() -> AskRequest {
        let answer = customAnswer.trimmingCharacters(in: .whitespaces)
        let (effectiveFormat, options) = formatAndOptions(
            correct: answer,
            kind: .word,
            level: nil
        )
        return AskRequest(
            word: customWord.trimmingCharacters(in: .whitespaces),
            expectedAnswer: answer,
            kind: .word,
            format: effectiveFormat,
            options: options
        )
    }

    private func repeatFormatAndOptions(for item: PendingRepeatItem) -> (AnswerFormat, [String]) {
        formatAndOptions(
            correct: item.expectedAnswer,
            kind: SeedKind(rawValue: item.kind.rawValue) ?? .word,
            level: nil
        )
    }

    /// Test formatı ancak 4 şık üretilebiliyorsa kullanılır; havuz yetersizse
    /// (ör. seed yüklenemedi) yazma formatına düşer.
    private func formatAndOptions(correct: String, kind: SeedKind, level: String?) -> (AnswerFormat, [String]) {
        guard format == .multipleChoice else { return (.text, []) }
        let options = OptionsBuilder.multipleChoiceOptions(
            correct: correct,
            kind: kind,
            level: level,
            pool: words
        )
        guard options.count >= 4 else { return (.text, []) }
        return (.multipleChoice, options)
    }

    private func levelColor(_ level: String) -> Color {
        switch level.prefix(1) {
        case "a": return .wdSuccess
        case "b": return .blue
        case "c": return .purple
        default: return .wdInkSecondary
        }
    }

    private var askConfirmBinding: Binding<Bool> {
        Binding(
            get: { pendingWord != nil },
            set: { if !$0 { pendingWord = nil } }
        )
    }
}

#Preview {
    NavigationStack {
        AskingView(
            roundNumber: 4,
            totalRounds: 10,
            dueRepeats: [
                PendingRepeatItem(word: "ephemeral", expectedAnswer: "geçici", dueAtRoundIndex: 3, weight: 2),
                PendingRepeatItem(word: "diligent", expectedAnswer: "çalışkan", dueAtRoundIndex: 3, weight: 3)
            ]
        )
    }
}
