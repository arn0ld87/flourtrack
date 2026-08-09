# Recherche: Offline-First-Sync-Muster für FlourTrack (Phase 4)

**Datum:** 2026-08-09
**Projekt:** FlourTrack iOS
**Scope:** SwiftData (lokal) + REST-Backend-Sync

---

## 1. Simple Outgoing Sync Queue in SwiftData

### Problem
Ein Spieler speichert ein Spiel offline. Die App muss den Upload zuverlässig später nachholen, ohne Daten zu verlieren.

### Lösung: Lokale Outbox/Queue
Die robuste Basis ist eine **einfache Outbox-Tabelle** in SwiftData. Jedes zu synchronisierende Ereignis wird als eigener Datensatz mit Status persistiert.

**Schema-Vorschlag:**

```swift
@Model
class SyncQueueItem {
    var id: UUID
    var entityType: String      // z.B. "Game"
    var payload: Data           // JSON-codierter Payload
    var status: SyncStatus      // .pending, .inProgress, .completed, .failed
    var createdAt: Date
    var retryCount: Int
    var lastError: String?
}

enum SyncStatus: String, Codable {
    case pending
    case inProgress
    case completed
    case failed
}
```

**Ablauf:**
1. Spiel wird lokal in SwiftData gespeichert.
2. Ein `SyncQueueItem` mit Status `.pending` wird angelegt.
3. Der Upload-Worker holt sich alle `.pending`-Items, markiert sie als `.inProgress`, sendet sie an das Backend.
4. Bei Erfolg: Item wird gelöscht oder als `.completed` markiert.
5. Bei Fehler: `retryCount` wird erhöht, Status zurück auf `.pending` (ggf. mit Exponential Backoff).

**Wichtig:**
- **Kleine Batches:** Maximal 10–20 Items pro Upload-Run, um Memory und Zeit zu begrenzen.
- **Idempotente Operationen:** Jedes Queue-Item muss eine eindeutige ID mitführen (siehe Abschnitt 2).
- **Persistenz vor Netzwerk:** Nie ein Event nur im Memory halten — sofort in SwiftData schreiben.

