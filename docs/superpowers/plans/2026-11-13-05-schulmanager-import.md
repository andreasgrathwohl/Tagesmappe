# Frontstage — Teilplan 05: Schulmanager-Import

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax
> for tracking. Setzt den Rahmen `2026-11-13-00-uebersicht.md` voraus (insbesondere Abstimmung Punkte 14 und 15).
> **Überarbeitet 2026-11-14:** Der Koordinator hält einen `DataStore` und entsteht deshalb je Datenort innerhalb von
> `DataScopedRoot` (Teilplan 08) – über `SourceCoordinatorHolder`, den auch die Hintergrund-Aktualisierung nutzt.

**Goal:** Den Stundenplan samt Zeitraster, Vertretungen und Ausfällen aus Schulmanager Online übernehmen –
hinter einer gemeinsamen Schnittstelle für Stundenplan-Quellen, mit Zugangsdaten nur im Schlüsselbund,
Abfrage einmal je Morgen und auf Knopfdruck, Import-Abgleich mit Vorschau und ohne Teilimport.

**Architecture:** Alles, was sich ohne Netz und ohne Schlüsselbund prüfen lässt – Protokoll
`TimetableSource`, Auswerten der Antworten, Ableiten des Wochenplans mit A/B-Wochen, Abweichungen,
Übernahme, Abfrage-Regeln –, liegt in `FrontstageCore` und wird mit erfundenen JSON-Beispielen getestet.
Die App enthält nur den dünnen Rest: HTTP-Aufrufe, Passwort-Hash (CommonCrypto), Schlüsselbund, den
Koordinator, die Hintergrund-Aktualisierung und drei Oberflächen. **Aufgabe 1 ist ein Prüfschritt mit einem
echten Lehrerkonto (Q-16); scheitert er, endet dieser Teilplan dort.**

**Tech Stack:** Swift 6, Foundation (`URLSession`, `JSONSerialization`, `JSONDecoder`), Security (Schlüsselbund),
CommonCrypto (PBKDF2), BackgroundTasks + SwiftUI `.backgroundTask(.appRefresh(_:))` (nur iPadOS), Swift Testing.

**Spec:** `docs/PRD.md` (FR-2, FR-2.2, FR-1.2 letzter Satz, FR-13.1, NFR-2, NFR-4, RISK-1, Q-16; AK-3, AK-20,
AK-21, AK-41), `docs/adr/0004-schulmanager-als-austauschbarer-importbaustein.md`, `docs/ARCHITECTURE.md`
(Area stundenplan-quellen, Area daten), `docs/adr/0002`, `0005`, `0009`, `0012` (Datenort – nur für den Lebenszyklus des Koordinators); Mockups `mockup/einrichten.html`
(`#quelle`, `#abgleich`) und `mockup/tagesansicht.html` (Kopfzeile „Stand“) nur als Veranschaulichung.

## Global Constraints

Es gelten **alle** Zeilen aus `2026-11-13-00-uebersicht.md`, Abschnitt „Global Constraints“. Teilplan-eigen:

- **Einziger Fremd-Host:** `https://login.schulmanager-online.de` (NFR-2, AK-18). Keine weitere Adresse, kein
  Abruf von Webseiten oder Skripten des Anbieters.
- **Abfrage-Häufigkeit (ADR-0004, RISK-1):** automatisch höchstens bis zum ersten Erfolg je Kalendertag und
  höchstens 3 automatische Versuche je Tag mit ≥ 30 min Abstand; auf Knopfdruck mit ≥ 60 s Abstand.
- **Kein Teilimport:** Entweder alle Teilantworten eines Imports sind gültig, oder es wird nichts geschrieben.
- **Zugangsdaten:** nur Schlüsselbund, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`,
  `kSecAttrSynchronizable = false`, `kSecUseDataProtectionKeychain = true`. Passwort und Sitzungs-Token
  (JWT) erscheinen nie in `print`/`Logger`, `UserDefaults`, Dateien oder SwiftData. Der JWT lebt nur im
  Speicher eines Imports.
- **Kein Kaufbezug (FR-13.1):** Kein Code unter `Frontstage/TimetableSources/` und keine der drei
  Oberflächen dieses Teilplans fragt `Unlock` ab.
- **Kennzeichnung (FR-13.1):** Wo die Quelle eingerichtet wird, steht sichtbar, dass die Anbindung
  inoffiziell ist und ohne Gewähr erfolgt.
- **Belegte Schnittstelle, keine erfundene:** Endpunkte und Feldnamen stammen aus der Quellenliste unten;
  was dort nicht belegt ist, kommt aus der Befundtabelle von Aufgabe 1 und nirgendwo sonst her.

### Quellen zur inoffiziellen Schnittstelle (gelesen 2026-11-13)

| Quelle | Belegt dort | Kontotyp |
|---|---|---|
| `rwunsch/schulmanager-online-hass` (MIT), `custom_components/schulmanager_online/const.py`, `api.py` | Basis `https://login.schulmanager-online.de`; `POST /api/get-salt`, `POST /api/login`, `POST /api/calls`; Salt-Body `emailOrUsername`, `mobileApp`, `institutionId`; Login-Body zusätzlich `password`, `hash`; Hash PBKDF2-SHA512, 99 999 Runden, 512 Byte, Salz als UTF-8, Ausgabe hex (1024 Zeichen); Token aus `jwt`, Kopfzeile `Authorization: Bearer <jwt>`, Lebensdauer ca. 1 h; Calls-Body `{"bundleVersion": …, "requests": [{"moduleName", "endpointName", "parameters"}]}`; Antwort `results[i].status`, `results[i].data`; Login-Antwort mit `multipleAccounts` statt `jwt` bei mehreren Schulen | Eltern, Schüler |
| dieselbe, `documentation/Schedules_API_Documentation.md` | `schedules/get-actual-lessons` mit `parameters.student`, `start`, `end` (`YYYY-MM-DD`); Element: `date`, `classHour.number`, `type` ∈ `regularLesson`, `cancelledLesson`, `changedLesson`, `event`; `actualLesson` und `originalLessons[]` mit `subject.name`/`abbreviation`, `teachers[].id`, `classes[].name`, `studentGroups[].name`; `isCancelled`, `isSubstitution`, `isNew`; `schedules/get-class-hours` mit `parameters.classId`, Element `number`, `from`, `until` (`HH:MM:SS`) | Eltern, Schüler |
| dieselbe, `documentation/Authentication_Guide.md` | Salt-Pfad dort als `/api/salt` (Widerspruch zu `const.py` → Prüfschritt 1.3); Salt-Antwort als blanker JSON-String oder `{"salt": …}` | Eltern |
| dieselbe, `test-scripts/standalone_api.py` | Kontoobjekt in `user.associatedStudent` bzw. `user.associatedParents[].student` | Eltern, Schüler |
| `codeberg.org/Benkralex/Schulmanager-API` (Fork von `SchmueI/Schulmanager-API`) | Warnung: „exzessives Abrufen kann schwerwiegende Folgen haben“, Empfehlung, Schulmanager Online GmbH vorab zu kontaktieren, beschreibenden User-Agent setzen | – (Browser-Automatisierung) |

**Nicht belegt für Lehrerkonten:** wo das Lehrer-Objekt in der Login-Antwort steht, welcher Parameter
`get-actual-lessons` den Plan einer Lehrkraft liefert, wie `get-class-hours` ohne `classId` gefragt wird,
ob Vertretungen im Lehrerplan erscheinen, und ob ein fester `bundleVersion`-Wert genügt. Genau das klärt
Aufgabe 1.

### Apple-Schnittstellen (Quelle)

- `BackgroundTask.appRefresh(_:)` – iOS/iPadOS 16+, **nicht macOS** (developer.apple.com, Seite
  `swiftui/backgroundtask/apprefresh(_:)`, JSON-Daten gelesen 2026-11-13). `BGTaskScheduler`,
  `BGAppRefreshTaskRequest` – iOS/iPadOS 13+, Mac Catalyst, **nicht macOS** (ebenda). Keine Zusage für
  eine Uhrzeit; maßgeblich bleibt der Abruf beim ersten Öffnen (ADR-0004).
- `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` – „empfohlen für Einträge, die Hintergrund-Apps
  brauchen“, wandert nicht auf ein neues Gerät; `kSecUseDataProtectionKeychain` – macOS verhält sich wie iOS,
  auf anderen Plattformen ignoriert (developer.apple.com, Security, gelesen 2026-11-13).
- `CCKeyDerivationPBKDF(kCCPBKDF2, …, kCCPRFHmacAlgSHA512, …)` – Header `CommonCrypto/CommonKeyDerivation.h`;
  CryptoKit hat kein PBKDF2. Testwert unten mit zwei unabhängigen Umsetzungen (.NET `Rfc2898DeriveBytes`,
  Node `crypto.pbkdf2Sync`) gerechnet; beim ersten CI-Lauf belegt.

## Review Focus

1. **Das iPad wird über Nacht nicht beendet, nur angehalten.** „Erstes Öffnen am Tag“ ist der Wechsel der
   Szene nach `.active`, nicht der App-Start – sonst kommt AK-21 nie. → Aufgabe 6
   (`activationOnNewDayTriggersFetch`), Aufgabe 9 (`activationTriggersFetchOncePerDay`).
2. **Ferien oder ein Feiertag im Abfragezeitraum** lassen eine Woche ganz oder teilweise leer; ohne Regel
   entstünden falsche A/B-Wochen oder ein geleerter Stundenplan. → Aufgabe 4
   (`holidayWeekIsSkipped`, `singleMissingWeekdayIsNotAVariant`, `noLessonsInRangeLeavesTimetableAlone`).
3. **Netz bricht mitten im Import ab / eine Teilantwort hat Status ≠ 200** – nichts darf halb geschrieben
   werden. → Aufgabe 3 (`nonOkSubResultThrows`), Aufgabe 9 (`failedFetchLeavesEverythingUntouched`).
4. **Passwort oder JWT landen in `UserDefaults`, der Vorschau-Datei oder iCloud.** → Aufgabe 7
   (`credentialsAreDeviceOnlyAndNotSynchronizable`), Aufgabe 9 (`persistedStateNeverContainsSecrets`).
5. **Mehrfaches Tippen auf „Aktualisieren“ und wiederholtes Aktivieren** fragen den Anbieter dauernd ab
   (Kontosperre, RISK-1). → Aufgabe 6 (`userRequestIsDebounced`, `automaticAttemptsAreCappedPerDay`).

