import SwiftUI

/// Dairesel geri sayım halkası. `progress` kalan oranı (1 → 0) temsil eder.
public struct TimerRing: View {
    private let progress: Double
    private let remainingSeconds: Int
    private let isCritical: Bool
    private let size: CGFloat

    public init(
        progress: Double,
        remainingSeconds: Int,
        isCritical: Bool = false,
        size: CGFloat = 104
    ) {
        self.progress = progress
        self.remainingSeconds = remainingSeconds
        self.isCritical = isCritical
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.wdSurfaceSecondary, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    ringStyle,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
                .animation(.easeInOut(duration: 0.3), value: isCritical)

            VStack(spacing: 0) {
                Text("\(remainingSeconds)")
                    .font(.system(size: size * 0.32, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isCritical ? Color.wdDanger : Color.wdInk)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy(duration: 0.3), value: remainingSeconds)
                Text("saniye")
                    .font(.wdCaption)
                    .foregroundStyle(Color.wdInkSecondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kalan süre \(remainingSeconds) saniye")
    }

    private var lineWidth: CGFloat { size * 0.1 }

    /// Normalde bonbon pembesi gradyan, kritik eşikte kiraz kırmızısı.
    private var ringStyle: AnyShapeStyle {
        isCritical
            ? AnyShapeStyle(Color.wdDanger)
            : AnyShapeStyle(LinearGradient.wdAccentGradient)
    }
}

#Preview {
    HStack(spacing: 32) {
        TimerRing(progress: 0.8, remainingSeconds: 24)
        TimerRing(progress: 0.2, remainingSeconds: 6, isCritical: true)
    }
    .padding()
}
