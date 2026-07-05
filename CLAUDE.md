# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WordDuel is a real-time, turn-based English vocabulary dueling game for two players — a native iOS app. The game mechanic: Player A asks Player B an English word; B earns nothing if correct, A earns points if wrong, and missed words recur after 3 rounds with exponentially increasing stakes (2→4→8 points).

**Stack**: iOS 18+, SwiftUI (pure), Swift 6 strict concurrency, `@Observable`, SwiftData for local persistence, CloudKit public DB for multiplayer sync.

## Build & Development Commands

The `.xcodeproj` is not committed — it is generated from `project.yml`:

```bash
# First time setup
brew install xcodegen
xcodegen generate
open WordDuel.xcodeproj
```

Re-run `xcodegen generate` whenever `project.yml` changes.

**Run MatchEngine tests (no Xcode, no iOS SDK needed — runs on Linux/macOS)**:
```bash
cd Packages/MatchEngine
swift test
```

**Run tests for any other package locally**:
```bash
cd Packages/<PackageName>
swift test
```

**CI runs**:
- `MatchEngine` tests on Ubuntu via `swift test --parallel`
- iOS build (no tests) on `macos-15` using XcodeGen + `xcodebuild build ... CODE_SIGNING_ALLOWED=NO`
- TestFlight deploy via Fastlane (`bundle exec fastlane beta`), triggered manually or by `v*` tags

## Architecture

### Package Structure

Seven local SPM packages under `Packages/`, each independently testable:

| Package | Purpose |
|---|---|
| `CoreModels` | SwiftData `@Model` classes (`Match`, `Round`, `Player`, `WordEntry`, `ScoreEvent`) + shared value types (`MatchStateSnapshot`, `PendingRepeatItem`, enums) |
| `MatchEngine` | Pure Swift game rules — no UI/SwiftData dependency. The canonical state machine for game logic, scoring, and the repeat queue. Tests run on Linux. |
| `CloudKitService` | CloudKit actors: `MatchSyncService` (facade), `InviteRepository` (`MatchInvite` in public DB), `MatchStateRepository` (append-only `MatchState` revisions in public DB), `SubscriptionManager`, `TurnNotifier`, `PushNotificationHandler` |
| `AuthService` | `AuthController` (@Observable), `AppleSignInService`, `KeychainProfileStore`, `PlayerUpsert` |
| `DesignSystem` | Color tokens, typography, spacing/radius constants, reusable components (`PrimaryButton`, `AvatarView`, `TimerRing`, `WordCard`, `ConfettiView`, `.wdCard()` modifier, button styles) |
| `WordRepository` | `SeedLoader` — loads bundled `SeedWords.json` (English words with definitions and CEFR levels) |
| `L10n` | Runtime language helpers; the app uses Apple String Catalogs (`Localizable.xcstrings`) for TR/EN |

### App Layer

- `WordDuelApp` — `@main`. Creates `ModelContainer` (CloudKit-resilient), `AuthController`, `AppServices`. Injects both into the environment.
- `AppServices` — `@Observable @MainActor`. Holds `MatchSyncService`, `SubscriptionManager`, `LocalNotificationScheduler`, and an `AsyncStream` for push notification outcomes.
- `AppRoot` — Switches root view based on `AuthController.phase`: `OnboardingView` when signed out, `NameEntryView` when the display name is placeholder/empty, `HomeView` when fully signed in.
- `AppConstants` — Central place for `cloudKitContainerID` (`iCloud.club.kadro.wordduel`), `cloudKitEnabled` flag, and the UserDefaults key. **`cloudKitEnabled` only controls SwiftData's private-DB mirror; match sync over the public-DB revision chain always runs.**

### Feature Screens (`Features/`)

```
Home/         HomeView + HomeViewModel — match list, create/join entry points
Invite/       InviteView (host shares code), JoinByCodeView + ViewModel (guest enters code)
Match/        MatchDetailView, AskingView, AnsweringView, ReviewAnswerView, MatchFlow
Result/       ScoreboardView
Profile/      ProfileView, HistoryView
Onboarding/   OnboardingView, NameEntryView, SignInViewModel
Settings/     SettingsView
Shared/       MatchCloudSync, MatchStats, SoundPlayer
```

### Match Sync Architecture (Critical)

**CKShare and shared CloudKit zones are intentionally NOT used** — SwiftData's CloudKit mirror does not support shared zones (prior attempt using CKShare resulted in guests receiving an empty zone). Instead:

1. Every mutation (word ask, answer, manual review, guest join) serializes the **complete match state** as `MatchStateSnapshot` (JSON) and writes it to the CloudKit public DB as a new `MatchState` record named `state-<code>-<revision>` (append-only; existing records are never updated, avoiding the "only creator can update" public DB restriction).
2. The opponent device fetches `revision+1` by record name (no query index needed), applies it to the local `Match` via `MatchStateSnapshot.apply(to:in:)`, and increments `syncRevision`.
3. `MatchDetailView` polls every 3 seconds while open. `HomeView` pulls on appear/refresh.
4. **Write discipline**: each device only pushes its own action. Turn-based flow makes simultaneous writes rare; if they collide on the same revision name, the second writer gets a conflict error and falls back to `pull` to reconcile.
5. Guest join flow: `MatchCloudSync.materialize` downloads the chain, guest claims the seat, pushes the updated state — host's next poll starts the match.