---

## Dateien

**Kern** – `Packages/FrontstageCore/Sources/FrontstageCore/TimetableSources/`

| Datei | Verantwortung |
|---|---|
| `TimetableSource.swift` | Protokoll, `TimetableSourceKind`, `TimetableSourceError`, `SourceChange`, `SourceSnapshot`, `TimetableDerivationOutcome`, `DerivedTimetable`, `ManualTimetableSource` |
| `JSONValue.swift` | rohe JSON-Werte (Kontoobjekt unverändert weiterreichen) |
| `SchulmanagerAPIShape.swift` | die in Aufgabe 1 festgestellten Pfade und Schlüssel |
| `SchulmanagerRequestBuilder.swift` | Request-Bodies für Salt, Login, Calls |
| `SchulmanagerResponseParser.swift` | Antworten → `SchulmanagerLesson`, `BellSchedule`, Login-Ergebnis |
| `SchulmanagerTimetableDeriver.swift` | datierte Stunden → Wochenplan mit A/B |
| `SchulmanagerChangeExtractor.swift` | datierte Stunden → `SourceChange` |
| `SourceChangeResolver.swift`, `ScheduleChangeMerger.swift`, `ImportApplier.swift` | Abweichungen zuordnen und ersetzen; Vorschau übernehmen |
| `SourceStatus.swift`, `MorningRefreshPolicy.swift` | Stand, Fehlzähler, wann abgefragt wird |

Tests: `Packages/FrontstageCore/Tests/FrontstageCoreTests/TimetableSources/` (eine Testdatei je Quelldatei
mit Logik, plus `SchulmanagerFixtures.swift` mit den erfundenen JSON-Beispielen als `"""`-Literale – keine
Paket-Ressourcen, damit `Package.swift` aus Teilplan 01 unberührt bleibt).

**App** – `Frontstage/TimetableSources/`: `CredentialStore.swift`, `KeychainCredentialStore.swift`,
`SchulmanagerPasswordHash.swift`, `HTTPTransport.swift`, `SchulmanagerTimetableSource.swift`,
`SourceStatusStore.swift`, `PendingImportStore.swift`, `TimetableRepository.swift` (Protokoll und
`extension DataStore: TimetableRepository`), `TimetableSourceCoordinator.swift`, `SourceCoordinatorHolder.swift` (Koordinator je Datenort, Aufgabe 10), `MorningRefresh.swift`.
Oberfläche (eigenständige Ansichten; Teilplan 04 kommt nach diesem Teilplan und hängt sie in Einrichten und
Tagesansicht ein – dieser Teilplan ändert keine Dateien von 04): `Frontstage/UI/Setup/TimetableSourceSettingsView.swift`,
`Frontstage/UI/Setup/ImportPreviewView.swift`, `Frontstage/UI/DayView/SourceStatusBar.swift`.
Tests: `FrontstageTests/TimetableSources/`. Geändert: `project.yml`, `Frontstage/Resources/Localizable.xcstrings`.

**Doku** (nur Aufgabe 1): `docs/research/schulmanager-lehrerkonto.md` (neu), `docs/PRD.md` (Q-16),
`docs/adr/0004-schulmanager-als-austauschbarer-importbaustein.md` (More Information).

---

### Aufgabe 1: Prüfschritt Q-16 mit einem echten Lehrerkonto (Stopp-Tor)

Diese Aufgabe führt **ein Mensch** aus: Andreas mit seinem **eigenen Lehrerkonto**, das dafür bereitsteht
(Nutzerentscheidung 2026-11-13). Zugangsdaten werden **nur lokal** im Browser bzw. am Gerät eingegeben – nie ins
Repo, in diesen Plan, in Notizen, Sitzungsnotizen oder Befundtabellen. Ein Agent bereitet nur die Notiz vor und
trägt das (anonymisierte) Ergebnis ein. Kein Code, kein CI.

**Files:**
- Create: `docs/research/schulmanager-lehrerkonto.md`
- Modify: `docs/PRD.md` (Zeile Q-16), `docs/adr/0004-…md` (Abschnitt More Information), diese Plandatei (Befundtabelle)

**Interfaces:**
- Produces: die ausgefüllte **Befundtabelle** unten; Aufgabe 3 übernimmt sie wörtlich in `SchulmanagerAPIShape.recorded`.

- [ ] **Schritt 1.1: Mitschnitt am Desktop-Browser.** Mit dem Lehrerkonto unter
  `https://login.schulmanager-online.de` anmelden, Entwicklerwerkzeuge → Netzwerk, Filter `api`. Dann
  nacheinander: Stundenplan dieser Woche, nächste Woche, eine Woche mit bekannter Vertretung oder bekanntem
  Ausfall öffnen. **Nur Feldnamen und Struktur notieren, alle Werte (Namen, Kürzel, IDs, Räume, Klassen) durch
  Platzhalter ersetzen** (CLAUDE.md, Datenhygiene); keine Mitschnitt-Datei (`.har`) ins Repo.
- [ ] **Schritt 1.2: Befundtabelle ausfüllen.**

  | # | Frage | Befund (ausfüllen) |
  |---|---|---|
  | B1 | Pfad zum Objekt der Lehrkraft in der Antwort von `/api/login` (bei Eltern `user.associatedParents[].student`) | |
  | B2 | Pfad zur ID der Lehrkraft in diesem Objekt | |
  | B3 | `moduleName`/`endpointName` des Stundenplan-Aufrufs der Weboberfläche für das Lehrerkonto | |
  | B4 | Schlüssel in `parameters`, der das Lehrer-Objekt trägt (bei Schülern `student`), und ob das ganze Objekt oder nur die ID übergeben wird | |
  | B5 | Haben die Elemente die Form aus der Quellenliste (`date`, `classHour.number`, `type`, `actualLesson`, `originalLessons`, `isCancelled`, `isSubstitution`)? Ist `classHour.number` Zahl oder Text? | |
  | B6 | Erscheint eine Vertretung, die die Lehrkraft übernimmt, als `changedLesson` mit ihrer ID in `actualLesson.teachers`? | |
  | B7 | Erscheint eine eigene Stunde, die ausfällt, als `cancelledLesson` mit ihrer ID in `originalLessons[].teachers`? Erscheint eine eigene Stunde, die jemand anderes vertritt? Wie? | |
  | B8 | Aufruf und `parameters` für die Stundenzeiten (`get-class-hours`?) bei einem Lehrerkonto; Zeitformat von `from`/`until` | |
  | B9 | Salt-Pfad: `/api/get-salt` oder `/api/salt`? Antwort blanker String oder `{"salt": …}`? | |
  | B10 | Wert von `bundleVersion` im Mitschnitt; antwortet `/api/calls` auch ohne das Feld bzw. mit einem Wert von vor ≥ 1 Woche mit Status 200? (mit `curl` und dem JWT aus dem Mitschnitt nachstellen, **eine** Abfrage) | |
  | B11 | Liefert die Login-Antwort `multipleAccounts` (Lehrkraft an zwei Schulen)? | |

- [ ] **Schritt 1.3: Tor entscheiden.**
  - **Weiter**, wenn B3/B4 einen Stundenplan der Lehrkraft liefern, B8 Zeiten liefert **und** B6 oder B7
    Vertretungen bzw. Ausfälle zeigt.
  - **Weiter mit Plan-Nachtrag**, wenn B10 zeigt, dass ein fester `bundleVersion` abgelehnt wird: Teilplan
    anhalten, einen Nachtrag „bundleVersion ermitteln“ von einem Menschen beschließen lassen (nicht raten).
  - **Stopp**, wenn kein Stundenplan der Lehrkraft kommt, oder wenn er kommt, aber keine Vertretungen
    (ADR-0004, „Revisit if“). Dann: Ergebnis dokumentieren (Schritt 1.4), Aufgaben 2–15 **nicht** ausführen,
    an Andreas melden: „Q-16 negativ – FR-2/FR-2.2 so nicht erfüllbar; FR-1 bleibt der Weg; ADR-0004 neu
    bewerten.“
- [ ] **Schritt 1.4: Ergebnis dokumentieren.** `docs/research/schulmanager-lehrerkonto.md`: Datum, Methode,
  Befundtabelle (nur Platzhalter-Werte), ein anonymisiertes Beispielelement je `type`. In `docs/PRD.md`:
  `- ~~Q-16~~: … → answered <Datum>: <ja/nein, Kurzbefund>` (CLAUDE.md, Nummernregeln); bei „nein“ zusätzlich
  Zeile unter `## Changes` und RISK-1 ergänzen. In ADR-0004 unter More Information: `- Prüfung Q-16:
  docs/research/schulmanager-lehrerkonto.md`. Diese Doku-Änderungen laufen über einen Pull Request (CLAUDE.md, Pflege).
- [ ] **Schritt 1.5: Commit**

```bash
git add docs/research/schulmanager-lehrerkonto.md docs/PRD.md docs/adr/0004-schulmanager-als-austauschbarer-importbaustein.md docs/superpowers/plans/2026-11-13-05-schulmanager-import.md
git commit -m "docs: record Q-16 check of Schulmanager teacher account"
```

---

### Aufgabe 2: Protokoll `TimetableSource` und gemeinsame Typen (Kern)

**Files:**
- Create: `…/TimetableSources/TimetableSource.swift`, `…/TimetableSources/JSONValue.swift`
- Test: `…/FrontstageCoreTests/TimetableSources/TimetableSourceTests.swift`

**Interfaces:**
- Consumes (Teilplan 01): `CalendarDay` (inkl. `init(_:calendar:)`, `adding(days:)`, `weekday`, `mondayOfWeek`,
  `storageText`), `TimetableEntry`, `Timetable` (inkl. `.empty`), `BellSchedule`, `SchoolClass`, `Subject`,
  `WeekVariant`. Keine eigene Tagesrechnung (Übersicht, Abstimmung Punkt 1).
- Produces:

