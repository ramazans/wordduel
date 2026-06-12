import AVFoundation
import Foundation

/// Uygulama genelindeki kısa ses efektlerini çalar. Dosyalar
/// `scripts/make_sounds.py` ile sentezlenir ve bundle'a WAV olarak girer.
///
/// `.ambient` kategorisi sayesinde sessize alma anahtarına uyar ve arka planda
/// çalan müziği kesmez. Ayarlar'daki "Ses efektleri" anahtarı
/// (`soundEffectsEnabled`) kapalıysa hiç ses çalınmaz.
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    enum Effect: String, CaseIterable {
        /// Geri sayımın son saniyelerindeki tik.
        case tick
        /// Cevap süresi doldu.
        case timeUp = "timeup"
        /// Tur doğru cevapla kapandı.
        case correct
        /// Tur yanlış cevapla kapandı.
        case wrong
        /// Kelime soruldu / cevap gönderildi.
        case send
        /// Maç kazanıldı (konfeti eşliği).
        case victory
        /// Maç kaybedildi.
        case defeat
        /// Maç berabere bitti.
        case tie
    }

    private var players: [Effect: AVAudioPlayer] = [:]

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundEffectsEnabled") as? Bool ?? true
    }

    func play(_ effect: Effect) {
        guard isEnabled, let player = player(for: effect) else { return }
        player.currentTime = 0
        player.play()
    }

    /// İlk çalmadaki gecikmeyi önlemek için sesleri belleğe alır.
    func preload(_ effects: [Effect] = Effect.allCases) {
        for effect in effects {
            _ = player(for: effect)
        }
    }

    private func player(for effect: Effect) -> AVAudioPlayer? {
        if let cached = players[effect] { return cached }
        guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        players[effect] = player
        return player
    }
}
