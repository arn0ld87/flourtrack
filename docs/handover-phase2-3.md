# FlourTrack Handover — Phase 2 + 3 (Offline-iOS-MVP)

Last updated: 2026-08-09
Vorherige Handover: `HANDOVER.md` (Phase 1, Backend-Infrastruktur).
Plan: `docs/phase-2-3-mvp-plan.md`.

## Stand

- GitHub: https://github.com/arn0ld87/flourtrack
- Branch: `phase2-ios-mvp` → PR #1 → `main` (noch offen)
- Basis-Commit auf `main`: `f8d89d9` (Add FlourTrack logo)
- Commit auf Branch: „Phase 2+3: spielbarer Offline-iOS-MVP"
- App **läuft auf dem echten iPhone 16 Pro** (iOS 27.0), installiert via Xcode Run.

## Produkt

Native iPhone Arcade-/Timing-Spiel. Werte fiktiv, kein Drug/Medical-Bezug. 7-Phasen-Roadmap (streng):
Phase 1 ✅ · **Phase 2 ✅ + Phase 3 ✅ (dieser Handover)** · Phase 4 Backend APIs · Phase 5 Stats · Phase 6 Social · Phase 7 Quality.

Dieser MVP ist **offline-first**: keine Backend-APIs, kein Social, keine Stats-Sync. Nur lokale SwiftData-Persistenz.

## Architektur (iOS-Target)

Bundle-ID `app.flourtrack`, Deployment-Target iOS 18.0, Swift 5, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` (→ explizite `import Combine`/`SwiftUI` nötig). `PBXFileSystemSynchronizedRootGroup` — neue Dateien in `Flourtrack/` werden ohne pbxproj-Edits gebaut.

```
Flourtrack/
├── App/FlourTrackApp.swift          @main, ModelContainer, TabView, HapticAudioManager inject
├── Models/
│   ├── Rating.swift                 reine Wertelogik (5 Stufen + Early-Miss, Combo-Score)
│   ├── GameAttempt.swift            @Model, @Attribute(.unique) attemptId = client_game_id
│   ├── PlayerProfile.swift          @Model (displayName, haptics/audio flags)
│   ├── LocalAchievement.swift        @Model, @Attribute(.unique) code
│   └── AchievementDefinition.swift  statische Defs + Trigger-Enum
├── Persistence/FlourTrackModelContainer.swift   Schema, ModelContainer.make()
├── Repositories/                   Protokolle + SwiftData-Implementierungen
│   ├── GameRepository.swift         save, recentAttempts, bestScore, bestCombo, lastPerfectsInARow
│   ├── ProfileRepository.swift     current() (legt erstes Profil an)
│   └── AchievementRepository.swift  all, seedIfNeeded, unlock(code)->Bool, isUnlocked
├── Audio/HapticAudioManager.swift  Core Haptics + synthetisiertes AVAudio-Audio, schaltbar,
│                                   Inject über `\.hapticAudio` EnvironmentKey; #if !os(macOS) für AVAudioSession
├── ViewModels/GameViewModel.swift  @MainActor ObservableObject
│                                   Phasen idle/counting/waitingTap/result, Countdown 5→0,
│                                   Tap-Scoring (early→Too Early, late→Rating), Combo/Streak,
│                                   Auto-Too-Slow-Fallback (~1,2 s), Achievement-Eval, Persist
└── Views/
    ├── RootView.swift               TabView Spielen/Scores/Einstellungen, baut GameViewModel
    ├── PlayView.swift               routed phase→Home/Game/Result
    ├── HomeView.swift               Logo + Start
    ├── GameView.swift               Countdown/Tap-Fläche (ganzes Display tappbar)
    ├── ResultView.swift             Rating, Score, Combo, Δ ms, neu freigeschaltet
    ├── ScoresView.swift             Best/Combo + letzte 50 Versuche (SwiftData)
    ├── SettingsView.swift           Name, Haptik/Audio-Toggle, Achievements-Liste
    └── Components/FlourTrackVisuals.swift  Hintergrund + Logo + StopwatchMark/FlourSwipe/FlourSparkles