```swift
/// Art der Stundenplan-Quelle (Glossar: Stundenplan-Quelle). Liegt im Kern, damit 02 den Rohwert speichern
/// (TimetableRecord.sourceKindRaw) und 04 ihn anzeigen kann (Übersicht, Abstimmung Punkt 3).
/// WebUntis kommt später als weiterer Fall (FR-2.1).
public enum TimetableSourceKind: String, Codable, Sendable, CaseIterable { case manual, schulmanager }

public enum TimetableSourceError: Error, Equatable, Codable, Sendable {
  case notConfigured, invalidCredentials, multipleSchoolsUnsupported, offline
  case server(status: Int)
  case unexpectedResponse(String)   // Text nur zur Diagnose, nie mit Zugangsdaten
}

/// Abweichung, wie die Quelle sie meldet – noch ohne Schlüssel der Unterrichtsstunde (ADR-0005).
public enum SourceChange: Hashable, Codable, Sendable {
  case cancelled(date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject)
  case substitute(date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject)
}

public struct DerivedTimetable: Hashable, Codable, Sendable {
  public var entries: [TimetableEntry]; public var weekVariantCount: Int; public var referenceWeekA: CalendarDay?
}
public enum TimetableDerivationOutcome: Hashable, Codable, Sendable {
  case derived(DerivedTimetable)
  case noLessonsInRange          // z. B. Sommerferien: Stundenplan bleibt, wie er ist
  case weekVariantsUndetermined  // nur eine Unterrichtswoche, vorhandener Plan hat A/B
}

public struct SourceSnapshot: Hashable, Codable, Sendable {
  public var kind: TimetableSourceKind
  public var fetchedAt: Date
  public var range: ClosedRange<CalendarDay>
  public var timetable: TimetableDerivationOutcome
  public var bellSchedule: BellSchedule?
  public var changes: [SourceChange]
}

/// Gemeinsame Schnittstelle aller Stundenplan-Quellen (Area stundenplan-quellen, ADR-0004).
public protocol TimetableSource: Sendable {
  var kind: TimetableSourceKind { get }
  /// `nil`: Diese Quelle liefert nichts, der Stundenplan wird in der App gepflegt („von Hand“).
  /// `existing` braucht die Quelle, um A/B-Wochen gleich zu benennen wie der vorhandene Stundenplan.
  func fetch(range: ClosedRange<CalendarDay>, existing: Timetable?, now: Date) async throws -> SourceSnapshot?
}

public struct ManualTimetableSource: TimetableSource { public init() }   // kind = .manual, fetch → nil

public enum JSONValue: Hashable, Codable, Sendable {
  case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null
  public subscript(path: [String]) -> JSONValue? { get }   // Objektpfad, nil bei fehlendem Schlüssel
}
```

- [ ] **Schritt 2.1: Tests schreiben**

```swift
@Test("Quelle „von Hand“ liefert nichts (Area stundenplan-quellen)")
func manualSourceReturnsNil() async throws {
  #expect(try await ManualTimetableSource().fetch(range: d(2026,11,16)...d(2026,12,13), existing: nil, now: .now) == nil)
}
@Test("Stand übersteht Speichern und Laden") func snapshotRoundTripsThroughJSON()   // encode → decode == original, mit .derived, 1 substitute, BellSchedule [1: 7:45–8:30]
@Test func jsonValuePathLookup()   // {"user":{"associatedTeacher":{"id":"T-100"}}}[["user","associatedTeacher","id"]] == .string("T-100"); fehlender Pfad → nil
@Test func sourceKindRawValues()   // TimetableSourceKind.allCases.map(\.rawValue) == ["manual", "schulmanager"] (gespeichert in TimetableRecord.sourceKindRaw)
```
(`d(_:_:_:)` ist ein Test-Helfer für `CalendarDay`.)

- [ ] **Schritt 2.2: Typen umsetzen** wie im Interfaces-Block. `JSONValue` dekodiert über
  `singleValueContainer` in der Reihenfolge null, bool, number, string, array, object.
- [ ] **Schritt 2.3: Diff durchsehen** – nur `import Foundation`; alle Typen `Sendable`; `ClosedRange<CalendarDay>`
  ist `Codable`, weil `CalendarDay` `Codable` ist. Kommentare deutsch.
- [ ] **Schritt 2.4: Commit** `feat(core): add TimetableSource protocol and shared source types`

---

### Aufgabe 3: Schulmanager-Antworten lesen und Anfragen bauen (Kern)

**Files:**
- Create: `…/TimetableSources/SchulmanagerAPIShape.swift`, `SchulmanagerRequestBuilder.swift`, `SchulmanagerResponseParser.swift`
- Test: `…/TimetableSources/SchulmanagerResponseParserTests.swift`, `SchulmanagerRequestBuilderTests.swift`, `SchulmanagerFixtures.swift`

**Interfaces:**
- Consumes: Befundtabelle B1–B5, B8–B11 (Aufgabe 1); `JSONValue`, `TimetableSourceError` (Aufgabe 2).
- Produces:

```swift
public struct SchulmanagerAPIShape: Sendable {
  public var host: String                       // "login.schulmanager-online.de" (belegt)
  public var saltPath: String                   // B9
  public var loginPath: String                  // "/api/login" (belegt)
  public var callsPath: String                  // "/api/calls" (belegt)
  public var teacherObjectPath: [String]        // B1
  public var teacherIDPath: [String]            // B2, relativ zum Lehrer-Objekt
  public var lessonsModule: String, lessonsEndpoint: String   // B3
  public var teacherParameterKey: String        // B4
  public var passesWholeTeacherObject: Bool     // B4
  public var classHoursModule: String, classHoursEndpoint: String  // B8
  public var classHoursParameters: [String: JSONValue]             // B8
  public var bundleVersion: String?             // B10
  public static let recorded: SchulmanagerAPIShape   // Werte wörtlich aus der Befundtabelle
}

public struct SchulmanagerLessonInfo: Hashable, Sendable {
  public var subjectName: String; public var classNames: [String]; public var teacherIDs: [String]
}
public enum SchulmanagerLessonType: String, Sendable { case regularLesson, cancelledLesson, changedLesson, event }
public struct SchulmanagerLesson: Hashable, Sendable {
  public var date: CalendarDay; public var period: Int; public var type: SchulmanagerLessonType
  public var actual: SchulmanagerLessonInfo?; public var originals: [SchulmanagerLessonInfo]
  public var isCancelled: Bool; public var isSubstitution: Bool
}
public struct SchulmanagerLogin: Sendable { public var jwt: String; public var teacherObject: JSONValue; public var teacherID: String }

public enum SchulmanagerRequestBuilder {
  public static func saltBody(username: String) throws -> Data
  public static func loginBody(username: String, password: String, hash: String) throws -> Data
  /// Ein POST mit zwei Teilaufrufen: [0] Stunden im Zeitraum, [1] Stundenzeiten.
  public static func callsBody(shape: SchulmanagerAPIShape, login: SchulmanagerLogin, range: ClosedRange<CalendarDay>) throws -> Data
}
public enum SchulmanagerResponseParser {
  public static func salt(from data: Data) throws -> String                    // blanker String oder {"salt": …}
  public static func login(from data: Data, shape: SchulmanagerAPIShape) throws -> SchulmanagerLogin
  public static func lessons(fromCalls data: Data, at index: Int) throws -> [SchulmanagerLesson]
  public static func bellSchedule(fromCalls data: Data, at index: Int) throws -> BellSchedule
}
```

Regeln, die Signatur und Tests nicht allein festlegen:
- Fach: `subject.name`, wenn nicht leer, sonst `subject.abbreviation`; beides leer → `unexpectedResponse`.
- Klasse: `classes[].name`; ist die Liste leer, `studentGroups[].name`; mehrere Namen sortiert mit `/` verbunden (`"8a/8b"`).
- `classHour.number` als Zahl **oder** Text annehmen (B5).
- Unbekannter `type`, fehlendes Pflichtfeld, `results[index].status != 200` oder `results` kürzer als `index+1`
  → `TimetableSourceError.unexpectedResponse` (kein Teilimport). Login ohne `jwt`, aber mit `multipleAccounts`
  → `.multipleSchoolsUnsupported`.
- Zeiten `"HH:MM:SS"` oder `"HH:MM"`; anderes → `unexpectedResponse`.
- Login-Body: `emailOrUsername`, `password`, `hash`, `mobileApp: false`, `institutionId: null`. Calls-Body:
  `bundleVersion` nur, wenn `shape.bundleVersion != nil`; `start`/`end` als `YYYY-MM-DD`.

**Erfundene Beispieldaten** (`SchulmanagerFixtures.swift`): Lehrkraft-ID `"T-100"`, fremde Lehrkraft `"T-200"`,
Namen leer bzw. `"XY"`; Klassen `7a`, `8a`, `8b`, `9c`, `6c`; Fächer `Deutsch`, `Englisch`, `Mathematik`.
Ein Element hat diese Form (Werte je Fall laut Tabelle der Tests):

```json
{"date":"2026-11-17","classHour":{"id":"h3","number":"3"},"type":"changedLesson",
 "actualLesson":{"subject":{"name":"Mathematik","abbreviation":"M"},"teachers":[{"id":"T-100","abbreviation":"XY"}],"classes":[{"id":"c6","name":"6c"}],"studentGroups":[]},
 "originalLessons":[{"subject":{"name":"Mathematik","abbreviation":"M"},"teachers":[{"id":"T-200","abbreviation":"ZZ"}],"classes":[{"id":"c6","name":"6c"}],"studentGroups":[]}],
 "isCancelled":false,"isSubstitution":true,"isNew":false}
```
Weicht B5 davon ab, werden Fixture und Regeln **vor** dieser Aufgabe an den Befund angepasst.

- [ ] **Schritt 3.1: Tests schreiben**

```swift
@Test func saltAcceptsBareStringAndObject()        // "\"beispielsalz\"" und {"salt":"beispielsalz"} → "beispielsalz"
@Test func loginExtractsJwtAndTeacher()            // jwt == "jwt-beispiel", teacherID == "T-100"
@Test func loginWithMultipleAccountsIsUnsupported() // throws .multipleSchoolsUnsupported
@Test func parsesSubstitutionElement()             // obiges Element → period 3, type .changedLesson, actual.classNames == ["6c"], originals[0].teacherIDs == ["T-200"]
@Test func periodNumberAsIntOrString()             // "number": 3 und "number": "3" → 3
@Test func unknownLessonTypeThrows()               // "type":"somethingNew" → .unexpectedResponse
@Test func nonOkSubResultThrows()                  // results[0].status == 500 → .unexpectedResponse
@Test func classFallsBackToStudentGroup()          // classes [] , studentGroups [{"name":"8b"}] → ["8b"]
@Test("Zeitraster aus der Quelle übernehmen (FR-1.2, Werte aus AK-42)")
func parsesClassHours()                            // [{1,"07:45:00","08:30:00"},{2,"08:35:00","09:20:00"}] → periods[2] == 8:35...9:20, periods.count == 2
@Test func malformedTimeThrows()                   // "8.35" → .unexpectedResponse
@Test func callsBodyHasTwoRequestsAndRange()       // requests.count == 2; requests[0].parameters.start == "2026-11-16", end == "2026-12-13"; ohne bundleVersion kein Schlüssel "bundleVersion"
@Test func loginBodyFields()                       // mobileApp == false, institutionId == null, hash übernommen
```
- [ ] **Schritt 3.2: Umsetzen** – Dekodieren über `JSONDecoder` mit privaten `Decodable`-Hilfstypen (Felder
  optional, Prüfung danach), Bodies über `JSONSerialization` aus `JSONValue`. `SchulmanagerAPIShape.recorded`
  mit den Werten der Befundtabelle; jeder Wert mit Kommentar `// Befund Bn, <Datum>`.
