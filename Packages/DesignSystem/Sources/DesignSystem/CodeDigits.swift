import SwiftUI

/// Davet kodunu karakter karakter kutularda gösterir (salt okunur).
public struct CodeDigitsView: View {
    private let code: String

    public init(_ code: String) {
        self.code = code
    }

    public var body: some View {
        HStack(spacing: WDSpacing.sm) {
            ForEach(Array(code.enumerated()), id: \.offset) { _, character in
                Text(String(character))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.wdAccent)
                    .frame(width: 44, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: WDRadius.sm, style: .continuous)
                            .fill(Color.wdSurface)
                            .shadow(color: .wdSurfaceEdge, radius: 0, x: 0, y: WDBevel.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: WDRadius.sm, style: .continuous)
                            .strokeBorder(Color.wdSeparator.opacity(0.6), lineWidth: 1)
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Davet kodu \(code.map(String.init).joined(separator: " "))")
    }
}

/// Kutulu davet kodu girişi. Görünmez bir `TextField` klavye girişini alır,
/// kutular yazılanı yansıtır; sıradaki kutu vurgulanır.
public struct CodeInputField: View {
    @Binding private var code: String
    private let length: Int
    @FocusState private var isFocused: Bool

    public init(code: Binding<String>, length: Int = 6) {
        self._code = code
        self.length = length
    }

    public var body: some View {
        ZStack {
            HStack(spacing: WDSpacing.sm) {
                ForEach(0..<length, id: \.self) { index in
                    box(at: index)
                }
            }

            TextField("", text: $code)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .accessibilityLabel("Davet kodu girişi")
                .accessibilityValue(code.map(String.init).joined(separator: " "))
        }
        .frame(height: 58)
        .onAppear { isFocused = true }
        .onChange(of: code) { _, newValue in
            if newValue.count > length {
                code = String(newValue.prefix(length))
            }
        }
    }

    @ViewBuilder
    private func box(at index: Int) -> some View {
        let characters = Array(code)
        let isActive = isFocused && index == min(code.count, length - 1) && code.count < length

        RoundedRectangle(cornerRadius: WDRadius.sm, style: .continuous)
            .fill(Color.wdSurface)
            .shadow(color: .wdSurfaceEdge, radius: 0, x: 0, y: WDBevel.card)
            .overlay(
                RoundedRectangle(cornerRadius: WDRadius.sm, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.wdAccent : Color.wdSeparator.opacity(0.6),
                        lineWidth: isActive ? 2.5 : 1
                    )
            )
            .overlay(
                Text(index < characters.count ? String(characters[index]) : "")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.wdInk)
            )
            .frame(width: 46, height: 58)
            .animation(.easeOut(duration: 0.15), value: isActive)
    }
}

#Preview {
    struct Demo: View {
        @State var code = "AB2"
        var body: some View {
            VStack(spacing: 32) {
                CodeDigitsView("AB23K9")
                CodeInputField(code: $code)
            }
            .padding()
        }
    }
    return Demo()
}
