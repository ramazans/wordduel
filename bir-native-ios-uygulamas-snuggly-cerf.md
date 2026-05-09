# WordDuel — Native iOS Uygulaması Planı

## Context

İki kişi arasında gerçek zamanlı, online bir **İngilizce kelime ezberleme yarışması** uygulaması inşa edilecek. Hedef: Apple HIG ile birebir uyumlu, native iOS deneyimi.

**Oyun mekaniği**:
- Oyuncu A, oyuncu B'ye bir İngilizce kelime sorar (havuzdan seçer veya kendi yazar).
- B bilirse puan yok; bilemezse A puan kazanır.
- Bilinmeyen kelime sabit tur aralığıyla (varsayılan 3 tur sonra) tekrar B'ye sorulur.
- Tekrar sorulduğunda da bilemezse, A daha çok puan kazanır (üssel: 2-4-8).
- Tekrar sorulduğunda bilirse, kelime kuyruktan düşer, puan yok.

**Neden bu plan**: Sıfırdan yeni bir Xcode projesi (`/Users/zeus/Developer/demo-app` şu anda boş). Apple ekosistemine sıkı bağlı, native hisli, MVP olarak 4-6 haftada tek geliştiriciyle yapılabilir bir mimari hedefleniyor.

---

## Onaylı Kararlar (Kullanıcı Seçimleri)

| Konu | Karar |
|---|---|
| Multiplayer | Online (gerçek zamanlı, uzaktan) |
| Backend | **CloudKit** (Apple ekosistemi, sunucu yok) |
| Auth | **Sign in with Apple** |
| Match flow | **Davet kodu** (6 hane) + 10 sabit tur |
| Kelime kaynağı | **Hibrit**: yerleşik kelime listesi + manuel giriş |
| Tekrar zamanlaması | Sabit tur aralığı (varsayılan **3 tur** sonra) |
| Cevap kontrolü | **Hibrit**: önce otomatik string eşleşme, eşleşmezse soran manuel onay |
| UI dili | **Türkçe + İngilizce** (Localization) |
| Puan formülü | **2 → 4 → 8** (üssel: ilk, 1. tekrar, 2. tekrar) |
| Tur süresi | **30 saniye** (cevap veren için) |
| Davet linki | Sadece **kod paylaşımı** (Universal Link ileride) |

---

## Teknoloji Yığını

| Katman | Tercih | Gerekçe |
|---|---|---|
| iOS minimum | **iOS 18** | `@Observable`, SwiftData v2, NavigationStack olgun. iOS 17'deki SwiftData/CloudKit bug'ları geride. |
| UI | **SwiftUI** (saf, UIKit fallback yok) | HIG bileşenleri yerel SwiftUI'da tam destekli. Dynamic Type/Dark Mode/A11y otomatik. |
| Concurrency | **Swift Concurrency** (`async/await`, `actor`, `@MainActor`) | CloudKit istemcisi async; oyun motoru `actor` ile thread-safe. |
| Navigation | **NavigationStack** + tip-güvenli `NavigationPath` | Coordinator pattern overkill; deep link/route enum yeterli. |
| State | **`@Observable`** (Observation framework) | iOS 17+ standardı; ObservableObject sorunlarını çözer. |
| Persistence | **SwiftData** (`ModelConfiguration(cloudKitDatabase: .private(...))`) | CloudKit sync yerleşik, schema migration kolay. |
| Sync | CloudKit `private` DB + `shared` DB; her maç için **`CKShare`** | Davet eden kendi private DB'sine yazar, davet edilen `CKShare` ile shared DB'de görür. |
| Push | **CloudKit silent push** + lokal `UNUserNotificationCenter` bildirimi | Ayrı APNs sunucusu gerekmez; "Sıra sende" bildirimi cihazda planlanır. |
| Test | XCTest (oyun motoru), XCUITest (kritik akışlar) | %90+ kapsama hedefi `MatchEngine` için. |

