# FlourTrack Phase 2 + 3 — Offline-MVP Plan

Stand: 2026-08-09
Branch: `phase2-ios-mvp` (PR-Base: `main`)
Ziel: Spielbarer Offline-MVP, der auf einem echten iPhone läuft.

## Entscheidungprotokoll (Grilling)

| # | Entscheidung | Wahl |
|---|---|---|
| 1 | Scope | Spielbarer Offline-MVP auf Gerät (Phase 2 + 3), offline-first |
| 2 | Deployment-Target | iOS 18 (laut README) |
| 3 | Signing | Free Personal Team via Xcode-UI; Bundle-ID + Automatic Signing gesetzt, `DEVELOPMENT_TEAM` frei |
| 4 | Bundle-ID | `app.flourtrack` |
| 5 | SwiftData-Schema | `GameAttempt` + `PlayerProfile` + `LocalAchievement` |
| 6 | Game-Input | Tap bei 0 |
| 7 | Bewertung | 5 Stufen + Combo + Early-Miss (siehe unten) |
| 8 | Haptics/Audio | Core Haptics + synthetisiertes AVFoundation-Audio, schaltbar |
| 9 | Navigation | TabView: Spielen / Scores / Einstellungen |
| 10 | Achievements | 5 echte Trigger; `around_the_world` deferred (gesperrter Placeholder) |
| 11 | Verifikation | Sim-Build + Sim-Launch durch Claude; Gerät-Launch durch Alex |
| 12 | Branch/PR | `git pull --ff-only` → Feature-Branch → PR auf main |

## Projekt-Setup

- Bestehendes `Flourtrack.xcodeproj` behalten (echtes App-Target, file-synchronized groups).
- `import Playgrounds` + `#Playground` aus `ContentView.swift` entfernen.
- Logo-/Background-Visuals aus `ContentView.swift` extrahieren und in `HomeView` weiterverwenden.
- `IPHONEOS_DEPLOYMENT_TARGET`: 27.0 → 18.0.
- `PRODUCT_BUNDLE_IDENTIFIER`: Placeholder → `app.flourtrack`.
- `CODE_SIGN_STYLE = Automatic` bleibt; `DEVELOPMENT_TEAM` wird in Xcode-UI gesetzt.

## Ordnerstruktur (unter `Flourtrack/`)

```text
Flourtrack/
├── App/
│   └── FlourTrackApp.swift          @main, TabView
├── Models/
│   ├── Rating.swift                  Enum + Schwellen + Score-Formel
│   ├── GameAttempt.swift             SwiftData @Model
│   ├── PlayerProfile.swift           SwiftData @Model
│   ├── LocalAchievement.swift        SwiftData @Model
│   └── AchievementDefinition.swift   6 Seed-Defs + Trigger-Typen
├── Persistence/
│   └── FlourTrackModelContainer.swift
├── Repositories/
│   ├── GameRepository.swift          Protocol + SwiftData-Impl
│   ├── ProfileRepository.swift       Protocol + SwiftData-Impl
│   └── AchievementRepository.swift   Protocol + SwiftData-Impl
├── ViewModels/
│   └── GameViewModel.swift            Countdown, Tap, Score, Combo, Achievement-Unlock
├── Views/
│   ├── HomeView.swift
│   ├── GameView.swift
│   ├── ResultView.swift
│   ├── ScoresView.swift
│   ├── SettingsView.swift
│   └── Components/
│       ├── FlourTrackBackground.swift
│       ├── FlourTrackLogoView.swift
│       ├── StopwatchMark.swift
│       ├── FlourSwipe.swift
│       └── FlourSparkles.swift
└── Audio/
    └── HapticAudioManager.swift      Core Haptics + AVAudioEngine-Synthese
```

## SwiftData-Schema

### GameAttempt

- `id: UUID` (client_game_id, idempotent für späteren Sync)
- `score: Int`
- `accuracyMs: Int` (|Δ| zum Tap-Zeitpunkt)
- `ratingRaw: String` (Perfect/Excellent/Good/Okay/TooSlow/TooEarly)
- `combo: Int`
- `streak: Int`
- `tappedEarly: Bool`
- `createdAt: Date`

### PlayerProfile

- `id: UUID`
- `displayName: String`
- `hapticsEnabled: Bool` (default true)
- `audioEnabled: Bool` (default true)

### LocalAchievement

- `id: UUID`
- `code: String` (z. B. `rookie_baker`)
- `unlockedAt: Date?` (nil = gesperrt/deferred)

## Bewertungslogik

| Rating | Bedingung (|Δ|ms) |
|---|---|
| Perfect | ≤ 50 |
| Excellent | ≤ 120 |
| Good | ≤ 250 |
| Okay | ≤ 500 |
| Too Slow | > 500 |
| Too Early | Tap vor Erreichen von 0 (Miss) |

- Score = `max(0, 1000 − |Δ| · 2) × (1 + combo · 0.1)`
- Combo +1 pro Treffer (alles außer Too Slow / Too Early), Reset bei Miss.
- Early Tap = Miss, bricht Combo.

## Core Game Loop

1. Home: Logo + „Start"-Button.
2. Game: Countdown 5→0 mit Haptics-Tick pro Sekunde + Audio-Beep.
3. Tap stoppt Timer → |Δ|ms → Rating → Score + Combo.
4. Tap vor 0 → Too Early → Miss, Combo-Reset.
5. Result: Rating, Score, Combo, Best-Vergleich, Achievement-Toast.
6. SwiftData: `GameAttempt` mit `client_game_id` speichern.
7. Achievement-Unlock prüfen.

## Achievements (lokale Trigger)

| Code | Trigger |
|---|---|
| `rookie_baker` | 1 abgeschlossenes Spiel |
| `millisecond_master` | 1× Perfect (≤ 50 ms) |
| `flour_power` | Combo ≥ 5 |
| `precision_machine` | 3 Perfects in Folge |
| `early_bird` | Spiel vor 08:00 lokaler Zeit |
| `around_the_world` | gesperrter Placeholder („braucht MapKit / Year in Swipe") |

## Haptics & Audio

- Core Haptics: Countdown-Tick pro Sekunde + Rating-Feedback (bei Perfect stärker).
- AVAudioEngine: synthetisierter Sinus-Ton pro Countdown-Stufe und Rating.
- Beide via `PlayerProfile.hapticsEnabled` / `audioEnabled` schaltbar.

## Repository-Protokolle

`GameRepository`, `ProfileRepository`, `AchievementRepository` als Protokolle mit lokaler SwiftData-Implementierung. Backend-Implementierung (Phase 4) später einklinkbar, ohne View-Änderungen.

## Verifikation

- `xcodebuild build` für verfügbare Simulator-Destination (iOS 18 falls Runtime installiert, sonst iOS 27).
- `xcodebuild build` generic/platform=iOS (Compile-Check ohne Signing).
- Simulator booten + App launchen.
- Gerät-Launch: Alex öffnet Xcode, wählt Personal Team, Run.

## Out-of-Scope (spätere Phasen)

- Backend-Game-APIs (Phase 4), Leaderboards, Freunde/Social (Phase 6).
- Year in Swipe, MapKit, Charts, Statistiken (Phase 5).
- `around_the_world`-Achievement.
- Sign in with Apple, Token in Keychain.
- CI, Tests, Polish (Phase 7).