Key files:
- `MatchCloudSync` (`Features/Shared/`) — `push`, `pull`, `materialize`, `join` — the `@MainActor enum` bridging SwiftData and CloudKit
- `MatchStateRepository` (`CloudKitService`) — raw CloudKit record I/O
- `MatchStateSnapshot` (`CoreModels`) — the wire format and `apply(to:in:)` reconciliation logic
- `MatchFlow` (`Features/Match/`) — applies `MatchEngine` rules to persistent `Match`/`Round` SwiftData models
- `MatchEngine` (`Packages/MatchEngine/`) — pure state machine, no persistence

### Game Rules (MatchEngine → MatchFlow)

- 10 rounds total; even-indexed rounds are asked by the host, odd by the guest.
- `AnswerNormalizer.autoJudge`: exact match → `.correct`; Levenshtein within tolerance (0 for <5 chars, 1 for 5–7, 2 for 8+) → `.correct`; otherwise → `.needsManualReview` (asker manually accepts/rejects).
- Wrong answer: asker scores `Scoring.points(forWeight:)` — weight 1→2pts, 2→4pts, 3→8pts. Word re-queued at `currentRoundIndex + repeatInterval` with `weight+1`.
- Word re-enters as a `isRepeat` round; if wrong at `maxWeight` (3), it drops from the queue permanently.
- `Match.pendingRepeats` stores the queue serialized as JSON in a `Data` field (SwiftData limitation for arrays of non-`@Model` types).

### Auth Flow

`AuthController` stores `appleUserID` in `UserDefaults`. On launch, `bootstrap` immediately restores `.signedIn` from storage, then asynchronously checks Apple credential state — only `.revoked` triggers sign-out. Apple's display name arrives only on first sign-in; subsequent launches restore it from Keychain via `KeychainProfileStore`. If the stored name is auto-generated (placeholder), `AppRoot` routes to `NameEntryView`.

### Design System Conventions (King Style UI)

The app uses a "King Style" candy-game design language: saturated candy colors on a lavender-sky gradient background, chunky 3D beveled buttons, and heavy rounded typography. All UI must use tokens from `DesignSystem`:
- Colors: `Color.wdAccent` (candy pink), `.wdInk`, `.wdInkSecondary`, `.wdSurface`, `.wdSurfaceSecondary`, `.wdSuccess`, `.wdDanger`, `.wdWarning`, `.wdGold`; each action color has a darker `…Edge` counterpart (`.wdAccentEdge`, `.wdSuccessEdge`, `.wdDangerEdge`, `.wdGoldEdge`, `.wdSurfaceEdge`) used for the 3D bottom bevel
- Gradients: `LinearGradient.wdAccentGradient` (primary CTA), `.wdSuccessGradient` (confirm/play), `.wdGoldGradient`, `.wdScreenGradient` (screen background)
- Screen background: `.wdScreenBackground()` view modifier — full-bleed lavender gradient; prefer it over flat `Color.wdBackground`
- Spacing: `WDSpacing.xs/sm/md/lg/xl` (4pt rhythm)
- Corner radius: `WDRadius.sm/md/lg/xl` — always `.continuous` style
- Bevel heights: `WDBevel.card/button` — the hard bottom edge is drawn with a zero-radius shadow offset by the bevel height
- Typography: `Font.wdDisplay`, `.wdTitle`, `.wdHeadline`, `.wdSubheadline`, `.wdLabel`, `.wdCaption` (all rounded system font, heavy headline weights)
- Card surface: `.wdCard()` view modifier (candy panel with bottom bevel)
- Buttons: `WDProminentButtonStyle(.primary/.secondary/.destructive/.success)` (3D beveled, presses down onto its edge) and `WDPressableButtonStyle`
- Avatar: `AvatarView(name:colorIndex:size:)` with `AvatarPalette.color(for:)` (candy palette, thick surface-colored ring)

### Swift 6 Strict Concurrency

`SWIFT_STRICT_CONCURRENCY = complete` is enforced globally. All types crossing actor boundaries must be `Sendable`. CloudKit service types are `actor`; `MatchEngine` is `actor`; app-layer state is `@MainActor @Observable`. `MatchFlow` and `MatchCloudSync` are `@MainActor`.

### CloudKit Schema

Two record types in the **public DB** (no query indexes needed — all reads use deterministic record names):
- `MatchInvite` — record name `invite-<code>`; fields: `code`, `shareURL`, `hostUserRecordName`, `createdAt`, `expiresAt`
- `MatchState` — record name `state-<code>-<revision>`; fields: `code`, `revision`, `payload` (JSON bytes), `createdAt`

SwiftData `@Model` types (`Player`, `Match`, `Round`, `WordEntry`, `ScoreEvent`) are defined in `CoreModels` and registered via `SchemaContainer`.

### Bundle ID & Entitlements

- Bundle ID: `club.kadro.wordduel`
- Debug entitlements: `App/wordduel.entitlements` (development push environment)
- Release entitlements: `App/wordduel-release.entitlements` (production push environment)
- Required capabilities: Sign in with Apple, iCloud → CloudKit (`iCloud.club.kadro.wordduel`), Push Notifications, Background Modes → Remote notifications