- [ ] **Schritt 3.3: Diff durchsehen** – keine Zugangsdaten in Fehlertexten von `unexpectedResponse`; keine
  Adresse außer `host`.
- [ ] **Schritt 3.4: Commit** `feat(core): parse Schulmanager responses and build requests`

---

### Aufgabe 4: Wochenplan mit A/B-Wochen ableiten, Abweichungen erkennen (Kern)

**Files:**
- Create: `…/TimetableSources/SchulmanagerTimetableDeriver.swift`, `SchulmanagerChangeExtractor.swift`
- Test: `…/TimetableSources/SchulmanagerTimetableDeriverTests.swift`, `SchulmanagerChangeExtractorTests.swift`

**Interfaces:**
- Consumes: `SchulmanagerLesson` (Aufgabe 3), `TimetableCalculator.weekVariant(for:timetable:)` (Teilplan 01).
- Produces:

```swift
public enum SchulmanagerTimetableDeriver {
  public static func derive(lessons: [SchulmanagerLesson], teacherID: String, existing: Timetable?) -> TimetableDerivationOutcome
}
public enum SchulmanagerChangeExtractor {
  public static func changes(in lessons: [SchulmanagerLesson], teacherID: String) -> [SourceChange]
}
```

**Algorithmus `derive`** (eigene Stunde = `teacherIDs` enthält `teacherID`):
1. Geplante eigene Stunden je Element: `regularLesson` → `actual`; `cancelledLesson`/`changedLesson` →
   `originals`; `event` → keine. Nur eigene; je Stunde Tripel (Stunde, Klasse, Fach) am Datum.
2. Nach Woche gruppieren (`CalendarDay.mondayOfWeek`, Teilplan 01). Eine Woche ist **nutzbar**, wenn sie ≥ 1 geplante Stunde hat; ein
   Wochentag zählt in einer Woche nur, wenn er dort ≥ 1 geplante Stunde hat (Feiertag ≠ Planunterschied).
3. Erstes Paar unmittelbar aufeinanderfolgender nutzbarer Wochen (W1, W2 = W1 + 7 Tage). Gibt es keins: die
   erste nutzbare Woche allein. Gibt es keine → `.noLessonsInRange`.
4. Nur eine Woche: hat `existing` zwei Wochenvarianten → `.weekVariantsUndetermined`; sonst alle Tripel mit
   `weekVariant: nil`, `weekVariantCount: 1`, `referenceWeekA: existing?.referenceWeekA`.
5. Paar: je Wochentag d. Zählt d nur in einer Woche → deren Tripel ohne Variante. Sonst: S1 ∩ S2 → ohne
   Variante; S1 − S2 → Variante v(W1); S2 − S1 → Variante v(W2).
6. v(W): hat `existing` zwei Varianten → `TimetableCalculator.weekVariant(for: W, timetable: existing)`;
   sonst v(W1) = `.a`, v(W2) = `.b`, `referenceWeekA = W1`. Gibt es kein Tripel mit Variante →
   `weekVariantCount: 1`, sonst `2`. Ergebnis sortiert nach Wochentag, Stunde, Variante.

**Regeln `changes`:** `cancelledLesson` → `.cancelled` für jede eigene Stunde in `originals`.
`changedLesson`: ist `actual` eigen und hat ein eigenes Original dieselbe Klasse und dasselbe Fach → keine
Abweichung (nur Raum oder Mitlehrkraft geändert); ist `actual` eigen, sonst → `.substitute(actual)` plus
`.cancelled` je eigenem Original; ist `actual` nicht eigen → `.cancelled` je eigenem Original. `regularLesson`
und `event` → nichts. Ergebnis ohne Doppelte.

- [ ] **Schritt 4.1: Tests schreiben**

```swift
@Test("A/B-Wochen aus zwei Wochen erkennen (Werte aus AK-2)")
func derivesWeekVariants()
// W1 ab 2026-11-16: Mo 1 7a Deutsch, Di 2 8b Englisch; W2 ab 2026-11-23: Mo 1 9c Englisch, Di 2 8b Englisch
// → .derived: [Mo 1 7a Deutsch .a, Mo 1 9c Englisch .b, Di 2 8b Englisch nil], weekVariantCount 2, referenceWeekA 2026-11-16
@Test("Drei Einträge aus der Quelle (AK-3)")
func derivesThreeEntriesFromIdenticalWeeks()
// beide Wochen: Di 2 8b Englisch, Mi 4 7a Deutsch, Fr 2 8a Englisch → 3 Einträge ohne Variante, weekVariantCount 1
@Test func holidayWeekIsSkipped()                 // W1 leer, W2 und W3 gleich → wie W2, weekVariantCount 1
@Test func singleMissingWeekdayIsNotAVariant()    // Mi 2026-11-18 ohne Stunden (Feiertag), sonst gleich → Mi-Einträge aus W2 ohne Variante
@Test func noLessonsInRangeLeavesTimetableAlone() // nur events → .noLessonsInRange
@Test func singleWeekWithExistingABIsUndetermined() // existing.weekVariantCount 2, nur eine nutzbare Woche → .weekVariantsUndetermined
@Test func usesExistingVariantNaming()            // existing: referenceWeekA = 2026-11-23 → W1 (16.11.) ist .b
@Test func foreignLessonsAreIgnored()             // regularLesson mit teacherIDs ["T-200"] → nicht im Plan
@Test("Vertretung 3. Stunde 6c (AK-21)")
func substitutionBecomesSubstitute()              // obiges Fixture-Element → [.substitute(2026-11-17, 3, 6c, Mathematik)]
@Test func cancelledOwnLessonBecomesCancelled()   // cancelledLesson 2026-11-17, 4, 9c Englisch, originals T-100 → [.cancelled(...)]
@Test func roomChangeIsNoChange()                 // changedLesson actual 8b Englisch T-100, original 8b Englisch T-100 → []
@Test func lessonGivenAwayIsCancelled()           // changedLesson actual T-200, original 7a Deutsch T-100 → [.cancelled(7a Deutsch)]
@Test func foreignCancellationIsIgnored()         // cancelledLesson originals nur T-200 → []
```
- [ ] **Schritt 4.2: Umsetzen** nach Algorithmus und Regeln oben.
- [ ] **Schritt 4.3: Diff durchsehen** – Sortierung deterministisch (Tests vergleichen Arrays).
- [ ] **Schritt 4.4: Commit** `feat(core): derive weekly timetable and changes from Schulmanager lessons`

---

### Aufgabe 5: Abweichungen zuordnen und ersetzen, Vorschau übernehmen (Kern)

**Files:**
- Create: `…/TimetableSources/SourceChangeResolver.swift`, `ScheduleChangeMerger.swift`, `ImportApplier.swift`
- Test: `…/TimetableSources/ImportApplyTests.swift`

**Interfaces:**
- Consumes (Teilplan 01): `TimetableCalculator.lessons(on:timetable:nonTeachingPeriods:changes:)`, `ScheduleChange`,
  `Origin`, `LessonKey`, `ImportDiff`, `ImportDiffer.compare(existing:manuallyEdited:imported:)`.
- Produces:

```swift
public enum SourceChangeResolver {
  /// Ausfall → Schlüssel der berechneten Unterrichtsstunde (gleiche Stunde, Klasse, Fach); ohne Treffer → unmatched.
  /// Vertretungsstunde → immer `.substituteLesson(…, .source)`.
  public static func resolve(_ changes: [SourceChange], timetable: Timetable, nonTeachingPeriods: [NonTeachingPeriod])
    -> (resolved: [ScheduleChange], unmatched: [SourceChange])
}
public enum ScheduleChangeMerger {
  /// Behält alle `.manual`; entfernt `.source` mit Datum in `range`; hängt `new` an. `.source` außerhalb bleibt.
  public static func replacingSourceChanges(in existing: [ScheduleChange], with new: [ScheduleChange], range: ClosedRange<CalendarDay>) -> [ScheduleChange]
}
public struct AppliedTimetable: Hashable, Sendable { public var entries: [TimetableEntry]; public var manuallyEdited: Set<TimetableEntry> }
public enum ImportApplier {
  /// `acceptedFromSource`: Quell-Fassungen aus `diff.manualConflicts`, die die Lehrkraft gewählt hat; alle anderen Konflikte behalten ihre Fassung.
  public static func apply(_ diff: ImportDiff, existing: [TimetableEntry], manuallyEdited: Set<TimetableEntry>, acceptedFromSource: Set<TimetableEntry>) -> AppliedTimetable
}
```
`apply`: Ergebnis = `existing` − `diff.removed` − `changed.old` + `changed.new` + `added`; je Konflikt
(mine, source): source ∈ `acceptedFromSource` → mine durch source ersetzen, sonst mine behalten.
`manuallyEdited` des Ergebnisses = übergebene Menge ∩ Ergebnis.

- [ ] **Schritt 5.1: Tests schreiben**