---

## Modül / Dosya Yapısı

Tek Xcode projesi, ince app target + yerel SPM paketleri.

```
demo-app/
├─ App/
│  ├─ WordDuelApp.swift            # @main, ModelContainer
│  ├─ AppRoot.swift                # auth durumuna göre root switch
│  ├─ Info.plist + Entitlements    # CloudKit, Sign in with Apple, Push
│  └─ Resources/
│     ├─ Assets.xcassets           # AppIcon, AccentColor, SF Symbols
│     ├─ Localizable.xcstrings     # tr + en (String Catalog)
│     └─ SeedWords.json            # Yerleşik kelime havuzu (CEFR)
│
├─ Packages/                       # Local Swift Package'lar
│  ├─ DesignSystem/                # Renk, tipografi, reusable view'lar
│  ├─ CoreModels/                  # @Model sınıfları, DTO'lar
│  ├─ CloudKitService/             # CKContainer wrapper, CKShare, subscription
│  ├─ AuthService/                 # Sign in with Apple + iCloud user eşleme
│  ├─ MatchEngine/                 # Saf Swift oyun kuralları (test edilebilir)
│  ├─ WordRepository/              # Seed + custom kelime kaynağı
│  └─ L10n/                        # Lokalizasyon helper
│
└─ Features/
   ├─ Onboarding/                  # OnboardingView, SignInViewModel
   ├─ Home/                        # HomeView, HomeViewModel
   ├─ Invite/                      # InviteView, JoinByCodeView
   ├─ Match/                       # AskingView, AnsweringView, ReviewAnswerView
   ├─ Result/                      # ScoreboardView
   ├─ Profile/                     # ProfileView, HistoryView
   └─ Settings/                    # SettingsView

Tests/
├─ MatchEngineTests/               # 30+ deterministik senaryo
├─ CloudKitServiceTests/           # Mock CKContainer
└─ UITests/                        # Onboarding + invite akışı
```

---

## Veri Modelleri (SwiftData @Model + CloudKit)

| Model | Anahtar Alanlar | İlişkiler / Notlar |
|---|---|---|
| **Player** | `appleUserID: String`, `displayName`, `avatarColor: Int`, `createdAt` | Unique `appleUserID`. CloudKit kayıt id deterministik. |
| **Match** | `code: String` (6 hane), `status` (pending/active/finished), `totalRounds=10`, `repeatInterval=3`, `currentRoundIndex`, `hostScore`, `guestScore`, `roundTimerSeconds=30` | `host: Player`, `guest: Player?`, `rounds: [Round]`. `CKShare` ile paylaşılır. Indexed: `code`, `status`. |
| **Round** | `index`, `askerRole`, `word`, `expectedAnswer`, `answerGiven?`, `judgement` (correct/wrong/pendingReview), `pointsAwarded`, `isRepeat`, `originRoundIndex?`, `startedAt`, `resolvedAt` | `match: Match` (parent reference, cascade delete). |
| **PendingRepeat** | Tekrar kuyruğu — `Match` üzerinde `Codable` JSON alan olarak (ek CKRecord değil, istek sayısını azaltır) | Item: `{word, expectedAnswer, dueAtRoundIndex, weight}` |
| **WordEntry** (yalnızca yerel) | `text`, `definition`, `level: CEFR`, `language=en` | İlk açılışta `SeedWords.json`'dan yüklenir, sync edilmez. |
| **ScoreEvent** (audit) | `roundIndex`, `playerID`, `delta`, `reason` | Geçmiş + manuel ret istatistikleri. |

**Sign in with Apple ↔ CloudKit eşleme**: `ASAuthorizationAppleIDCredential.user` (stable id) → `Player.appleUserID`. CloudKit `fetchUserRecordID` paralel kontrol; ilk açılışta credential state doğrula.

---

## Anahtar Ekranlar

