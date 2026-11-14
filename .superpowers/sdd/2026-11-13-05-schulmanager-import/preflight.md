# Preflight — Teilplan 05 Schulmanager-Import (2026-11-14)

Branch `feature/batch-b-schulmanager-oberflaeche`, Basis `ac93d25` (Bündel A gemergt).

## Scan

| # | Plan-Behauptung | Ist im Repo | Ergebnis |
|---|---|---|---|
| 1 | Kern-Typen aus 01: `CalendarDay` (`init(_:calendar:)`, `adding(days:)`, `weekday`, `mondayOfWeek`, `storageText`, `init?(storageText:)`), `TimetableEntry`, `Timetable.empty`, `BellSchedule`, `SchoolClass`, `Subject`, `WeekVariant` | vorhanden, Signaturen gleich | ok |
| 2 | `TimetableCalculator.weekVariant(for:timetable:)`, `lessons(on:timetable:nonTeachingPeriods:changes:)` | vorhanden; `weekVariant` mit floorDiv → Test `usesExistingVariantNaming` (16.11. = .b bei Bezug 23.11.) stimmt | ok |
| 3 | `ScheduleChange`, `Origin`, `LessonKey(date:schoolClass:subject:ordinal:)`, Ordinal ab 1 | vorhanden | ok |
| 4 | `ImportDiff`, `ImportDiffer.compare(existing:manuallyEdited:imported:)` | vorhanden; `ImportDiff` nicht Equatable (Vorschau-Modell braucht `==` von Hand, steht im Plan) | ok |
| 5 | Test-Helfer `d(_:_:_:)` | existiert schon in `Tests/FrontstageCoreTests/Fixtures.swift` (+ `t`, `entry`, `timetable`) | **korrigiert** (nicht neu anlegen) |
| 6 | `ClosedRange<CalendarDay>` Codable/Hashable | ja (Bound Codable/Hashable) | ok |
| 7 | App-Tests bauen Kern-Werte (`SourceSnapshot`, `DerivedTimetable`, Test-Form) | App-Tests nutzen `import FrontstageCore` ohne `@testable` → memberwise init von `public struct` unsichtbar | **korrigiert** (öffentliche Initialisierer) |
| 8 | Kern-Aufgaben lokal TDD (`swift-test.ps1`), App nur CI, `swift-parse.ps1` vor CI (Übersicht) | im Plan nicht erwähnt | **korrigiert** (Global Constraints, Aufgabe 14.0) |
| 9 | `DataStore`-Methoden aus 02: `timetable()`, `manuallyEditedEntries()`, `nonTeachingPeriods()`, `scheduleChanges()`, `timetableSourceRaw()`, `setTimetableSourceRaw(_:)`, `sourceFetchedAt()`, `replaceTimetable(entries:manuallyEdited:weekVariantCount:referenceWeekA:bellSchedule:)`, `replaceScheduleChanges(_:sourceFetchedAt:)` | alle vorhanden in `DataStore.swift` / `DataStore+Sources.swift`, Signaturen gleich | ok |
| 10 | `makeStore()` (Test-Hilfe 02), `DataStore.lessons(on:)` | `FrontstageTests/Data/Fixtures.swift`; Typalias `DataStore` in `FrontstageTests/TestSupport/TypeAliases.swift` | ok |
| 11 | Halter-Test „Koordinator sieht Stundenplan über das Repository“ | Koordinator-Interface hatte kein lesbares `repository` | **korrigiert** (`let repository`) |
| 12 | Halter-Test mit `live` | `live` schreibt in `UserDefaults.standard`/Application Support | **korrigiert** (Test injiziert `makeCoordinator`) |
| 13 | `FrontstageApp` Stand nach 08: `DataScopedRoot(controller:) { store, container in … }`, `dataLocation.store`, `@Environment(\.scenePhase)` | vorhanden; `.onChange(of: scenePhase)` am `WindowGroup` existiert bereits (08) | **korrigiert** (bleibt; Closure mit `initial: true` für Kaltstart) |
| 14 | `project.yml` iOS-Ziel `UIBackgroundModes: [fetch]` | vorhanden ist `[remote-notification]` (08) | **korrigiert** (`[remote-notification, fetch]`) |
| 15 | `Localizable.xcstrings`, `sourceLanguage de` | vorhanden; `Bundle.main.localizedString` im Test-Host liefert de | ok |
| 16 | PBKDF2-Referenzwert (Aufgabe 7) | mit Node `pbkdf2Sync` nachgerechnet: 1024 Zeichen, Präfix/Suffix stimmen | ok |
| 17 | Tests Aufgabe 4 (A/B, Ferienwoche, Feiertag) gegen Algorithmus | Erwartungen und Sortierung passen zum Algorithmus | ok |
| 18 | Tests Aufgabe 5/6 gegen Regeln | passen | ok |
| 19 | Tests Aufgabe 3/8 (Login) mit `.recorded` | `.recorded` hat ohne Aufgabe 1 keine Werte | **korrigiert** (Tests mit eigener Test-Form) + Konflikt D1 |
| 20 | Aufgabe 13 `showsFetchedAt` → `.none` | widerspräche `.stale`, wenn aus `status.lastSuccessAt` gerechnet | **korrigiert** (stale aus `fetchedAt`, Test-Vorgaben) |
| 21 | Einrichten-/Leisten-Ansicht `init()` braucht `CredentialStore` | Herkunft offen | **korrigiert** (`KeychainCredentialStore()` Vorgabe-Dienst) |
| 22 | Aufgabe 10 ohne Design-Takt (berührt `FrontstageApp`) | Übersicht verlangt Feld bei UI-Berührung | **korrigiert** (`keiner`) |
| 23 | CI-Sparregel: Aufgabe 14 bleibt, Controller führt aus | Plan sagte nichts dazu | **korrigiert** (Controller, gemeinsam mit 04 im Bündel B) |
| 24 | Mockup-Anker `#quelle`, `#abgleich`; Doku FR/AK/ADR/Area | vorhanden (`einrichten.html` Direkteinstieg; ADR-0004, Area stundenplan-quellen) | ok |
| 25 | `docs/research/` | existiert noch nicht (entsteht in Aufgabe 1) | ok (erwartet) |

