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

## Maç Akışı (Mimari)

Maç durumu SwiftData'da yaşar; cihazlar arası taşıma CloudKit **public DB**'deki append-only revizyon zinciriyle yapılır. Ayrı bir "oyun sunucusu" yoktur.

- **`MatchEngine`** (paket): kuralların saf, test edilebilir referansı.
- **`Features/Match/MatchFlow.swift`**: aynı kuralları kalıcı `Match`/`Round` modeline uygulayan akış katmanı — tur oluşturma, `AnswerNormalizer` ile otomatik karar, 2→4→8 puanlama, tekrar kuyruğu (`Match.pendingRepeats`), maç bitişi.
- **`MatchDetailView`**: faza göre ekran seçer — kelime seçme (`AskingView`, tekrar kuyruğu bölümüyle), cevaplama (`AnsweringView`, 30 sn halka sayaç), manuel değerlendirme (`ReviewAnswerView`), bekleme durumları ve skor tablosu (`ScoreboardView`).
- Tur sırası: çift indeksli turları **host**, tekleri **guest** sorar.
- Cevaplayanın cihazı kapalıysa: süre + 10 sn pay dolduktan sonra asker turu tek taraflı kapatabilir.

### Senkronizasyon (`MatchCloudSync` + `MatchStateRepository`)

CKShare/paylaşılan zone **kullanılmaz** — SwiftData'nın CloudKit aynası paylaşılan zone'ları desteklemediği için o yol çıkmazdır. Bunun yerine:

1. Her mutasyon (kelime sorma, cevap, değerlendirme, katılım) maçın **tam durumunu** (`MatchStateSnapshot`, JSON) public DB'ye `state-<kod>-<revizyon>` adlı **yeni** bir `MatchState` kaydı olarak yazar (append-only; mevcut kayıt asla güncellenmez — public DB'nin "yalnızca oluşturan günceller" kuralına takılmaz).
2. Karşı cihaz `revizyon+1` kaydını adıyla fetch eder (sorgu/indeks gerekmez), varsa uygular; maç ekranı açıkken 3 sn'de bir, Home'da açılış/yenilemede yoklanır.
3. Disiplin: her cihaz yalnızca **kendi aksiyonunu** push'lar; turn-based akışta yazma çakışması pratikte oluşmaz, oluşursa aynı revizyon adı ikinci yazana hata döndürür ve pull ile uzlaşılır.
4. Katılım: kod doğrulanınca misafir zinciri indirir (`materialize`), koltuğu kapar, `active` durumu push'lar; host'un yoklaması maçı başlatır.

`AppConstants.cloudKitEnabled` yalnızca SwiftData'nın private-DB aynasını kontrol eder; maç senkronu bu bayraktan bağımsız çalışır.

## Tasarım Sistemi

Arayüz, Airbnb iOS uygulamasındaki gibi "native ama custom" hissi hedefler. Tüm görsel dil `Packages/DesignSystem` altında token'lara dayanır:

- **Renk** — sıcak mercan marka rengi (`wdAccent`, açık/karanlık moda duyarlı), yüzeyler (`wdSurface`, `wdSurfaceSecondary`), metin (`wdInk`, `wdInkSecondary`), anlamsal renkler ve CTA gradient'i (`LinearGradient.wdAccentGradient`).
- **Tipografi** — başlıklarda yuvarlatılmış (rounded) sistem fontu: `wdDisplay`, `wdTitle`, `wdLabel`, `wdScore`…
- **Boşluk & köşe** — `WDSpacing` (4'lü ritim) ve `WDRadius` (her zaman `.continuous`).
- **Bileşenler** — `PrimaryButton`/`SecondaryButton` (basınca küçülen, gradient dolgulu), `AvatarView` (kazanan halkalı), `WordCard`, `TimerRing` (dairesel geri sayım), `CodeDigitsView`/`CodeInputField` (kutulu davet kodu), `.wdCard()` kart yüzeyi.

Ürün dili "iki yakın arkadaşın rekabeti" üzerine kurulu: ana ekranda kafa kafaya galibiyet sayan **Ezeli Rekabet** kartı, "Sıra sende" rozetleri, maç sonunda rövanşa çağıran skor ekranı.

## Geliştirme

Xcode 16+ ve iOS 18 SDK gerekir.

### Xcode projesini üretme (XcodeGen)

`.xcodeproj` repo'da yok — `project.yml`'den XcodeGen ile üretiliyor. İlk kurulumda:

```bash
# XcodeGen yüklü değilse:
brew install xcodegen

# Repo kökünde:
xcodegen generate

# Sonra:
open WordDuel.xcodeproj
```

`project.yml` değiştirildiğinde `xcodegen generate` ile yeniden üret. Üretilen `.xcodeproj` `.gitignore`'da, asla commit'lenmez.

### Xcode'da yapılması gerekenler (ilk açılışta)

1. Signing & Capabilities → **Team** seç (Apple Developer hesabın)
2. Capabilities şu an entitlements'tan geliyor — eksik bir şey görürsen Xcode "Fix" sunar:
   - Sign in with Apple
   - iCloud → CloudKit (container: `iCloud.club.kadro.wordduel`)
   - Push Notifications
   - Background Modes → Remote notifications
3. CloudKit Dashboard'da container yoksa oluştur (`iCloud.club.kadro.wordduel`)
4. App Icon ekle (`Assets.xcassets/AppIcon.appiconset/`) — 1024×1024 PNG

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

> **Önemli**: `MatchInvite` yalnızca kod → maç eşlemesidir; oyun verisi `MatchState`'te yaşar.

### Public DB — `MatchState`

| Field | Type | Indexed | Notes |
|---|---|---|---|
| `code` | String | — | 6 haneli maç kodu |
| `revision` | Int64 | — | Append-only revizyon numarası |
| `payload` | Bytes | — | `MatchStateSnapshot` JSON'u |
| `createdAt` | Date/Time | — | |

> Kayıt adı deterministiktir: `state-<kod>-<revizyon>`. Okuma her zaman kayıt
> adıyla fetch olduğu için **hiçbir alanda sorgu indeksi gerekmez** —
> Development ortamında ilk push şemayı otomatik oluşturur, production'a
> deploy etmek yeterlidir.

### Private DB — SwiftData @Model'lar

`Player`, `Match`, `Round`, `WordEntry`, `ScoreEvent` SwiftData tarafından otomatik
oluşturulur. Schema deployment için bir kez uygulamayı simulator'de çalıştırıp Match
yarat, sonra Dashboard'dan production'a deploy et.

### Capabilities (Xcode)

- Sign in with Apple
- iCloud → CloudKit container `iCloud.com.<team>.wordduel`
- Push Notifications
- Background Modes → Remote notifications

## App Store Deployment Checklist (Faz 6)

### Xcode Setup
- [ ] Bundle ID: `club.kadro.wordduel` (Constants.swift + xcconfig'te ayarlı)
- [ ] CloudKit Container: `iCloud.club.kadro.wordduel`
- [ ] Signing & Capabilities → Sign in with Apple
- [ ] Signing & Capabilities → iCloud → CloudKit checkbox + container seç
- [ ] Signing & Capabilities → Push Notifications
- [ ] Signing & Capabilities → Background Modes → Remote notifications
- [ ] App'e `App/PrivacyInfo.xcprivacy` ekle (target membership: app)

### App Store Connect
- [ ] App Store Connect → My Apps → New App: Bundle ID + SKU + name
- [ ] App Information → Category: Games → Word
- [ ] Pricing: Free
- [ ] App Privacy → "Data Collection" anketini doldur (Player ID, gameplay content — linked to identity, not for tracking)
- [ ] Age Rating: 4+
- [ ] App Review Information: contact, demo Apple ID gerekirse

### Assets
- [ ] App Icon 1024×1024 (Asset Catalog)
- [ ] Screenshots: iPhone 6.7" + iPhone 6.5" + iPad 13" (Light + Dark birer set)
- [ ] App preview video (opsiyonel ama önerilir)
- [ ] Marketing URL (opsiyonel)
- [ ] Support URL (zorunlu)
- [ ] Privacy Policy URL (Sign in with Apple zorunlu kılıyor)

### Localization (App Store)
- [ ] Türkçe açıklama, keywords (`kelime, ezberleme, ingilizce, oyun, yarışma`)
- [ ] English description + keywords (`vocabulary, english, learn, duel, game`)

### CloudKit Production
- [ ] CloudKit Dashboard → Schema'yı **Development → Production** deploy et
- [ ] `MatchInvite` record type'ı manuel oluştur (`code` field Queryable + Sortable)

### Beta
- [ ] Internal TestFlight: kendi cihazlarınla test
- [ ] External TestFlight: arkadaşlarla beta (Apple Review gerekir, 1-2 gün)

### Pre-submit
- [ ] Accessibility Inspector → her ekran VoiceOver ile gezilebilir
- [ ] Dynamic Type XXL'de UI taşması yok
- [ ] Light + Dark mode parity
- [ ] Lokalizasyon: TR ve EN dillerinde tüm akış denenmiş

### Submit
- [ ] Xcode → Archive → Validate → Upload
- [ ] App Store Connect → Submit for Review



Detaylı geliştirme planı için bkz. proje belgeleri (6 fazlı, ~4-6 hafta tek geliştirici tahmini).

## Lisans

TBD.