```swift
@Test("Import übernimmt 3 Einträge, der von Hand angelegte bleibt (AK-3)")
func importKeepsManualEntry()
// existing [Mo 5 8a Englisch] (manuallyEdited), imported = 3 Einträge aus derivesThreeEntriesFromIdenticalWeeks
// diff = ImportDiffer.compare(...); apply(..., acceptedFromSource: []) → 4 Einträge, enthält Mo 5 8a Englisch, manuallyEdited == [Mo 5 8a Englisch]
@Test("Konflikt: eigene Fassung bleibt ohne Wahl (AK-3)")
func conflictKeepsMineByDefault()                // existing Mo 5 8a Englisch (manuell), Quelle Mo 5 8b Englisch → Ergebnis enthält 8a, nicht 8b
@Test func conflictTakesSourceWhenChosen()       // dasselbe, acceptedFromSource [Mo 5 8b Englisch] → 8b, manuallyEdited leer
@Test func resolvesCancellationToLessonKey()     // Di 2026-11-17 4. Stunde 9c Englisch im Plan → .cancellation(LessonKey(2026-11-17, 9c, Englisch, ordinal 1), .source)
@Test func cancellationOnNonTeachingDayIsUnmatched()
@Test("Vertretungsstunde erscheint in der 3. Stunde (AK-21)")
func substituteAppearsInLessons()                // resolve → lessons(on: 2026-11-17, …, changes: resolved) enthält period 3, 6c, isSubstituteLesson == true
@Test func mergerReplacesOnlySourceChangesInRange()
// existing: manual cancellation 17.11., source substitute 17.11., source cancellation 10.11.; new: source cancellation 18.11.; range 16.11.–13.12.
// → manual 17.11. bleibt, source 17.11. weg, source 10.11. bleibt, source 18.11. neu (3 Einträge)
```
- [ ] **Schritt 5.2: Umsetzen.**
- [ ] **Schritt 5.3: Diff durchsehen.**
- [ ] **Schritt 5.4: Commit** `feat(core): resolve source changes and apply import preview`

---

### Aufgabe 6: Stand, Fehlzähler und Abfrage-Regeln (Kern)

**Files:**
- Create: `…/TimetableSources/SourceStatus.swift`, `MorningRefreshPolicy.swift`
- Test: `…/TimetableSources/MorningRefreshPolicyTests.swift`

**Interfaces:**

```swift
public struct SourceStatus: Hashable, Codable, Sendable {
  public var lastSuccessAt: Date?; public var lastAttemptAt: Date?
  public var consecutiveFailures: Int; public var lastError: TimetableSourceError?
  public var automaticAttemptsDay: CalendarDay?; public var automaticAttemptsCount: Int
  public init()
  public func recordingAttempt(_ trigger: RefreshTrigger, at: Date, calendar: Calendar) -> SourceStatus
  public func recordingSuccess(at: Date) -> SourceStatus       // consecutiveFailures = 0, lastError = nil
  public func recordingFailure(_ error: TimetableSourceError, at: Date) -> SourceStatus
  public var suggestsManualMaintenance: Bool { get }           // consecutiveFailures >= 3 (Area stundenplan-quellen)
  public func isStale(now: Date, calendar: Calendar) -> Bool   // kein Erfolg am Kalendertag von `now`
}
public enum RefreshTrigger: String, Codable, Sendable { case appBecameActive, backgroundRefresh, userRequest }
public enum MorningRefreshPolicy {
  public static let automaticAttemptsPerDay = 3
  public static let automaticRetryInterval: TimeInterval = 30 * 60
  public static let userRequestInterval: TimeInterval = 60
  public static func shouldFetch(_ trigger: RefreshTrigger, status: SourceStatus, now: Date, calendar: Calendar) -> Bool
  /// Nächster Tag 05:30 Ortszeit – frühester Beginn der Hintergrund-Aktualisierung (ADR-0004).
  public static func nextBackgroundBeginDate(after now: Date, calendar: Calendar) -> Date
}
```
`shouldFetch`: automatisch (`appBecameActive`, `backgroundRefresh`) ⇔ kein Erfolg heute ∧ automatische
Versuche heute < 3 ∧ (kein Versuch ∨ letzter Versuch ≥ 30 min her). `userRequest` ⇔ kein Versuch ∨ letzter
Versuch ≥ 60 s her.

- [ ] **Schritt 6.1: Tests schreiben** (Kalender `Europe/Berlin`)

```swift
@Test("Erstes Aktivieren am neuen Tag fragt ab (AK-21)")
func activationOnNewDayTriggersFetch()            // lastSuccessAt 2026-11-16 07:28, now 2026-11-17 07:30 → true
@Test func noSecondAutomaticFetchAfterSuccess()    // lastSuccessAt 2026-11-17 07:30, now 2026-11-17 10:00 → false
@Test func automaticRetryWaits30Minutes()          // Fehlversuch 07:30 → 07:45 false, 08:00 true
@Test func automaticAttemptsAreCappedPerDay()      // 3 automatische Fehlversuche heute → false; nächster Tag → true
@Test func userRequestIsDebounced()                // letzter Versuch vor 30 s → false; vor 61 s → true; auch nach Erfolg heute → true
@Test func threeFailuresSuggestManualMaintenance() // 2 → false, 3 → true, danach Erfolg → false
@Test func staleWhenLastSuccessYesterday()         // isStale: gestern 07:28 → true; heute 07:28 → false; nil → true
@Test func nextBackgroundBeginIsNextDayHalfPastFive() // now 2026-11-16 21:00 → 2026-11-17 05:30 Ortszeit
```
- [ ] **Schritt 6.2: Umsetzen.**
- [ ] **Schritt 6.3: Diff durchsehen.**
- [ ] **Schritt 6.4: Commit** `feat(core): add source status and morning refresh policy`

---

### Aufgabe 7: Zugangsdaten im Schlüsselbund und Passwort-Hash (App)

**Files:**
- Create: `Frontstage/TimetableSources/CredentialStore.swift`, `KeychainCredentialStore.swift`, `SchulmanagerPasswordHash.swift`
- Test: `FrontstageTests/TimetableSources/KeychainCredentialStoreTests.swift`, `SchulmanagerPasswordHashTests.swift`

**Interfaces:**

```swift
struct SchulmanagerCredentials: Codable, Equatable, Sendable { var username: String; var password: String }
protocol CredentialStore: Sendable {
  func load() throws -> SchulmanagerCredentials?
  func save(_ credentials: SchulmanagerCredentials) throws   // ersetzt vorhandene
  func delete() throws
}
/// Ein Eintrag `kSecClassGenericPassword`, Dienst `service`, Konto "schulmanager-online",
/// Wert = JSON der Zugangsdaten. Gerätegebunden, nicht synchronisiert (NFR-4).
struct KeychainCredentialStore: CredentialStore { init(service: String = "frontstage.timetable-source") }
enum SchulmanagerPasswordHash {
  /// PBKDF2-HMAC-SHA512, 99 999 Runden, 512 Byte, Salz als UTF-8, Ausgabe Kleinbuchstaben-Hex.
  static func make(password: String, salt: String) -> String
}
```

- [ ] **Schritt 7.1: Tests schreiben**

```swift
@Test("Zugangsdaten nur im Schlüsselbund, gerätegebunden (NFR-4, AK-20)")
func credentialsAreDeviceOnlyAndNotSynchronizable()
// save → SecItemCopyMatching mit kSecReturnAttributes: kSecAttrAccessible == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
// kSecAttrSynchronizable == false; UserDefaults.standard.dictionaryRepresentation() enthält "Beispiel-Passwort-1" nirgends
@Test func saveLoadDeleteRoundTrip()     // save → load == gespeichert; zweites save ersetzt; delete → load == nil
@Test func passwordHashMatchesReferenceVector()
// make(password: "Beispiel-Passwort-1", salt: "beispielsalz"): count == 1024,
// hasPrefix("f82673fd3caf5e8cb13026c51bd8746d"), hasSuffix("ae384c7d9538d1bf999d4da7acd0ff1d")
```
Testdienst `"frontstage.tests.\(UUID())"`, im Test am Ende gelöscht.
- [ ] **Schritt 7.2: Umsetzen** – Abfragen immer mit `kSecUseDataProtectionKeychain: true`; `save` = `SecItemDelete`
  dann `SecItemAdd`; Status ≠ `errSecSuccess`/`errSecItemNotFound` → Fehler mit `OSStatus`. Hash mit
  `CCKeyDerivationPBKDF` (Swift-Hinweis: C-Funktion, Puffer über `withUnsafeBytes`/`withUnsafeMutableBytes`).
- [ ] **Schritt 7.3: Diff durchsehen** – kein `print`/`Logger` mit Passwort; `import CommonCrypto` und
  `import Security` nur in diesen Dateien.
- [ ] **Schritt 7.4: Commit** `feat: store Schulmanager credentials in device-only keychain`

---

### Aufgabe 8: Baustein „Schulmanager Online“ (App, HTTP)

**Files:**
- Create: `Frontstage/TimetableSources/HTTPTransport.swift`, `SchulmanagerTimetableSource.swift`
- Test: `FrontstageTests/TimetableSources/SchulmanagerTimetableSourceTests.swift`

**Interfaces:**
- Consumes: Aufgaben 2–4, 7.
- Produces:

```swift
protocol HTTPTransport: Sendable { func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) }
struct URLSessionTransport: HTTPTransport { init(session: URLSession = .shared) }
struct SchulmanagerTimetableSource: TimetableSource {
  init(credentials: any CredentialStore, transport: any HTTPTransport = URLSessionTransport(), shape: SchulmanagerAPIShape = .recorded)
  // kind = .schulmanager
  // fetch: Zugangsdaten laden (fehlen → .notConfigured) → Salt → Hash → Login → ein Calls-POST →
  // SourceSnapshot(range, timetable: derive(...), bellSchedule, changes) – oder Fehler, nie halb.
}
```
Jede Anfrage: `POST`, `Content-Type: application/json`, `User-Agent: Frontstage/<CFBundleShortVersionString>
(inoffizielle Anbindung)` (Empfehlung der Codeberg-Quelle), Zeitlimit 15 s. Fehlerabbildung: Login-Status 401 →
`.invalidCredentials`; `URLError` `.notConnectedToInternet`, `.networkConnectionLost`, `.timedOut`,
`.cannotFindHost` → `.offline`; anderer Status ≠ 2xx → `.server(status:)`; Auswertfehler weiterreichen.
Zeitraum, den der Koordinator übergibt: heute bis heute + 27 Tage.

- [ ] **Schritt 8.1: Tests schreiben** (`FakeTransport` liefert vorbereitete Antworten der Reihe nach und merkt sich die Anfragen)