Tümü SwiftUI; HIG bileşenleri (NavigationStack, Form, List, ContentUnavailableView, ConfirmationDialog), SF Symbols 6, Dynamic Type, Dark Mode, VoiceOver, `.sensoryFeedback` haptics.

1. **Onboarding** — 3 sayfalı kısa tanıtım (`TabView(.page)`) + `SignInWithAppleButton`. iCloud kapalıysa `ContentUnavailableView` uyarısı.
2. **Home** — `List` (sectioned: Aktif Maçlar / Davetler), boş durumda `ContentUnavailableView`. Sıra sendeyse satırda yanıp sönen nokta. Sağ üst `.toolbar Menu`: Yeni maç, Kodla katıl, Profil. Pull-to-refresh.
3. **Davet et** — `.sheet` + `ShareLink`. Büyük punto monospaced kod gösterimi. "Kopyala" + "Paylaş" butonları.
4. **Kodla katıl** — `Form` + `TextField` (6 hane, `.textInputAutocapitalization(.characters)`). "Katıl" `.borderedProminent`.
5. **Soru sorma (Asker)** — Üst başlık "Tur 4 / 10". `Picker(.segmented)`: "Listeden seç" / "Kendin yaz". Listeden: `.searchable` ile CEFR filtre. Yazarak: 2 `TextField` (kelime + beklenen anlam).
6. **Cevap verme (Answerer)** — `WordCard` ortada, `TextField("Türkçe karşılık")`. **`TimelineView` ile 30 sn geri sayım**, son 10 sn renk değişimi. `.submitLabel(.send)`. Süre dolarsa otomatik "bilmedim".
7. **Manuel onay (ReviewAnswer)** — Otomatik string normalize (lowercase, trim, diakritik, basit Levenshtein toleransı) eşleşmediğinde açılır. Soran "Doğru say" / "Yanlış say" butonlarıyla karar verir. Manuel ret `ScoreEvent.reason = .manualReject` olarak loglanır.
8. **Skor / Sonuç** — Tur arası küçük toast "+2 puan". Maç sonu `Scoreboard`: iki avatar, kazanan `.symbolEffect(.bounce)`, "Tekrar oyna" / "Ana ekran".
9. **Profil / Geçmiş** — Geçmiş maçlar `List`, win/loss rozeti, son 10 maç skor grafiği (Swift Charts).
10. **Ayarlar** — `Picker` dil (Sistem / TR / EN), `Toggle` bildirim tercihleri, "Hesabı Sil" `.destructive` (CloudKit kayıtları temizlenir).

---

## Oyun Mantığı Detayları

**Puan formülü** (`MatchEngine` içinde, saf fonksiyon):
```
ilk kez bilemedi          → soran +2 puan, kelime PendingRepeat'e weight=1 ile eklenir
1. tekrar bilemedi        → soran +4 puan, weight=2 ile kuyrukta kalır
2. tekrar bilemedi        → soran +8 puan, kuyruktan düşer (yeterince ezberlenemediği kabul)
herhangi bir tekrarı bildi → puan yok, kuyruktan düşer
```

**Tekrar kuyruğu**: Kelime bilinmediğinde `dueAtRoundIndex = currentRoundIndex + 3` ile kuyruğa eklenir. Her yeni round başında kuyruk taranır; `dueAtRoundIndex <= currentRoundIndex` olan kelimeler arasından soran isterse seçer (asker'a "tekrar sor" önerisi olarak gösterilir, otomatik dayatma yok — soran kontrolü).

**Cevap kontrolü pipeline**:
1. Normalize: `.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)`, diakritik temizleme.
2. Tam eşleşme → otomatik doğru.
3. Levenshtein mesafesi ≤ 2 (kısa kelimelerde ≤ 1) → otomatik doğru.
4. Aksi halde → ReviewAnswer ekranı, soran karar verir.

**30 sn timer**: Cevap veren ekranı açtığında `Round.startedAt` server'a yazılır. Cihazda `TimelineView` ile geri sayım. Süre dolarsa client tarafı otomatik "bilmedim" gönderir; server-side guard yok (CloudKit'te zor), iki taraf da aynı `startedAt`'ı görür ve uyumlu davranır.