```

`Flourtrack/ContentView.swift` ist leer/auskommentiert (Komponenten extrahiert, `@main` nach `App/FlourTrackApp.swift` verschoben).

## Spiellogik

- Countdown 5→0 (jede Sekunde Haptic+Ton). Tap vor 0 = **Too Early** (Miss, Score 0). Tap bei/nach 0 = Rating aus `accuracyMs`.
- Rating-Schwellen (ms): Perfect ≤50, Excellent ≤120, Good ≤250, Okay ≤500, sonst Too Slow.
- Score = `max(0, 1000 − accuracyMs·2) · (1 + combo·0.1)`, gerundet. Bei Miss: 0.
- Combo bricht bei Miss auf 0; Streak analog.
- Auto-Too-Slow nach ~1,2 s ohne Tap (accuracyMs 1500).

## Achievements

5 echte lokale Trigger: `rookie_baker` (1 Spiel), `millisecond_master` (1× Perfect), `flour_power` (Combo ≥5), `precision_machine` (3 Perfects in Folge via `lastPerfectsInARow`), `early_bird` (vor 08:00 Uhr spielen). `around_the_world` bewusst **deferred** (braucht MapKit / Year-in-Swipe).

## Build & Device-Install

**CLI (Compile-Checks, ohne Zertifikat):**
```bash
xcodebuild -project Flourtrack.xcodeproj -scheme Flourtrack \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build   # → BUILD SUCCEEDED
xcodebuild -project Flourtrack.xcodeproj -scheme Flourtrack \
  -destination 'generic/platform=iOS' -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build                                              # → BUILD SUCCEEDED (Device-Arch)
```

**Aufs echte iPhone (free Personal-Team-Provisioning, nur Xcode-GUI):**

CLI kann **kein** free Provisioning erzeugen („No Account for Team" / „No profiles for app.flourtrack"). Team `RFZ5FCPC5Q` ist im pbxproj hinterlegt (Automatic Signing).

1. Xcode (Xcode-beta) → Settings → Accounts → „+" → Apple ID → `arn0ld816@icloud.com`.
2. Target *Flourtrack* → Signing & Capabilities → Automatically manage Signing, Team = Personal Team.
3. Gerät **Alex iPhone 16 Pro** wählen → ▶ Run (⌘R). Xcode generiert das 7-Tage-Profil und installiert.
4. Falls „Untrusted Developer": iPhone → Einstellungen → Allgemein → VPN & Geräteverwaltung → vertrauen. Developer Mode ist bereits Enabled.

Profil ist 7 Tage gültig; danach in Xcode neu builden (Run erneuert automatisch).

## Verifikation (diese Session)

- `xcodebuild` BUILD SUCCEEDED für generic iOS Simulator und generic iOS (Device-Arch).
- App läuft installiert auf iPhone 16 Pro (iOS 27.0), TabView + Spielrunde durchspielbar.

## Out of Scope (bewusst)

- Backend-APIs (Phase 4), Stats (Phase 5), Social (Phase 6).
- MapKit/`around_the_world`-Achievement.
- Sync der lokalen `GameAttempt`-Datensätze nach Backend (Schema ist idempotent vorbereitet: `attemptId = client_game_id`).
- Animationen-Polish, App-Icon-Asset, Launch-Screen-Asset (System-Default aktuell).

## Nächste Schritte

1. PR #1 mergen (`phase2-ios-mvp` → `main`), Empfehlung: **Squash** (ein atomarer MVP-Commit, Fixup-Rauschen vermeiden).
2. Phase 4: Backend APIs — `POST /games` (idempotent via `client_game_id`), `GET /games` (History), Auth. SwiftData-Sync: `attemptId` ist schon der idempotente Key; Repository braucht dann eine Sync-Queue (offline-first: local-first, später push).
3. Vor Phase 4: Phase 1 auf `armserver` prüfen (`docker compose ps`, `/health/ready`) — nicht vergessen, die App ist aktuell rein lokal.

## Offene Hinweise

- SourceKit zeigt in einigen Dateien „Cannot find type … in scope" — das sind macOS-Host-False-Positives; der iOS-Build ist sauber.
- `AVAudioSession` ist `#if !os(macOS)`-geguardt, weil das Target multiplatform ist (macOS u.a.); Audio läuft nur auf iOS.
- `docs/phase-2-3-mvp-plan.md` enthält den vollständigen 12-Entscheidungs-Baum der Grilling-Session als Nachschlag.