```swift
@Test func loginSendsHashAndUsesBearerToken()
// Salt "\"beispielsalz\"", Login {"jwt":"jwt-beispiel","user":…}: Login-Body hash hasPrefix "f82673fd…"; Calls-Anfrage Authorization == "Bearer jwt-beispiel"
@Test("Nur Schulmanager wird angesprochen (NFR-2, AK-18)")
func allRequestsGoOnlyToSchulmanagerHost()     // alle URLs: scheme "https", host "login.schulmanager-online.de"; genau 3 Anfragen
@Test("Import aus dem Testkonto (AK-3)")
func fetchProducesSnapshotWithThreeEntries()   // Fixture AK-3 → timetable == .derived mit 3 Einträgen; bellSchedule.periods.count == 2
@Test func missingCredentialsIsNotConfigured()   // load → nil → .notConfigured, 0 Anfragen
@Test func wrongPasswordIsInvalidCredentials()   // Login 401 → .invalidCredentials, keine Calls-Anfrage
@Test func offlineIsOffline()                    // URLError(.notConnectedToInternet) → .offline
@Test func serverErrorIsServer()                 // Calls 503 → .server(status: 503)
```
- [ ] **Schritt 8.2: Umsetzen.**
- [ ] **Schritt 8.3: Diff durchsehen** – Passwort nur im Login-Body; JWT nur als lokale Variable in `fetch`.
- [ ] **Schritt 8.4: Commit** `feat: add Schulmanager Online timetable source`

---

### Aufgabe 9: Koordinator – abfragen, Abweichungen sofort, Stundenplan nach Vorschau (App)

**Files:**
- Create: `Frontstage/TimetableSources/TimetableRepository.swift`, `TimetableSourceCoordinator.swift`, `SourceStatusStore.swift`, `PendingImportStore.swift`
- Test: `FrontstageTests/TimetableSources/TimetableSourceCoordinatorTests.swift`, `TimetableRepositoryTests.swift`

**Interfaces:**
- Consumes: Aufgaben 2–8; von Teilplan 02 die `DataStore`-Methoden `timetable()`, `manuallyEditedEntries()`,
  `nonTeachingPeriods()`, `scheduleChanges()` (Task 6), `timetableSourceRaw()`, `setTimetableSourceRaw(_:)`,
  `sourceFetchedAt()`, `replaceTimetable(entries:manuallyEdited:weekVariantCount:referenceWeekA:bellSchedule:)`,
  `replaceScheduleChanges(_:sourceFetchedAt:)` (Task 6, `DataStore+Sources`) und `makeStore()` (Test-Hilfe).
- Produces:

```swift
/// Schmale Sicht auf die App-Daten (Übersicht, Abstimmung Punkt 4) – ohne SwiftData-Typen nach außen.
/// Signaturen gleich den DataStore-Methoden aus Teilplan 02.
@MainActor protocol TimetableRepository: AnyObject {
  func timetable() throws -> Timetable?
  func manuallyEditedEntries() throws -> Set<TimetableEntry>      // Herkunft .manual oder von Hand geändert (01, Task 8)
  func nonTeachingPeriods() throws -> [NonTeachingPeriod]
  func scheduleChanges() throws -> [ScheduleChange]
  func timetableSourceRaw() throws -> String
  func setTimetableSourceRaw(_ raw: String) throws
  func sourceFetchedAt() throws -> Date?                          // gespiegelt: „Stand“ auch auf dem zweiten Gerät
  /// Schreibt in einem Speichervorgang: Einträge (nicht in manuallyEdited → Herkunft .source), Varianten, Zeitraster.
  func replaceTimetable(entries: [TimetableEntry], manuallyEdited: Set<TimetableEntry>, weekVariantCount: Int, referenceWeekA: CalendarDay?, bellSchedule: BellSchedule?) throws
  /// Ersetzt alle Abweichungen und setzt, wenn nicht nil, den Stand – ein Speichervorgang.
  func replaceScheduleChanges(_ changes: [ScheduleChange], sourceFetchedAt: Date?) throws
}
extension DataStore: TimetableRepository {}          // ruft nur vorhandene DataStore-Methoden (gleiche Signaturen)
extension TimetableRepository {
  /// Unbekannter Rohwert → .manual.
  func timetableSourceKind() throws -> TimetableSourceKind { TimetableSourceKind(rawValue: try timetableSourceRaw()) ?? .manual }
  func setTimetableSourceKind(_ kind: TimetableSourceKind) throws { try setTimetableSourceRaw(kind.rawValue) }
}

struct ImportPreview { var snapshot: SourceSnapshot; var diff: ImportDiff; var bellScheduleChanged: Bool }

@MainActor @Observable final class TimetableSourceCoordinator {
  init(repository: any TimetableRepository, makeSource: @escaping (TimetableSourceKind) -> any TimetableSource,
       statusStore: SourceStatusStore, pendingStore: PendingImportStore, calendar: Calendar = .current, now: @escaping () -> Date = Date.init)
  private(set) var status: SourceStatus
  private(set) var pendingPreview: ImportPreview?
  private(set) var isFetching: Bool
  func refresh(_ trigger: RefreshTrigger) async      // prüft MorningRefreshPolicy; Fehler landen in `status`, nie geworfen
  func applyPendingPreview(acceptedFromSource: Set<TimetableEntry>) throws
  func discardPendingPreview()
  func switchSource(to kind: TimetableSourceKind) throws
}
struct SourceStatusStore { init(defaults: UserDefaults = .standard); func load() -> SourceStatus; func save(_ status: SourceStatus) }   // Schlüssel "timetableSource.status", JSON
struct PendingImportStore { init(directory: URL); func load() -> SourceSnapshot?; func save(_ snapshot: SourceSnapshot?) throws }   // Datei pending-import.json in Application Support/TimetableSources, nur dieses Gerät
```

Ablauf `refresh` (nach erfolgreichem `fetch`; vorher nichts schreiben):
0. Quelle `.manual` → sofort Ende, nichts zählen, nichts schreiben.
1. `status.recordingAttempt` speichern; `fetch` → bei Fehler `recordingFailure`, Ende (nichts sonst geändert).
2. Stundenplan-Teil: `.derived` → `diff = ImportDiffer.compare(existing:manuallyEdited:imported:)`; sind
   `added`, `changed`, `manualConflicts`, `removed` leer und das Zeitraster gleich → nichts zu zeigen; sonst
   `pendingPreview` setzen und speichern (**nicht** übernehmen). `.noLessonsInRange`/`.weekVariantsUndetermined`
   → keine Vorschau.
3. Abweichungen **sofort** (FR-2.2): `resolve` gegen den **aktuellen** Stundenplan, `replacingSourceChanges(range:)`,
   `replaceScheduleChanges(_:sourceFetchedAt:)`; `recordingSuccess`.

`applyPendingPreview`: `ImportApplier.apply` → `replaceTimetable(...)` (Zeitraster aus dem Stand, wenn
geliefert) → Abweichungen des Stands gegen den **neuen** Stundenplan erneut auflösen und ersetzen → Vorschau
löschen. `switchSource(to: .manual)`: Quelle setzen, Vorschau löschen, Abweichungen mit Herkunft `.source`
**ab heute** entfernen (Annahme A4), Zugangsdaten bleiben bis „Abmelden“.

- [ ] **Schritt 9.1: Tests schreiben** (Repository = echter `DataStore` im Speicher über `makeStore()` aus Teilplan 02 – prüft zugleich die Erweiterung `DataStore: TimetableRepository`; für `failedFetchLeavesEverythingUntouched` zusätzlich ein `CountingRepository`, das Schreibaufrufe zählt und an den `DataStore` weiterreicht; `FakeSource` mit vorbereitetem Ergebnis, `UserDefaults(suiteName:)` und temporärer Ordner)

```swift
@Test("Quelle wird als Rohwert gespeichert und als TimetableSourceKind gelesen")
func repositoryMapsSourceKind()   // DataStore ohne Stundenplan → timetableSourceKind() == .manual; setTimetableSourceKind(.schulmanager) → .schulmanager
```

```swift
@Test("Kein Teilimport: Fehler lässt alles unberührt (Area stundenplan-quellen)")
func failedFetchLeavesEverythingUntouched()   // FakeSource wirft .offline → Repository: 0 Schreibaufrufe; status.consecutiveFailures == 1; sourceFetchedAt unverändert
@Test func threeFailuresSuggestManualMaintenance()  // 3× .userRequest mit 61 s Abstand, je .offline → status.suggestsManualMaintenance
@Test("Vertretung steht ohne Rückfrage in der 3. Stunde (AK-21)")
func sourceChangesAreAppliedWithoutPreview()  // Stand mit .substitute(17.11., 3, 6c, Mathematik), gleicher Plan → pendingPreview == nil; lessons(on: 17.11.) enthält period 3 6c isSubstituteLesson; sourceFetchedAt == now
@Test func timetableDifferencesWaitForPreview()  // Stand mit 3 Einträgen, Repository leer → pendingPreview != nil; timetable() unverändert
@Test("Übernahme behält den von Hand angelegten Eintrag (AK-3)")
func applyingPreviewKeepsManualEntry()        // Repository [Mo 5 8a Englisch manuell] + Stand AK-3 → apply(acceptedFromSource: []) → 4 Einträge, Mo 5 8a Englisch weiter in manuallyEditedEntries
@Test func manualSourceNeverFetches()         // kind .manual → Repository unverändert, status == SourceStatus()
@Test func activationTriggersFetchOncePerDay() // 2× .appBecameActive am selben Tag nach Erfolg → FakeSource 1× aufgerufen
@Test func persistedStateNeverContainsSecrets() // nach Import: Inhalt pending-import.json und UserDefaults-Suite enthalten weder "Beispiel-Passwort-1" noch "jwt-beispiel"
@Test func switchingToManualDropsFutureSourceChanges() // source-Abweichungen 10.11. und 18.11., heute 17.11. → nur 10.11. bleibt
```
Für `manualSourceNeverFetches` gilt: Bei `.manual` wird `MorningRefreshPolicy` gar nicht gefragt und kein
Versuch gezählt; die Zusicherung ist `status == SourceStatus()`.
- [ ] **Schritt 9.2: Umsetzen.** Swift-Hinweis: `@Observable` (Observation-Framework) macht gespeicherte
  Eigenschaften für SwiftUI beobachtbar; `@MainActor` hält alle Zugriffe auf dem Haupt-Thread, wie es
  SwiftData-Kontexte aus Teilplan 02 verlangen. Der `fetch` selbst läuft außerhalb (`await`).