**Tur ilerletme — tek doğru kaynak**: `Match.currentRoundIndex` server-side artırılır (ilk yazan kazanır). Çakışma olursa `recordChangeTag` üzerinden refresh + retry.

---

## Kritik Dosyalar (Faz sonunda var olacak)

- `App/WordDuelApp.swift` — `ModelContainer` + CloudKit konfigürasyonu
- `Packages/MatchEngine/Sources/MatchEngine/MatchEngine.swift` — actor + saf kurallar
- `Packages/MatchEngine/Sources/MatchEngine/Scoring.swift` — `2/4/8` puan tablosu
- `Packages/CloudKitService/Sources/CloudKitService/MatchSyncService.swift` — CKShare oluştur/kabul, subscription
- `Packages/AuthService/Sources/AuthService/AppleSignInService.swift`
- `Packages/WordRepository/Sources/WordRepository/SeedLoader.swift`
- `Features/Match/MatchViewModel.swift` — UI state + MatchEngine köprüsü
- `App/Resources/Localizable.xcstrings` — tr + en
- `App/Resources/SeedWords.json` — CEFR seviyeli ~500 başlangıç kelimesi

---

## Geliştirme Fazları

### Faz 1 — İskelet (3-5 gün)
- Xcode projesi, SPM paketleri, `.xcconfig` build ayarları
- `Localizable.xcstrings` (tr + en), `Info.plist` `CFBundleLocalizations`
- DesignSystem skeleton: renkler, tipografi, `PrimaryButton`, `WordCard`
- App icon placeholder, launch screen
- CI: Xcode Cloud veya GitHub Actions ile `xcodebuild test`

### Faz 2 — Auth & CloudKit Bootstrap (4-6 gün)
- Sign in with Apple capability + button
- CloudKit container `iCloud.com.<team>.wordduel`, schema init (development env)
- `AuthService` → `Player` upsert (private DB)
- `CKAccountStatus` kontrolü, kullanıcıya iCloud kapalıysa uyarı

### Faz 3 — Yerel Oyun Mantığı (5-7 gün)
- `MatchEngine` actor: round üretimi, tekrar kuyruğu, **2-4-8 puanlama**, durum makinesi
- 30+ XCTest senaryosu (tüm doğru, tüm yanlış, karışık tekrarlar, edge cases)
- Local-only "vs computer" debug modu (geliştirici verimi için)

### Faz 4 — CloudKit Match & Davet (6-8 gün)
- Match oluşturma → 6 haneli kod üretimi + private DB kayıt + `CKShare` URL
- "Kodla katıl" akışı: kod → Match'i CKShare üzerinden bul → kabul et
- `Round` yazma/okuma (parent reference). Optimistic UI + conflict resolution

### Faz 5 — Real-time + Push + Timer (5-7 gün)
- `CKQuerySubscription` her aktif `Match` için (yeni `Round` filtresi)
- Silent push → fetch → ViewModel state güncellemesi
- Local notification "Sıra sende" — `UNNotificationContent` lokalize
- 30 sn `TimelineView` geri sayım + otomatik "bilmedim" gönderimi

### Faz 6 — Polish & App Store (5-7 gün)
- Animasyonlar (kart flip, skor bounce), haptics, opsiyonel ses efekti
- Accessibility audit (Accessibility Inspector + VoiceOver gerçek cihaz)
- Localization QA (TR pluralization, HIG terminolojisi)
- App Privacy manifest (`PrivacyInfo.xcprivacy`)
- App Store screenshots (Light/Dark, iPhone + iPad)
- TestFlight beta → 1.0

