import Foundation

public enum Scoring {
    /// 2 → 4 → 8 puan tablosu.
    /// `weight = 1` ilk soru, `weight = 2` 1. tekrar, `weight = 3` 2. tekrar.
    public static func points(forWeight weight: Int) -> Int {
        switch weight {
        case 1: return 2
        case 2: return 4
        case 3: return 8
        default:
            return weight <= 0 ? 0 : Int(pow(2.0, Double(weight)))
        }
    }

    /// İlk kez bilemediğinde kuyruğa eklenecek başlangıç ağırlığı.
    public static let initialWeight = 1

    /// Maksimum ağırlık (bu seviyede bilinmezse kuyruktan düşer).
    public static let maxWeight = 3
}