- [ ] **Schritt 9.3: Diff durchsehen** – kein Pfad schreibt, bevor `fetch` und Auswertung fertig sind; jeder
  `throw` aus dem Repository wird als `status`-Fehler erfasst, nicht verschluckt.
- [ ] **Schritt 9.4: Commit** `feat: coordinate timetable source refresh, preview and changes`

---

### Aufgabe 10: Morgendliche Aktualisierung – Aktivieren und BGAppRefreshTask (App)

**Files:**
- Create: `Frontstage/TimetableSources/MorningRefresh.swift`
- Create: `Frontstage/TimetableSources/SourceCoordinatorHolder.swift`
- Modify: `Frontstage/App/FrontstageApp.swift` (Stand nach 02, 03 und 08 – vorher ganz lesen, nichts entfernen), `project.yml` (Info.plist des iPadOS-Ziels)
- Test: `FrontstageTests/TimetableSources/SourceCoordinatorHolderTests.swift`

Zum Zeitpunkt dieses Teilplans ersetzt Teilplan 08 den Container-Aufbau in `FrontstageApp` durch
`DataLocationController` und `DataScopedRoot` (Übersicht, Abstimmung 15): Alles, was einen `DataStore` hält, entsteht
in der Ansicht in der Closure von `DataScopedRoot` neu, sobald der Datenort wechselt. Der Koordinator hält über
`repository:` einen `DataStore` – er gehört also dorthin. `.backgroundTask` ist aber ein Szenen-Modifikator am
`WindowGroup` und läuft auch, wenn das System die App nur im Hintergrund weckt und keine Ansicht aufbaut; er kann
den Koordinator deshalb nicht aus einer Ansicht holen. Lösung: ein App-weiter `SourceCoordinatorHolder`, der den
Koordinator **je `DataStore`** anlegt und zwischenspeichert. Ansicht und Hintergrundaufgabe fragen ihn mit dem
aktuellen `DataStore` (`dataLocation.store`, Teilplan 08) – beide bekommen dasselbe Objekt, und nach einem Wechsel
entsteht ein neuer Koordinator auf dem neuen Container. Teilplan 04 übernimmt die Ansicht als `ScopedAppContent`.

**Interfaces:**

```swift
/// Hält den Koordinator des aktuellen Datenorts (Übersicht, Abstimmung 15). Neuer DataStore → neuer Koordinator.
@MainActor final class SourceCoordinatorHolder {
  init(makeCoordinator: @escaping @MainActor (DataStore) -> TimetableSourceCoordinator = SourceCoordinatorHolder.live)
  func coordinator(for store: DataStore) -> TimetableSourceCoordinator   // gleicher Store (ObjectIdentifier) → gleiches Objekt
  static func live(_ store: DataStore) -> TimetableSourceCoordinator     // repository: store, makeSource: Manual/Schulmanager, Stores wie Aufgabe 9
}
enum MorningRefresh {
  static let taskIdentifier = "frontstage.timetable-source.morning-refresh"   // fest, unabhängig von der Bundle-ID aus CI
  #if os(iOS)
  static func schedule(after now: Date, calendar: Calendar)   // BGAppRefreshTaskRequest, earliestBeginDate = MorningRefreshPolicy.nextBackgroundBeginDate
  #endif
}
```

- [ ] **Schritt 10.1: `project.yml`** – im iPadOS-Ziel unter `info.properties`:
  `BGTaskSchedulerPermittedIdentifiers: [frontstage.timetable-source.morning-refresh]`,
  `UIBackgroundModes: [fetch]`. macOS-Ziel unverändert.
- [ ] **Schritt 10.2: Test `SourceCoordinatorHolder`** (zwei `DataStore` aus `makeStore()`):
  `@Test("Gleicher DataStore → derselbe Koordinator; neuer DataStore → neuer") func holderCachesPerStore()` und
  `@Test("Nach Wechsel des Datenorts liest der Koordinator den neuen Stundenplan") func coordinatorFollowsStore()`
  (Stundenplan nur im zweiten Store → `holder.coordinator(for: second)` sieht ihn über das Repository). Implementieren:
  ein Eintrag (zuletzt gefragter Store + Koordinator); anderer Store → neu anlegen, alten verwerfen.
- [ ] **Schritt 10.3: `FrontstageApp`** – im `App`-Typ `@State private var sourceCoordinators = SourceCoordinatorHolder()`.
  In der Closure-Ansicht von `DataScopedRoot` (08; in Teilplan 04 `ScopedAppContent`): `let coordinator = sourceCoordinators.coordinator(for: store)`
  per `.environment` an die Ansichten geben; `.onChange(of: scenePhase)`: `.active` → `Task { await coordinator.refresh(.appBecameActive) }`;
  `.background` → `MorningRefresh.schedule(...)` (nur iOS). Am `WindowGroup` (nur `#if os(iOS)`):
  `.backgroundTask(.appRefresh(MorningRefresh.taskIdentifier)) { await sourceCoordinators.coordinator(for: dataLocation.store).refresh(.backgroundRefresh); MorningRefresh.schedule(...) }`
  (Swift-Hinweis: die Closure läuft nicht auf dem Haupt-Actor; der Zugriff auf Halter und Controller braucht `await MainActor.run { … }`).
  Kein Koordinator als `@State` im `App`-Typ.
  Swift-Hinweis: SwiftUI ruft diesen Block auf, wenn das System die Aufgabe startet; die nächste Aufgabe muss
  man selbst wieder anmelden, sonst läuft sie nur einmal. Am Mac genügt das Aktivieren (ADR-0004: maßgeblich ist
  das erste Öffnen).
- [ ] **Schritt 10.4: Diff durchsehen** – Bezeichner in `project.yml` und Code wörtlich gleich; `import BackgroundTasks`
  nur unter `#if os(iOS)`; Koordinator nur über `SourceCoordinatorHolder`. Prüfung der Wirkung: Geräte-Checkliste AK-21.
- [ ] **Schritt 10.5: Commit** `feat: refresh timetable source on activation and in background`

---

### Aufgabe 11: Einrichten → „Stundenplan-Quelle“ (Oberfläche)

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/UI/Setup/TimetableSourceSettingsView.swift`
- Modify: `Frontstage/Resources/Localizable.xcstrings`. Eingehängt wird die Ansicht von Teilplan 04 (Einrichten › „Stundenplan-Quelle“); bis dahin zeigt ein `#Preview` sie.
- Test: `FrontstageTests/TimetableSources/SourceStringsTests.swift`

**Interfaces:**
- Consumes: `TimetableSourceCoordinator`, `CredentialStore`.
- Produces: `struct TimetableSourceSettingsView: View { init() }` (liest den Koordinator aus `@Environment`).

Muss leisten (Mockup `einrichten.html#quelle` zeigt das Was, nicht das Wie): Wahl „von Hand“ / „Schulmanager
Online“ (`switchSource`); Anmeldung mit Benutzername und Passwort (`SecureField`, Speichern erst nach
erfolgreichem Probe-Import: `save` → `refresh(.userRequest)` → bei `.invalidCredentials` wieder `delete`);
Zustand angemeldet/nicht angemeldet, Stand; „Jetzt importieren“; „Abmelden“ (`delete`); Hinweis
Zugangsdaten nur auf diesem Gerät; **Hinweis „inoffizielle Anbindung, ohne Gewähr“** (FR-13.1); Fehlertext je
`TimetableSourceError`. Liegt nach dem Import eine Vorschau vor, öffnet sich `ImportPreviewView` als Sheet.
Kein Kaufangebot, keine `Unlock`-Abfrage.

- [ ] **Schritt 11.1: Skill `apple-design` laden** (Hauptstufe).
- [ ] **Schritt 11.2: Test schreiben**

```swift
@Test("Anbindung als inoffiziell und ohne Gewähr bezeichnet (FR-13.1, AK-41)")
func unofficialNoticeNamesBoth()   // Bundle.main.localizedString(forKey: "timetableSource.unofficialNotice", value: nil, table: nil) enthält "inoffiziell" und "ohne Gewähr"
```
- [ ] **Schritt 11.3: Ansicht bauen** – `Form` mit `Section`s, Systemstandard für Farbe, Abstände, Zustände.
  Texte nur über Schlüssel `timetableSource.*`; Wortlaut ist offen (Platzhalter, unpersönliche Anrede).
- [ ] **Schritt 11.4: Diff durchsehen** – Passwort-Zustand nur in `@State` der Ansicht, nach Speichern geleert.
- [ ] **Schritt 11.5: Commit** `feat(ui): add timetable source settings`

---

### Aufgabe 12: Import-Abgleich mit Vorschau (Oberfläche)

Design-Takt: voll

**Files:**
- Create: `Frontstage/UI/Setup/ImportPreviewView.swift`
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/TimetableSources/ImportPreviewModelTests.swift`

**Interfaces:**

```swift
/// Gruppen der Vorschau in fester Reihenfolge; reine Ableitung aus ImportPreview, testbar ohne Ansicht.
struct ImportPreviewModel: Equatable {
  init(preview: ImportPreview)
  var added: [TimetableEntry]; var changed: [(old: TimetableEntry, new: TimetableEntry)]
  var conflicts: [(mine: TimetableEntry, source: TimetableEntry)]; var removed: [TimetableEntry]
  var bellScheduleChanged: Bool; var fetchedAt: Date
  var acceptedFromSource: Set<TimetableEntry>          // Startwert leer = „Meine Fassung behalten“ (AK-3)
  mutating func choose(source: Bool, for conflict: TimetableEntry)
}
struct ImportPreviewView: View   // „Abbrechen“ → discardPendingPreview, „Übernehmen“ → applyPendingPreview(acceptedFromSource:)
```
(`changed`/`conflicts` als Tupel-Arrays sind nicht automatisch `Equatable`; `==` von Hand über die Elemente.)

- [ ] **Schritt 12.1: Skill `apple-design` laden.**
- [ ] **Schritt 12.2: Tests schreiben**

```swift
@Test("Konflikt startet mit eigener Fassung (AK-3)")
func conflictsDefaultToMine()        // Modell aus Vorschau mit 1 Konflikt → acceptedFromSource.isEmpty
@Test func choosingSourceIsRecorded() // choose(source: true, for: mine) → acceptedFromSource == [source]
@Test func groupsKeepDiffContents()  // 1 added, 1 changed, 1 conflict, 0 removed → Zählungen 1/1/1/0
```
- [ ] **Schritt 12.3: Ansicht bauen** – Sheet mit `NavigationStack`, Gruppen „neu“, „geändert“, „von Hand geändert“
  (je Konflikt Auswahl eigene/Quelle), „entfällt“, Zeitraster geändert; Stand-Zeit oben; leere Gruppen nicht zeigen.
  Systemstandard; offene Kategorien (Zustände, Wortlaut, Dichte) im Abschlussbericht nennen.
- [ ] **Schritt 12.4: Prüfung mit `apple-design` als Prüfer** (voll): Befunde zu offenen Kategorien nicht
  selbst entscheiden, sondern melden.
- [ ] **Schritt 12.5: Diff durchsehen.**
- [ ] **Schritt 12.6: Commit** `feat(ui): add import preview sheet`

---

### Aufgabe 13: Stand der Quelle in der Tagesansicht (Oberfläche)

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/UI/DayView/SourceStatusBar.swift`
- Modify: `Frontstage/Resources/Localizable.xcstrings`. Eingehängt wird die Leiste von Teilplan 04 (Kopf der `DayView`).
- Test: `FrontstageTests/TimetableSources/SourceStatusBarModelTests.swift`