**Toplam tahmin**: ~4-6 hafta tek geliştiriciyle.

---

## Riskler ve Hafifletmeler

1. **CloudKit subscription gecikmesi (5-30 sn)** → Subscription + aktif maç ekranındayken 5 sn polling. Sub-second gerekirse v2'de Vapor + WebSocket.
2. **Tekrar kuyruğu CKRecord şişmesi** → `Match` üzerinde `Codable` JSON alan olarak tek kayıtta tut.
3. **Sign in with Apple ↔ CloudKit eşleme** → İlk açılışta `fetchUserRecordID` + Apple credential state check; uyumsuzluk varsa logout.
4. **Manuel cevap onayı adillik** → Her manuel ret `ScoreEvent` olarak loglanır; "itiraz et" butonu ileride; profil rejection oranı anti-cheat sinyali.
5. **`currentRoundIndex` çakışması** → İlk yazan kazanır; client retry + refresh.
6. **Offline davranış** → SwiftData yerel cache; yazma kuyruğa alınır; UI'da "Senkronize ediliyor" badge.
7. **App Review** → Sign in with Apple zorunluluğa uygun. Kelime havuzunda küfür/uygunsuz kelime kara listesi seed JSON'da filtrelenir.

---

## Doğrulama (Test Planı)

**Birim testleri** (`MatchEngineTests`):
- Tüm doğru cevap → kimse puan almaz, maç biter, beraberlik
- Tüm yanlış (tek tekrar) → soran 2 puan/kelime
- Tüm yanlış (3 tekrar tam) → 2 + 4 + 8 = 14 puan/kelime
- Karışık: bazı kelimeler ilk turda bilinir, bazıları 1. tekrarda doğru → puan akışı doğru
- 30 sn süre dolması → judgement = wrong, puan akışı doğru
- Tekrar kuyruğu sırası: en eski `dueAtRoundIndex` önce
- Levenshtein toleransı: "studied" ↔ "study" otomatik doğru sayılmamalı (mesafe = 4)

**Manuel uçtan uca** (iki cihaz / iki simülatör):
1. Cihaz A: Sign in → "Yeni maç" → 6 haneli kod kopyala
2. Cihaz B: Sign in → "Kodla katıl" → kodu gir → maç başlasın
3. A → kelime sor (havuzdan) → B 30 sn içinde cevap ver → A onaylasın → skor güncel
4. A → kelime sor (manuel) → B yanlış cevap → soran "yanlış" işaretler → kuyruğa girer
5. 3 tur sonra → A'nın asker ekranında "Bu kelimeyi tekrar sor" önerisi görünmeli
6. Maç bitince Scoreboard, geçmişte kayıtlı, "Tekrar oyna" çalışmalı
7. Push: B uygulamadan çıkar, A round oluşturur, B'ye "Sıra sende" bildirimi gelmeli

**Lokalizasyon**:
- Sistem dili TR ve EN olarak iki kez tüm akış denenir
- Pluralization: "1 tur kaldı" / "3 tur kaldı" doğru çekilmiş

**Accessibility**:
- VoiceOver ile kayıt cihazında onboarding → kodla katıl → tek tur tamamlama mümkün
- Dynamic Type XXL'de kart taşması olmamalı

---

## Kapsam Dışı (v1 İçin Yapılmayacaklar)

- Universal Link / Apple-app-site-association (sadece kod ile davet)
- Random matchmaking (sadece davet kodlu maç)
- Asenkron uzun maç (turn-based, günlere yayılan)
- Sosyal özellikler (arkadaş listesi, leaderboard, sohbet)
- iPad split view özel layout (iPad'de iPhone layout büyütülmüş şekilde çalışır)
- watchOS / macOS uyarlaması
- Çevrimdışı tam oyun (offline yalnızca cache okuma)
- Custom WebSocket sunucu (CloudKit yeterli MVP için)