**Quellen:**
- [What I Wish I Knew About Background Tasks on Mobile Apps – Level Up Coding](https://levelup.gitconnected.com/what-i-wish-i-knew-about-background-tasks-on-mobile-apps-db6b18851482) — Praktisches Beispiel für UploadQueueStore mit JSON-Datei auf Disk (analog auf SwiftData übertragbar).
- [AWS Transactional Outbox Pattern](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html) — Architekturpattern für zuverlässige Event-Publikation.

---

## 2. Idempotency-Muster für POST /games

### Problem
POST ist per HTTP-Definition nicht idempotent. Ein Timeout oder ein Crash nach dem Senden, aber vor dem Empfang der Antwort, führt zu einem "Phantom-Game" oder einem doppelten Eintrag.

### Lösung: Client-generierte Idempotency-Key
Da FlourTrack bereits `client_game_id` im Schema hat, ist das Idempotency-Muster nahezu gratis.

**Implementierung:**

1. **Client generiert UUID** für jedes neue Spiel (z.B. `client_game_id = UUID()`).
2. **Header oder Payload:** Das Backend akzeptiert den Key entweder als Header (`Idempotency-Key`) oder direkt im Body (`client_game_id`).
3. **Server speichert Key:** Bevor die eigentliche Verarbeitung beginnt, prüft der Server, ob der `client_game_id` schon existiert.
   - Falls ja: Server liefert den gespeicherten Datensatz zurück (oder `409 Conflict` mit Link zum bestehenden Resource).
   - Falls nein: Spiel wird angelegt, `client_game_id` + Response werden gespeichert.

**Beispiel-Request:**

```http
POST /games HTTP/1.1
Content-Type: application/json
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000

{
  "client_game_id": "550e8400-e29b-41d4-a716-446655440000",
  "score": 1250,
  "player_id": "user-123",
  "played_at": "2026-08-09T14:30:00Z"
}
```

**Best Practices:**
- **Key-Lifetime:** Idempotency-Keys sollten mindestens 24h, besser 7 Tage, gespeichert werden.
- **Atomare Prüfung:** Prüfung auf Duplikat und Speicherung müssen in einer Transaktion erfolgen, um Race Conditions zu vermeiden.
- **Request-Fingerprinting:** Stelle sicher, dass bei gleichem Key auch die Payload übereinstimmt. Bei abweichendem Body → `422 Unprocessable Entity`.

**Quellen:**
- [Stripe API Reference – Idempotent Requests](https://docs.stripe.com/api/idempotent_requests) — De-facto Standard für Idempotency-Keys.
- [MDN – Idempotency-Key Header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Idempotency-Key) — HTTP-Spezifikation.
- [Zuplo – Implementing Idempotency Keys in REST APIs](https://zuplo.com/learning-center/implementing-idempotency-keys-in-rest-apis-a-complete-guide) — Umfassende Implementierungsleitfäden in Python, TypeScript, Go.
- [APIs You Won't Hate – Make Your API Idempotent](https://apisyouwonthate.com/blog/idemptoency-keys/) — Praktische Beispiele und Fehlervermeidung.

---

## 3. Conflict Resolution: last-write-wins vs. server-wins vs. CRDT

### Szenario
FlourTrack ist ein **einfacher Spiel-Score-Upload**. Ein Spieler kann offline ein Spiel speichern. Wenn er wieder online kommt, soll der Score hochgeladen werden. Die App hat keine Multi-Device-Sync zwischen Telefon und iPad (zumindest nicht in Phase 4).

### Empfehlung: Server-wins mit Idempotency-Key (einfachste Variante)

| Strategie | Eignung für FlourTrack |
|-----------|------------------------|
| **Last-Write-Wins (LWW)** | Einfach, aber riskant. Wenn zwei Offline-Spiele hochgeladen werden, gewinnt der letzte Timestamp. Für reine Score-Uploads akzeptabel. |
| **Server-wins** | Am besten für FlourTrack geeignet. Der Server ist Source of Truth. Client-Uploads werden akzeptiert, aber der Server hat das letzte Wort. |
| **CRDT (Conflict-free Replicated Data Types)** | Überdimensioniert. CRDTs sind für kollaborative Editoren oder echte Multi-Device-Echtzeitsync gedacht. |

**Begründung:**
- FlourTrack ist **nicht kollaborativ**. Es gibt keine gleichzeitige Bearbeitung eines Spiels durch mehrere Benutzer.
- Die einzige potenzielle Konfliktquelle ist ein **doppelter Upload** desselben Spiels — das löst der Idempotency-Key.
- Ein **Server-wins**-Ansatz bedeutet: der Server nimmt den Upload an, validiert ihn (z.B. Anti-Cheat, Score-Plausibilität) und speichert ihn. Wenn der Server einen Fehler zurückgibt, bleibt das Queue-Item auf `.pending` und wird später erneut versucht.

**Alternative: Last-Write-Wins mit clientseitigem Timestamp**
Wenn FlourTrack in Zukunft Multi-Device-Sync unterstützen soll, kann LWW mit einem `modified_at`-Timestamp auf dem Server eingeführt werden. Der Server vergleicht Timestamps und nimmt nur den neueren Wert. Das ist aber **nicht nötig** für Phase 4.

**Quellen:**
- [Hacker News – Downsides of Offline First](https://news.ycombinator.com/item?id=28717848) — Diskussion über LWW als einfachen CRDT-Typ.
- [RxDB – CRDT Alternative](https://rxdb.info/crdt.html) — Beispiel für Field-Level-Merging statt CRDT.
- [Ditto – How to Build Robust Offline-First Apps](https://www.ditto.com/blog/how-to-build-robust-offline-first-apps-a-technical-guide-to-conflict-resolution-with-crdts-and-ditto) — Tiefe technische Einordnung, wann CRDTs Sinn machen.

---

## 4. Background Upload in iOS

### Optionenvergleich

| Ansatz | Wann nutzen | Vorteile | Nachteile |
|--------|-------------|----------|-----------|
| **BGTaskScheduler** | Periodische, nicht-sofortige Uploads | Von iOS verwaltet, batterieeffizient, robust | Unvorhersehbar wann es läuft; max. alle 15 Min.; App muss im Hintergrund erlaubt sein |
| **Manuelles Push-on-App-Open** | Sofort-Sync beim Öffnen | Einfach, deterministisch, kein Background-Mode nötig | Kein Sync, wenn App nicht geöffnet wird |
| **URLSession Background Tasks** | Große Dateien oder viele kleine Uploads | Läuft im separaten Prozess, App wird bei Fertigstellung geweckt | Komplexer, erfordert Delegate-Handling, nicht für kleine JSON-Events optimiert |

### Empfohlene Strategie für FlourTrack: Hybrid

**Primär:** Push-on-App-Open
- Beim `scenePhase` Wechsel zu `.active` oder in `onAppear` der Hauptansicht: Prüfe Queue, starte Upload.
- Einfach, zuverlässig, kein Background-Mode nötig.

**Sekundär (optional):** BGTaskScheduler für "Gelegenheitssync"
- Falls der Nutzer die App lange nicht öffnet, kann ein `BGProcessingTaskRequest` ab und zu die Queue leeren.
- Identifier in `Info.plist` registrieren (`BGTaskSchedulerPermittedIdentifiers`).
- `requiresNetworkConnectivity = true`, kleine Batch-Größe (max. 20 Games).

**Beispiel BGTaskScheduler (für optionale Erweiterung):**

```swift
import BackgroundTasks

final class BackgroundUploadScheduler {
    static let shared = BackgroundUploadScheduler()
    private let taskId = "de.flourtrack.uploadQueue"
    private init() {}

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: nil) { task in
            guard let task = task as? BGProcessingTask else { return }
            self.handle(task)
        }
    }

    func schedule() {
        let request = BGProcessingTaskRequest(identifier: taskId)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handle(_ task: BGProcessingTask) {
        schedule() // Reschedule next run
        Task {
            do {
                try await SyncEngine.shared.flushQueue()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }
}
```

**Wichtig:** iOS führt Background-Tasks nur aus, wenn die App "genug genutzt" wird. Für eine Gelegenheits-App wie FlourTrack ist **Push-on-App-Open** der zuverlässigere Pfad.

**Quellen:**
- [What I Wish I Knew About Background Tasks on Mobile Apps](https://levelup.gitconnected.com/what-i-wish-i-knew-about-background-tasks-on-mobile-apps-db6b18851482) — Umfassendes Praxisbeispiel mit BGTaskScheduler + URLSession.
- [Apple Developer – Finish tasks in the background (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/227/) — Aktuelle Apple-Doku zu Background-APIs.
- [iOS 18 Background Survival Guide – Stackademic](https://blog.stackademic.com/ios-18-background-survival-guide-part-3-unstoppable-networking-with-background-urlsession-f9c8f01f665b) — Tiefe Einblicke in URLSession-Background-Transfers.

---

## 5. Reference-Implementierungen

### Apple-Ökosystem
- **SwiftData + CloudKit:** Apple bietet native Sync über `NSPersistentCloudKitContainer`. Für FlourTrack aber **nicht passend**, weil ein REST-Backend existiert und CloudKit nicht für externe APIs gedacht ist.
- **Apple Sample Code:** Es gibt kein offizielles "Offline Sync with REST" Sample, aber die [BackgroundTasks-Framework-Doku](https://developer.apple.com/documentation/backgroundtasks) und [URLSession-Doku](https://developer.apple.com/documentation/foundation/urlsession) sind die primären Referenzen.

### Drittanbieter-Patterns
- **WatermelonDB (React Native):** Beliebtes Offline-First-Pattern mit "Sync Primitive" und konfliktfreier Auflösung. Das Konzept einer lokalen Queue und eines separaten Sync-Workers ist direkt auf SwiftData übertragbar.
  - [WatermelonDB + MongoDB Guide](https://medium.com/@vineetdixit.vns/offline-first-architecture-with-watermelondb-and-mongodb-7efee1a09bb0)
  - [WatermelonDB + Expo Guide](https://dev.to/fasthedeveloper/watermelondb-expo-sdk-54-the-complete-mobile-offline-first-setup-guide-that-actually-works-5he5)

- **Realm Sync:** MongoDB Realm bietet eingebaute Offline-First-Sync. Für FlourTrack aber Overkill, da ein eigenes Backend existiert.

- **RxDB (JavaScript):** Hervorragende Dokumentation zu Conflict Resolution und CRDT-Alternativen. Die Patterns (Queue, Batch-Upload, Idempotency) sind sprachunabhängig anwendbar.
  - [RxDB CRDT Docs](https://rxdb.info/crdt.html)

### Empfohlener Architektur-Stack für FlourTrack

```
┌─────────────────────────────────────┐
│           UI (SwiftUI)              │
│  - Spiel speichern → lokal sofort   │
│  - Queue-Status anzeigen (optional)  │
└─────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│        SwiftData (lokal)            │
│  - Game-Entities                      │
│  - SyncQueueItem (Outbox)            │
└─────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│        SyncEngine (Actor)           │
│  - Holt Queue-Items                  │
│  - Batch-Upload (max 20)           │
│  - Retry mit Exponential Backoff     │
│  - Idempotency-Key pro Request       │
└─────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│         REST Backend                │
│  - POST /games (idempotent)         │
│  - Server-wins Conflict Resolution   │
└─────────────────────────────────────┘
```

---

## Zusammenfassung der Top-3-Erkenntnisse

1. **Einfache Outbox in SwiftData:** Ein dediziertes `SyncQueueItem`-Model mit Status (`pending`/`inProgress`/`completed`/`failed`) ist der robuste Kern. Nie Events nur im Memory halten — sofort persistieren. Kleine Batches (≤20) pro Upload-Run verhindern Timeouts und Memory-Pressure.

2. **Idempotency ist fast gratis:** FlourTrack hat bereits `client_game_id`. Der Client sendet diesen Key als `Idempotency-Key`-Header (oder im Body) mit jedem POST /games. Der Server speichert den Key atomar und ignoriert Duplikate. Das verhindert doppelte Einträge bei Timeouts, Crashes oder Retries.

3. **Push-on-App-Open > Background Tasks:** Für eine Gelegenheits-App wie FlourTrack ist der einfachste und zuverlässigste Sync-Pfad das Abfeuern der Queue beim App-Start oder bei `.active`-Scene-Phase. BGTaskScheduler ist optional, aber nicht verlässlich genug für den primären Sync-Pfad, da iOS die Ausführung stark drosselt.

---

*Recherche durchgeführt mit Firecrawl + Web-Suche. Alle Quellen sind verlinkt.*