**Interfaces:**

```swift
enum SourceStatusNotice: Equatable { case none, stale, failed(TimetableSourceError), suggestManualMaintenance, previewPending, notSignedIn }
struct SourceStatusBarModel: Equatable {
  /// Vorrang: notSignedIn > suggestManualMaintenance > failed > previewPending > stale > none.
  init(kind: TimetableSourceKind, fetchedAt: Date?, status: SourceStatus, hasPendingPreview: Bool, hasCredentials: Bool, now: Date, calendar: Calendar)
  var isVisible: Bool          // false bei .manual
  var fetchedAt: Date?; var notice: SourceStatusNotice
}
struct SourceStatusBar: View { init() }   // liest TimetableSourceCoordinator aus @Environment; Name der Quelle, „Stand“ mit Uhrzeit (heute) bzw. Wochentag + Uhrzeit, Knopf „Aktualisieren“ → refresh(.userRequest), Hinweis je notice
```

- [ ] **Schritt 13.1: Skill `apple-design` laden.**
- [ ] **Schritt 13.2: Tests schreiben**

```swift
@Test("Tagesansicht zeigt, von wann der Stand ist (AK-21)")
func showsFetchedAt()                   // fetchedAt 2026-11-17 07:30, now 07:31 → fetchedAt gesetzt, notice == .none
@Test func yesterdayIsStale()           // fetchedAt 2026-11-16 07:28, now 2026-11-17 07:35, kein Fehler → .stale
@Test func threeFailuresWin()           // consecutiveFailures 3 → .suggestManualMaintenance
@Test func manualSourceHidesBar()       // kind .manual → isVisible == false
```
- [ ] **Schritt 13.3: Ansicht bauen** – Zustand nie nur über Farbe (DESIGN.md, Fallen): Symbol plus Text.
  Wortlaut offen.
- [ ] **Schritt 13.4: Diff durchsehen.**
- [ ] **Schritt 13.5: Commit** `feat(ui): show timetable source status in day view`

---

### Aufgabe 14: CI-Lauf (workflow_dispatch) und Ergebnis prüfen

**Files:** keine Änderung (bei Fehlern: Korrektur in der betroffenen Aufgabe, eigener Commit).

- [ ] **Schritt 14.1: Branch pushen** und Lauf starten:

```bash
gh workflow run ci.yml --ref <branch>
gh run watch
```
Erwartet: `swift test --package-path Packages/FrontstageCore` und `xcodebuild test` grün; insbesondere
`passwordHashMatchesReferenceVector` (belegt CommonCrypto-Aufruf) und `credentialsAreDeviceOnlyAndNotSynchronizable`
(Schlüsselbund im Simulator).
- [ ] **Schritt 14.2: Bei Rot** – Log mit `gh run view --log-failed` lesen, Ursache mit superpowers:systematic-debugging
  klären, alle Korrekturen sammeln, **ein** weiterer Lauf.
- [ ] **Schritt 14.3: Abschlussbericht** – offene Gestaltungskategorien aus 11–13 je eine Zeile; Abweichungen von
  der Befundtabelle; Stand der Geräte-Checkliste.

---

## Geräte-Checkliste (nach Aufgabe 14, mit TestFlight-Bau aus Teilplan 04)

Ein Mensch mit iPad, Mac und **eigenem Schulmanager-Lehrerkonto**; Ergebnis abhaken und mit Datum in
`docs/research/schulmanager-lehrerkonto.md` nachtragen. Keine Bildschirmfotos mit echten Namen ins Repo.

| AK | Schritte | Ergebnis | ✓ |
|---|---|---|---|
| AK-3 | Am iPad einen Eintrag von Hand anlegen, der im Schulmanager-Plan nicht steht. Quelle Schulmanager einrichten, „Jetzt importieren“, Vorschau „Übernehmen“. | Einträge aus dem Konto stehen im Stundenplan; der von Hand angelegte ist noch da oder stand in der Vorschau als „von Hand geändert“ zur Wahl. | |
| AK-20 | Nach dem Import: am Mac den App-Container (`~/Library/Containers/<Bundle-ID>`) und die Ablage per Volltextsuche nach dem Passwort durchsuchen; am iPad per Xcode → Devices → Download Container dasselbe. | Passwort nur im Schlüsselbund (Schlüsselbundverwaltung am Mac zeigt den Eintrag „frontstage.timetable-source“; der Mac zeigt ihn nur, wenn dort angemeldet wurde). | |
| AK-21 | Abends Vertretung im Konto vorhanden (oder echte Vertretung abwarten); iPad über Nacht gesperrt, App nicht beendet. Um ca. 7:30 entsperren, App öffnen. Zweiter Durchlauf: App vorher beenden. | Vertretung binnen weniger Sekunden in der richtigen Stunde; Kopfzeile zeigt den Stand von heute. Notieren, ob die Hintergrund-Aktualisierung schon vor dem Öffnen lief (Stand vor 7:30). | |
| AK-41 | Frisch geladene App ohne Kauf; Quelle Schulmanager einrichten und importieren. | Import funktioniert ohne Kauf; „inoffiziell“ und „ohne Gewähr“ stehen beim Einrichten. | |
| AK-18 (Teil) | Während eines Imports Netzwerkmitschnitt (z. B. Proxy am Mac). | Nur `login.schulmanager-online.de` (neben Apple). | |
| Offline | WLAN aus, App öffnen; dreimal „Aktualisieren“ mit je > 60 s Abstand. | Letzter Stand bleibt, als alt gekennzeichnet; nach dem dritten Fehlschlag Hinweis auf Pflege von Hand. | |

---

## Produziert für spätere Teilpläne (Zusammenfassung)

- **Kern:** `TimetableSourceKind` (`manual`, `schulmanager`), `TimetableSource`, `SourceSnapshot`, `SourceChange`,
  `SourceStatus`, `RefreshTrigger`, `MorningRefreshPolicy`.
- **App (für Teilplan 04):** `SourceCoordinatorHolder` (`coordinator(for:)`, im `App`-Typ; 04 holt den Koordinator in
  `ScopedAppContent` darüber), `TimetableSourceCoordinator` (`status`, `pendingPreview`, `isFetching`,
  `refresh(_:)`, `applyPendingPreview(acceptedFromSource:)`, `discardPendingPreview()`, `switchSource(to:)`) und
  `TimetableRepository.timetableSourceKind()`; Ansichten `TimetableSourceSettingsView()`, `ImportPreviewView`,
  `SourceStatusBar()` – 04 hängt sie in Einrichten bzw. den Kopf der `DayView` ein.

## Abstimmungsbedarf mit anderen Teilplänen

- Keiner offen (abgeglichen nach Übersicht, Abschnitt „Abstimmung“): Tagesrechnung und `Timetable.empty` aus 01;
  `ImportDiffer`-Regel aus 01 (Punkt 2); Datenzugriff über `TimetableRepository` mit Methoden aus 02; Herkunft und
  Hand-Markierung in 02 (`originRaw`, `isManuallyEdited`); Stand in `TimetableRecord.sourceFetchedAt`;
  Zusammenführen doppelter `.source`-Abweichungen beim Abgleich in 02 (`SyncMerger`, Abweichung nach Wert).
  „Stand“ steht im Glossar (`sourceFetchedAt`). Datenort (08): Koordinator je `DataStore` über `SourceCoordinatorHolder`
  (Übersicht, Abstimmung 15); `SourceStatusStore` und `PendingImportStore` liegen je Gerät und bleiben bei einem Wechsel
  des Datenorts stehen – die Vorschau gilt danach gegen den Stundenplan des neuen Orts (A3).

## Annahmen, die ein Mensch bestätigen sollte

- **A1** ~~Ein Lehrerkonto steht zur Verfügung~~ → bestätigt 2026-11-13: das eigene Konto des Nutzers, Zugangsdaten
  nur lokal. Offen bleibt: Die Nutzung für den Prüfschritt ist mit der Schule vereinbar; der Codeberg-Hinweis, den Anbieter vorab zu kontaktieren, wird
  zusammen mit der Partnerschaftsanfrage aus RISK-1 erledigt.
- **A2** Der Wochenplan wird aus vier Wochen ab heute abgeleitet (Regeln Aufgabe 4); Zeiten je Wochentag
  (`fromByDay`) werden ignoriert – `BellSchedule` hat ein Raster für alle Tage.
- **A3** Automatischer Import zeigt Abweichungen sofort, Änderungen am Stundenplan aber erst nach Bestätigung in der
  Vorschau (ADR-0004/AK-3 zusammen gelesen); die Vorschau-Daten liegen nur auf dem Gerät.
- **A4** Wechsel zu „von Hand“ entfernt Abweichungen mit Herkunft Quelle ab heute (sonst stünden nie mehr
  aktualisierte Vertretungen da); vergangene bleiben.
- **A5** Lehrkräfte an mehreren Schulen (`multipleAccounts`) werden im MVP nicht unterstützt und bekommen eine Meldung.
- **A6** Kombinierte Klassen erscheinen als `"8a/8b"`; ob das die Zuordnung zu Parallelklassen (FR-3.2) stört, zeigt
  erst der echte Plan.
- **A7** Ablageort der Prüfnotiz `docs/research/` – in der Dokumenten-Landkarte der `CLAUDE.md` nicht vorgesehen;
  sie ist Beleg, nicht Entscheidung.
