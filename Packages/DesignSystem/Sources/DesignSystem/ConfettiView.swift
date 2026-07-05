import SwiftUI

/// Kutlama anları için saf SwiftUI konfeti yağmuru.
/// `TimelineView` + `Canvas` ile çizilir; UIKit emitter bağımlılığı yoktur.
/// Parçacıklar sabit tohumlu rastgelelikle üretilir ki ebeveyn görünüm yeniden
/// oluşturulduğunda desen değişip titremesin.
public struct ConfettiView: View {
    private struct Piece {
        var xRatio: Double      // 0...1 yatay başlangıç konumu
        var delay: Double       // saniye cinsinden gecikmeli salınım
        var speed: Double       // ekran yüksekliği oranı / sn
        var drift: Double       // yatay salınım genliği (pt)
        var spin: Double        // dönüş hızı (radyan / sn)
        var phase: Double
        var width: Double
        var height: Double
        var colorIndex: Int
    }

    /// Tekrarlanabilir parçacık üretimi için basit LCG.
    private struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }
    }

    private let pieces: [Piece]
    private let colors: [Color]
    private let totalLifetime: Double
    @State private var startDate = Date.now
    @State private var isFinished = false

    /// - Parameters:
    ///   - pieceCount: Toplam konfeti parçası sayısı.
    ///   - emitDuration: Yeni parçacıkların bırakıldığı süre (sn).
    ///   - colors: Parçacık renk paleti.
    public init(
        pieceCount: Int = 140,
        emitDuration: Double = 2.0,
        colors: [Color] = AvatarPalette.colors
    ) {
        self.colors = colors
        // En geç bırakılan ve en yavaş düşen parçacığın ekranı terk etme süresi.
        self.totalLifetime = emitDuration + (1.0 / 0.35) + 0.5

        var rng = SeededGenerator(seed: 0xC0FF_E77E)
        self.pieces = (0..<max(1, pieceCount)).map { i in
            Piece(
                xRatio: .random(in: 0...1, using: &rng),
                delay: .random(in: 0...emitDuration, using: &rng),
                speed: .random(in: 0.35...0.75, using: &rng),
                drift: .random(in: 8...36, using: &rng),
                spin: .random(in: 2...7, using: &rng),
                phase: .random(in: 0...(2 * .pi), using: &rng),
                width: .random(in: 6...11, using: &rng),
                height: .random(in: 8...15, using: &rng),
                colorIndex: i % colors.count
            )
        }
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: isFinished)) { context in
            Canvas { canvas, size in
                let elapsed = context.date.timeIntervalSince(startDate)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t >= 0 else { continue }
                    let y = t * piece.speed * size.height - 20
                    guard y < size.height + 20 else { continue }

                    let x = piece.xRatio * size.width + sin(t * 2.2 + piece.phase) * piece.drift
                    let flip = abs(sin(t * piece.spin + piece.phase)) // 3B dönüş hissi
                    let fade = max(0, min(1, (size.height + 20 - y) / (size.height * 0.25)))

                    var ctx = canvas
                    ctx.opacity = fade
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .radians(t * piece.spin * 0.6 + piece.phase))
                    let rect = CGRect(
                        x: -piece.width / 2,
                        y: -piece.height * flip / 2,
                        width: piece.width,
                        height: max(1.5, piece.height * flip)
                    )
                    ctx.fill(
                        Path(roundedRect: rect, cornerRadius: 1.5),
                        with: .color(colors[piece.colorIndex])
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: .seconds(totalLifetime))
            isFinished = true
        }
    }
}

#Preview {
    ZStack {
        Color.wdBackground.ignoresSafeArea()
        ConfettiView()
    }
}