Korrekturen gesamt: 13 (Plantext, Commit siehe git log).

## Konflikte auf Entwurfsebene (nicht geändert)

- **D1 — `SchulmanagerAPIShape.recorded` ohne Befundtabelle.** Lauf-Ruling: Aufgabe 1 (Q-16) wird übersprungen. Der
  Plan verlangt aber „Werte wörtlich aus der Befundtabelle … und nirgendwo sonst her“ (Global Constraints, Aufgabe 3.2).
  Es gibt keine Vorgabe für vorläufige Werte (B1–B4, B8–B10). Entscheidung nötig: vorläufige Werte aus den Eltern-/Schüler-
  Quellen (`/api/get-salt`, `schedules/get-actual-lessons`, `schedules/get-class-hours`, Lehrer-Pfad als Platzhalter)
  mit Kommentar „unbelegt, Q-16 offen“ – oder `recorded` so bauen, dass `fetch` ohne Befund `.notConfigured`/Fehler liefert.

## Risiken (kein Plantext-Fehler)

- Schlüsselbund-Test im Simulator mit `CODE_SIGNING_ALLOWED=NO` (ci.yml): ohne eingebettete Entitlements kann
  `SecItemAdd` `errSecMissingEntitlement` (-34018) liefern. Falls rot: Ursache im CI-Log prüfen, nicht raten.
- PBKDF2 mit 99 999 Runden × 512 Byte kostet im Simulator spürbar Zeit je Test; in Aufgabe 8 nur einmal je Test aufrufen.
