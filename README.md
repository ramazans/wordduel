# WordDuel

İki kişi arasında gerçek zamanlı, online bir İngilizce kelime ezberleme yarışması — native iOS uygulaması.

## Oyun Mekaniği

- Oyuncu A, oyuncu B'ye bir İngilizce kelime sorar (havuzdan veya manuel).
- B bilirse puan yok; bilemezse A puan kazanır.
- Bilinmeyen kelime sabit tur aralığıyla (varsayılan **3 tur** sonra) tekrar B'ye sorulur.
- Tekrar bilemezse puan üssel artar: **2 → 4 → 8**.
- Tekrar bilirse kelime kuyruktan düşer, puan yok.
- Maç **10 sabit tur**, cevap için **30 sn** süre.

## Teknoloji

| Katman | Tercih |
|---|---|
| iOS minimum | iOS 18 |
| UI | SwiftUI (saf) |
| Concurrency | Swift Concurrency (`async/await`, `actor`) |
| State | `@Observable` (Observation framework) |
| Persistence | SwiftData + CloudKit |
| Sync | CloudKit private DB + `CKShare` |
| Auth | Sign in with Apple |
| Test | XCTest + XCUITest |

## Yapı

```
wordduel/
├─ App/                     # @main, AppRoot, Info.plist, Resources
├─ Packages/                # 7 yerel SPM paketi
│  ├─ DesignSystem/
│  ├─ CoreModels/
│  ├─ CloudKitService/
│  ├─ AuthService/
│  ├─ MatchEngine/          # saf Swift, test edilebilir
│  ├─ WordRepository/
│  └─ L10n/
├─ Features/                # SwiftUI ekranları (Onboarding, Home, Match, ...)
└─ Tests/                   # XCTest + XCUITest
```

## Geliştirme

Xcode 16+ ve iOS 18 SDK gerekir. Repo'yu klonladıktan sonra Mac'te `wordduel.xcodeproj` açılır (proje dosyası ilk kurulumda manuel olarak veya XcodeGen ile üretilir).

### MatchEngine'i CLI'da test etmek

`MatchEngine` paketi saf Swift'tir, Linux/macOS CLI'da test edilebilir:

```bash
cd Packages/MatchEngine
swift test
```

## CloudKit Schema (Manual Setup on Mac)

Faz 4 için CloudKit Dashboard → Development environment'ta şu record type'ları schema olarak deploy edilmeli (SwiftData @Model'lar otomatik üretir, ama public DB'deki `MatchInvite` manuel):

### Public DB — `MatchInvite`

| Field | Type | Indexed | Notes |
|---|---|---|---|
| `code` | String | Queryable + Searchable | 6-char, unique within fresh window |
| `shareURL` | String | — | iCloud share URL |
| `hostUserRecordName` | String | — | CKCurrentUser record name |
| `createdAt` | Date/Time | Sortable | |
| `expiresAt` | Date/Time | — | TTL — 7 gün varsayılan |

> **Önemli**: `MatchInvite` kodları opaque shareURL'i lookup edilebilir hale getirir.
> Kayıt içeriği yalnızca paylaşım meta verisidir; oyun verisi (kelime, skor) burada yok.

### Private DB — SwiftData @Model'lar

`Player`, `Match`, `Round`, `WordEntry`, `ScoreEvent` SwiftData tarafından otomatik
oluşturulur. Schema deployment için bir kez uygulamayı simulator'de çalıştırıp Match
yarat, sonra Dashboard'dan production'a deploy et.

### Capabilities (Xcode)

- Sign in with Apple
- iCloud → CloudKit container `iCloud.com.<team>.wordduel`
- Push Notifications
- Background Modes → Remote notifications

## Plan

Detaylı geliştirme planı için bkz. proje belgeleri (6 fazlı, ~4-6 hafta tek geliştirici tahmini).

## Lisans

TBD.
