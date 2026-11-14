# Frontstage — Teilplan 08: Datenort iCloud oder OneDrive, Abgleich und Koppeln

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> Rahmen: `docs/superpowers/plans/2026-11-13-00-uebersicht.md` – gilt vollständig und geht diesem Teilplan vor.

**Goal:** Den Datenort wählbar machen (FR-14, ADR-0012): „iCloud“ bleibt die SwiftData-Spiegelung aus Teilplan 02; „OneDrive“ arbeitet mit SwiftData ohne Spiegelung und gleicht über Microsoft Graph im Ordner der App (`Apps/Frontstage`) ab – eine JSON-Datei je Datensatz, Delta-Abfrage, Löschmarken, Konfliktregeln, Umzug zwischen den Datenorten, Auswahl in Einrichten mit der Zeile „Stand des Abgleichs“ – und ein zweites Gerät per QR-Code koppeln (FR-14.1), ohne Server.

**Architecture:** Alles Entscheidende ist reine Logik im Kern (`Packages/FrontstageCore/Sources/FrontstageCore/DataFolder/`): Dateiformat (Hülle + Inhalt je Modell), Pfade und Erkennung von Konfliktkopien, Verarbeitung der Delta-Antworten zu einer Dateiliste (`RemoteIndex`), lokales Buch über den Abgleichstand (`SyncLedger`), „zuletzt geschrieben gilt“ je Datensatz, Löschmarken mit Ablauf nach 90 Tagen, Auswahl der zu lesenden und zu schreibenden Dateien, Beitreten zu einem gefüllten Datenordner, Statuszusammenfassung, Inhalt und Prüfung des Kopplungs-Codes – lokal mit `scripts\swift-test.ps1` getestet. Die App übersetzt Records ↔ Kern-Inhalt (`RecordCodec`), spricht Graph über eine schmale Schnittstelle (`RemoteDataFolder`, umgesetzt von `OneDriveDataClient` auf der Anmeldung aus Teilplan 03), führt den Ablauf (`DataFolderSync`), hält Container und Datenort (`DataLocationController`, Neubau in der laufenden App) und zeigt bzw. scannt den QR-Code.

**Tech Stack:** Swift 6 strikt, SwiftData (`ModelConfiguration(_:schema:url:allowsSave:cloudKitDatabase: .none)`), Microsoft Graph v1.0 über `URLSession`, MSAL (aus Teilplan 03), Core Image (`CIFilter.qrCodeGenerator()`), VisionKit (`DataScannerViewController`, iPad), AVFoundation + Vision (`DetectBarcodesRequest`, Mac), SwiftUI, Swift Testing, XcodeGen.

**Spec:** `docs/adr/0012-datenort-icloud-oder-onedrive-nativ.md` (löst ADR-0010 ab), `docs/ARCHITECTURE.md` (Area daten: Datenort mit „OneDrive-Abgleich“ und „Koppeln“, Nebenläufigkeit, Betrieb; Open Questions Q-33, Q-34), `docs/PRD.md` (FR-14 samt Änderung vom 2026-11-14, FR-14.1, AK-43, AK-44, RISK-9, Glossar „Datenort“ `DataLocation` (`iCloud`, `oneDrive`), „Datenordner“ `DataFolder`, „Koppeln“ `pairing`), `docs/adr/0011-stiftnotizen-neben-dem-dokument.md` (Stiftnotizen neben dem Dokument; `PenNoteRecord` nur Ersatz – wird trotzdem mit abgeglichen).

**Baut auf (Plantexte auf `main`, Umsetzung läuft parallel):** Teilplan 02 (`DataStore`, die acht Records mit Suffix `Record`, `ModelContainerFactory`, `SyncMerger`, `SyncMergeTrigger`, `DataStore.mergeDuplicates()`, Test-Hilfe `makeStore()`), Teilplan 03 (`MicrosoftAccount`, `AccessTokenProviding`, `AuthPresentationAnchor`, `NetworkMonitor`, Test-Attrappe `StubURLProtocol`). Teilplan 01 liegt als Code auf `main` (`Packages/FrontstageCore`, Einrückung **zwei Leerzeichen**).

**Quellen (gelesen 2026-11-14):**
- Microsoft, „What is an App Folder“ (learn.microsoft.com/onedrive/developer/rest-api/concepts/special-folders-appfolder): App-Ordner unter `Apps/` im OneDrive der Person, „created … when your app makes the first call to the folder using the special folder namespace“; Zugriff mit `Files.ReadWrite.AppFolder` **oder** `Files.ReadWrite`; Operationen per Pfad `GET/PUT/DELETE /drive/special/approot:/{path}`, `…:/{path}:/delta`, Upload `PUT /drive/special/approot:/{parent-path}/{name}:/content`.
- Microsoft, OneDrive „permissions reference“ und Microsoft Q&A 1418013: `Files.ReadWrite.AppFolder` nur für private Konten, nicht für Schul-/Arbeitskonten → **`Files.ReadWrite`** (ADR-0012).
- Microsoft Graph, „driveItem: delta“ (learn.microsoft.com/graph/api/driveitem-delta): Folgeseiten über `@odata.nextLink`, danach `@odata.deltaLink`; gelöschte Elemente mit Facette `deleted`; „you should always track items by id“; dasselbe Element kann mehrfach erscheinen – „use the last occurrence“; bei OneDrive for Business fehlt bei Löschungen `name`; `410 Gone` mit `Location`-Kopf → von vorn aufzählen. Die HTTP-Referenz nennt Delta nur am Wurzelordner; die App-Ordner-Seite nennt es auch am App-Ordner → am Gerät prüfen (Q-33), Rückfall: Modellordner auflisten (`…:/children`).
- Microsoft Graph, „Upload small files“ (learn.microsoft.com/graph/api/driveitem-put-content): bis 250 MB; Berechtigung `Files.ReadWrite` für beide Kontoarten; `Content-Type: text/plain` als Pflichtkopf angegeben. `If-Match` ist dort nicht aufgeführt, aber Teil der allgemeinen OneDrive-Bedingungsköpfe; wird es ignoriert, bleibt die Regel trotzdem richtig, weil vor jedem Schreiben gelesen wird (Task 11).
- Apple, `ModelConfiguration.CloudKitDatabase.none` („Disables managed CloudKit sync“) und „Syncing model data across a person’s devices“ (`.none` überschreibt die aus den Entitlements erkannte Kennung – nötig, weil die App die CloudKit-Entitlements aus 02 trägt); `ModelConfiguration.init(_:schema:url:allowsSave:cloudKitDatabase:)` für eine eigene Speicherdatei; `ModelContext.didSave` (userInfo mit eingefügten, geänderten, gelöschten Kennungen unter `ModelContext.NotificationKey`) – Context7 `/websites/developer_apple_swiftdata`.
- Apple, `CIQRCodeGenerator` (developer.apple.com/documentation/coreimage/ciqrcodegenerator): iOS, iPadOS, macOS; `CIFilter.qrCodeGenerator()`, Eigenschaften `message: Data`, `correctionLevel` `"L" | "M" | "Q" | "H"`.
- Apple, `DataScannerViewController` (developer.apple.com/documentation/visionkit/datascannerviewcontroller): iOS/iPadOS 16+, **nicht macOS**; vor dem Zeigen `isSupported` und `isAvailable` prüfen; braucht `NSCameraUsageDescription`.
- Apple, `DetectBarcodesRequest` (developer.apple.com/documentation/vision/detectbarcodesrequest): iOS 18+, macOS 15+, `struct`, `symbologies`, `perform(on:orientation:)` u. a. für `CMSampleBuffer` → Scannen am Mac.

## Global Constraints

Alle Zeilen der Übersicht gelten (Abschnitt „Global Constraints“, Abstimmung Punkte 14 und 15). Zusätzlich für diesen Teilplan:

- **Kern zuerst und lokal belegt:** Tasks 1–7 berühren nur `Packages/FrontstageCore` (nur `import Foundation`) und laufen TDD mit `.\scripts\swift-test.ps1 -Filter <Suite>` (RED und GREEN lokal belegen). Tasks 8–14 sind App-Code: auf Windows nicht baubar; „Test ausführen“ heißt dort Task 15 (ein CI-Lauf am Ende, startet der Controller). Davor jeden Diff auf Compilerfehler durchsehen.
- **Nur in den App-Ordner schreiben:** Jede schreibende oder löschende Graph-Anfrage adressiert `…/special/approot:/<Pfad>` mit einem Pfad, den `RemoteLayout.isValidPath(_:)` bestätigt, oder eine Element-Kennung, die aus dem `RemoteIndex` des App-Ordners stammt. Nie Material, nie andere Ordner (FR-3.4, ADR-0012) – obwohl `Files.ReadWrite` es erlauben würde.
- **Netzverbindungen:** nur `graph.microsoft.com` und die MSAL-Authority (NFR-2, AK-18). Kein Server des Produkts, auch nicht zum Koppeln.
- **Nie lokal löschen, weil eine Datei fehlt.** Gelöscht wird nur durch eine gelesene Löschmarke (`deleted: true`). Eine Delta-Löschung oder eine Neu-Aufzählung nach `410` ändert nur die Dateiliste, nie lokale Daten.
- **Token nie in Logs, Dateien oder `UserDefaults`** (NFR-4); Zugriff nur über `MicrosoftAccount`.
- **Zeitstempel im Format:** ISO 8601 in UTC mit Millisekunden (`2026-11-17T08:35:00.123Z`), Schlüssel sortiert, eingerückt – lesbar in OneDrive im Browser, stabile Prüfsummen.
- **Prüfsummen** immer über die **kodierten Bytes** (`ContentHash.fnv1a64`), nie über Werte im Speicher. FNV-1a statt SHA-256, weil der Kern nur Foundation importiert (CryptoKit fehlt unter Windows) und hier Änderungserkennung genügt, keine Sicherheit.
- **Abgeglichen werden alle acht Records aus Teilplan 02** (auch `PenNoteRecord`). Neue Modelle oder Felder späterer Teilpläne brauchen eine Zeile in `RecordPayload` und `RecordCodec` – „jede Änderung am Datenmodell muss in beiden Abgleichwegen funktionieren“ (ADR-0012, Kosten).
- **Gestaltung:** Tasks 13 und 14 berühren Oberfläche (`Design-Takt: Hauptstufe`), alle anderen `Design-Takt: keiner`. Nur Systemstandard, keine eigenen Gestaltungsentscheidungen; Lücken im Abschlussbericht nennen.
- Testdaten: Klassen `8a`, `8b`; Fach `Englisch`; Material „Vokabeln.pdf“; Geräte-Kennungen `"device-A"`, `"device-B"`; Konto `lehrkraft@example.com`; Laufwerk `"b!drive"`, App-Ordner `"01APPROOT"`; Zeiten `t(n) = Date(timeIntervalSince1970: n)`.

## Entscheidungen dieses Teilplans (mit Begründung)

1. **Getrennte Speicherdateien je Datenort.** iCloud: unverändert `ModelContainerFactory.makeCloudContainer(identifier:)` aus 02. OneDrive: `Application Support/Frontstage-onedrive.store` mit `cloudKitDatabase: .none`. *Grund:* Dieselbe Datei abwechselnd mit und ohne Spiegelung zu öffnen, hinterlässt Spiegelungs-Metadaten, deren Verhalten beim Wiedereinschalten nicht dokumentiert ist. *Verworfen:* eine Datei für beide.
2. **Wechsel des Datenorts baut den Container in der laufenden App neu, kein Neustart.** `DataLocationController` hält Container, `DataStore`, `SyncMergeTrigger`, `DataFolderSync` und einen Zähler `generation`; die Wurzelansicht hängt mit `.id(generation)` daran. *Grund:* iPadOS bietet keinen Weg, die eigene App neu zu starten (`exit()` widerspricht den App-Review-Richtlinien und wirkt wie ein Absturz). *Verworfen:* „App schließen und neu öffnen“.
3. **Umzug = Kopie mit Kennung.** Alle Datensätze gehen über denselben Übersetzer wie der Abgleich (`RecordCodec`) mit gleicher `id` und gleichem `createdAt` in den neuen Speicher. Ziel OneDrive: Speicherdatei vorher leeren, dann einfügen. Ziel iCloud: einfügen oder nach `id` überschreiben, nichts löschen, danach `mergeDuplicates()`. Der alte Ort bleibt unberührt. *Grund:* ein Übersetzungsweg statt zweier.
4. **Beitreten zu einem gefüllten Datenordner: der Datenordner gewinnt** für Datensätze, die dort und lokal liegen; nur lokal Vorhandenes wird geschrieben. *Grund:* Die Records aus 02 tragen nicht überall einen Änderungszeitpunkt, „wer ist neuer“ ist lokal nicht entscheidbar; der Datenordner ist der gemeinsame Stand. *Kosten:* Wechsel OneDrive → iCloud → OneDrive verliert in der iCloud-Zeit geänderte Inhalte gleicher Datensätze (Risiko 3).
5. **Lokales Buch statt neuer Felder an den Records.** `SyncLedger` (Application Support, nicht gesichert, nicht abgeglichen): je Datensatz Prüfsumme, Stand und Gerät des zuletzt geschriebenen oder übernommenen Stands, `dirtySince` für Ungeschriebenes; je Datei das zuletzt gesehene eTag; dazu `RemoteIndex` mit Delta-Link. *Grund:* Schema aus 02 bleibt unverändert (CloudKit erlaubt nach Produktionsfreigabe nur Additives).
6. **Zuletzt geschrieben gilt, entschieden mit dem Zeitpunkt der lokalen Änderung.** Eine ungeschriebene lokale Änderung (`dirtySince`) verliert gegen einen gelesenen Stand mit späterem `updatedAt`; Gleichstand → größere Geräte-Kennung. Ein Durchgang ist immer **lesen → anwenden → zusammenführen → schreiben**; geschrieben wird mit `If-Match` auf das zuletzt gesehene eTag, ein `412` lässt den Datensatz ausstehend und löst einen neuen Durchgang aus.
7. **Anhänge inhaltsadressiert:** `<Kennung>.<Feld>.<Prüfsumme>.bin`. *Grund:* eine Anhang-Datei wird nie überschrieben, also nie im Konflikt; die JSON-Datei nennt genau, was sie braucht; fehlt es noch, wartet der Datensatz. Verwaiste Anhänge erst nach **7 Tagen** entfernen.
8. **Ort = App-Ordner, Berechtigung `Files.ReadWrite`, nachträglich angefordert** (ADR-0012). Die Anmeldung aus 03 bleibt für FR-5.1 bei `Files.Read`; erst die Wahl von OneDrive als Datenort fordert `Files.ReadWrite` an.
9. **Auslöser:** Start, Vordergrund, Rückkehr des Netzes (`NetworkMonitor` aus 03), 1 s nach jedem `ModelContext.didSave` (nur Schreiben), alle 60 s im Vordergrund (Delta mit gespeichertem Link – eine kleine Anfrage, meist leer).
10. **Datenort-Vorgabe ohne Wahl: iCloud** (verhält sich wie Teilplan 02). Datenort und Datenordner liegen in `UserDefaults` (je Gerät, nicht abgeglichen).
11. **Geräte-Kennung** = beim ersten Start erzeugte UUID in `UserDefaults` (nicht `identifierForVendor`, das es am Mac nicht gibt); nur für den Gleichstand.
12. **Kopplungs-Code als Text** `frontstage-pair:?v=1&loc=…&lib=…&drive=…&item=…&acct=…` (Abfrageteil per `URLComponents` kodiert). Kein registriertes URL-Schema: Die Kamera-App des Systems soll damit nichts öffnen; nur Frontstage liest ihn. Der Kontoname steht nur gekürzt darin (`l…@example.com`). Er überträgt keinen Zugriff – nur Kennungen, die erst nach Anmeldung am selben Konto etwas öffnen.
13. **Scannen:** iPad mit `DataScannerViewController`; Mac mit AVFoundation + Vision (`DataScannerViewController` gibt es am Mac nicht). Mac ohne Kamera: Hinweis „am iPad scannen“ (der Mac ist meist das erste Gerät) plus Wahl von Hand – bei OneDrive findet die App den Datenordner nach der Anmeldung ohnehin selbst im App-Ordner.

## Review Focus

1. **Anmeldung abgelaufen, Zustimmung fehlt oder kein Netz** → lokale Änderungen bleiben ausstehend und gehen nicht verloren; die Statuszeile sagt „Anmeldung nötig“ bzw. „offline“; nach Anmeldung bzw. Netz schreibt der nächste Durchgang sie. Tests: Task 11 `signInRequiredKeepsChangesPending`, `offlineKeepsChangesPending`; Task 6 `summaryPriority`.
2. **Anderes Gerät schreibt zwischen Lesen und Schreiben** (`412 Precondition Failed`) → kein blindes Überschreiben; der Datensatz bleibt ausstehend, der nächste Durchgang liest und entscheidet nach Zeitpunkt. Tests: Task 10 `uploadSendsIfMatchAndMaps412`, Task 11 `preconditionFailedRereadsInsteadOfOverwriting`.
3. **Delta-Link verfallen (`410 Gone`)** → neue Aufzählung; nichts doppelt, nichts lokal gelöscht, unveränderte Dateien werden nicht neu geladen. Tests: Task 3 `resyncRebuildsWithoutForgettingETags`, Task 11 `resyncAfterGoneReadsNothingTwice`.
4. **QR-Code eines anderen Microsoft-Kontos oder einer anderen Bibliothek** → abgelehnt mit Hinweis, Datenort und Daten unverändert. Tests: Task 7 `verifyRejectsOtherDrive`, `verifyRejectsOtherLibrary`; Task 13 `pairingWithOtherAccountChangesNothing`.
5. **Zweites Gerät tritt einem gefüllten Datenordner bei** → dessen Stand bleibt, nur auf dem zweiten Gerät Vorhandenes kommt dazu, nichts wird mit jüngerem Zeitstempel überschrieben. Test: Task 6 `joinPrefersFolderForSharedRecords`, Task 12 `joiningFilledFolderKeepsFolderState`.

---

## Dateistruktur

| Datei | Verantwortung | Task |
|---|---|---|
| `Packages/FrontstageCore/Sources/FrontstageCore/DataFolder/DataLocation.swift`, `SyncModel.swift`, `RecordPayload.swift`, `RecordEnvelope.swift`, `DataFolderCoding.swift`, `ContentHash.swift` | Datenort, Modelle, Dateiformat, Prüfsumme | 1 |
| `…/DataFolder/RemoteLayout.swift`, `LibraryMarker.swift` | Pfade im App-Ordner, Dateinamen erkennen, `library.json` | 2 |
| `…/DataFolder/RemoteIndex.swift` | Delta-Antworten → Dateiliste | 3 |
| `…/DataFolder/SyncLedger.swift`, `DataFolderPlanner.swift` | lokales Buch, lokale Änderungen, ausgehende Hüllen, zu lesende Dateien | 4 |
| `…/DataFolder/IncomingResolver.swift` | gelesene Dateien entscheiden, Löschmarken, Konfliktkopien, Aufräumen | 5 |
| `…/DataFolder/DataFolderJoin.swift`, `DataFolderSyncStatus.swift` | Beitreten, Statuszusammenfassung | 6 |
| `…/DataFolder/PairingPayload.swift` | Kopplungs-Code und Prüfung | 7 |
| `Packages/FrontstageCore/Tests/FrontstageCoreTests/DataFolder/*Tests.swift` | Kern-Tests | 1–7 |
| `Frontstage/Data/Folder/RecordCodec.swift` | Record ↔ `RecordPayload`, Export, Einfügen/Überschreiben, Löschen | 8 |
| `Frontstage/Data/Folder/DataLocationSettings.swift`, `DeviceIdentity.swift`, `Frontstage/Data/ModelContainerFactory+DataLocation.swift` | Datenort, Datenordner, Geräte-Kennung, Container je Datenort | 9 |
| `Frontstage/Storage/OneDrive/MicrosoftAccount.swift` (ändern) | Token je Berechtigung, nachträgliche Zustimmung | 9 |
| `Frontstage/Data/Folder/RemoteDataFolder.swift`, `OneDriveDataClient.swift` | Graph-Zugriff auf den App-Ordner | 10 |
| `Frontstage/Data/Folder/LedgerStore.swift`, `DataFolderSync.swift` | Ablauf eines Durchgangs, Auslöser, Status | 11 |
| `Frontstage/Data/DataStore.swift` (ändern) | `applyExternalChanges(_:)` | 11 |
| `Frontstage/Data/DataLocationController.swift`, `Frontstage/App/DataScopedRoot.swift`, `Frontstage/App/FrontstageApp.swift` (ändern) | Container-Lebenszyklus, Wechsel mit Umzug, Einbindung | 12 |
| `Frontstage/UI/Setup/Pairing/*.swift` | QR-Anzeige, Scanner, Kopplungsablauf | 13 |
| `Frontstage/UI/Setup/DataLocationSettingsViewModel.swift`, `DataLocationSettingsView.swift`, `SetupView.swift` (ändern) | Einrichten › Datenort, Statuszeile | 14 |
| `FrontstageTests/Data/Folder/*Tests.swift`, `FrontstageTests/UI/*Tests.swift` | App-Tests (Simulator) | 8–14 |
| `project.yml`, `Frontstage/Resources/Localizable.xcstrings` (ändern) | Kamera-Berechtigung, Texte | 13, 14 |

---

### Task 1: Datensatz-Format im Kern

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/DataFolder/DataLocation.swift`, `SyncModel.swift`, `RecordPayload.swift`, `RecordEnvelope.swift`, `DataFolderCoding.swift`, `ContentHash.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/DataFolder/RecordFormatTests.swift`

**Interfaces:**
- Consumes: `BellSchedule` (Teilplan 01, `Codable`, festes JSON-Format aus `BellScheduleTests`)
- Produces:

```swift
/// Datenort (Glossar): wo die App-Daten zwischen den Geräten abgeglichen werden (FR-14, ADR-0012).
public enum DataLocation: String, Codable, Sendable, CaseIterable { case iCloud, oneDrive }

/// Modell eines Datensatzes; rawValue = Unterordner im Datenordner.
public enum SyncModel: String, Codable, Sendable, CaseIterable {
  case timetable = "Timetable", timetableEntry = "TimetableEntry", nonTeachingPeriod = "NonTeachingPeriod",
       scheduleChange = "ScheduleChange", materialLink = "MaterialLink", penNote = "PenNote",
       lessonInfo = "LessonInfo", boardPage = "BoardPage"
  /// Eltern vor Kindern (= Reihenfolge von allCases).
  public static var applyOrder: [SyncModel] { get }
}

/// Verweis auf eine Anhang-Datei; Datei: <Kennung>.<field>.<hash>.bin.
public struct AttachmentRef: Codable, Hashable, Sendable { public var hash: String; public var byteCount: Int; public init(hash:byteCount:) }
```

Inhalt je Modell – Felder 1:1 aus Teilplan 02, Task 4 (gleiche Namen, gleiche Optionalität), plus `createdAt: Date` in jedem; abweichend nur:

| Struktur (`public struct …: Codable, Hashable, Sendable`, Initialisierer mit allen Feldern) | anders als am Record |
|---|---|
| `TimetablePayload` | `bellSchedule: BellSchedule?` statt `bellScheduleData` (lesbar); ohne `entries` |
| `TimetableEntryPayload` | `timetableID: UUID?` statt Beziehung |
| `NonTeachingPeriodPayload`, `ScheduleChangePayload`, `LessonInfoPayload` | – |
| `MaterialLinkPayload` | ohne `penNotes` |
| `PenNotePayload` | `materialLinkID: UUID?` statt Beziehung; `drawing: AttachmentRef?` statt `drawingData` |
| `BoardPagePayload` | `drawing: AttachmentRef?`, `backgroundImage: AttachmentRef?` statt der `Data`-Felder |

```swift
public enum RecordPayload: Hashable, Sendable {
  case timetable(TimetablePayload), timetableEntry(TimetableEntryPayload), nonTeachingPeriod(NonTeachingPeriodPayload),
       scheduleChange(ScheduleChangePayload), materialLink(MaterialLinkPayload), penNote(PenNotePayload),
       lessonInfo(LessonInfoPayload), boardPage(BoardPagePayload)
  public var model: SyncModel { get }
  public var attachments: [String: AttachmentRef] { get }   // Feldname → Anhang
  public var parentID: UUID? { get }                        // timetableID / materialLinkID
}

/// Inhalt einer Datei <Modell>/<Kennung>.json.
public struct RecordEnvelope: Hashable, Sendable {
  public static let currentFormatVersion = 1
  public var formatVersion: Int
  public var id: UUID
  public var model: SyncModel
  public var updatedAt: Date
  public var deviceID: String
  public var deleted: Bool
  public var payload: RecordPayload?          // nil genau dann, wenn deleted
  public init(id:model:updatedAt:deviceID:deleted:payload:)
  /// „Zuletzt geschrieben gilt“: späteres updatedAt; bei Gleichstand größere deviceID.
  public func isNewer(than other: (updatedAt: Date, deviceID: String)) -> Bool
}

public enum DataFolderCodingError: Error, Equatable { case unsupportedFormatVersion(Int), payloadMissing, modelMismatch }
public enum DataFolderCoding {
  public static func encode(_ envelope: RecordEnvelope) throws -> Data      // sortedKeys, prettyPrinted, ISO 8601 UTC mit ms
  public static func decode(_ data: Data) throws -> RecordEnvelope          // formatVersion > current → unsupportedFormatVersion
  public static func encodePayload(_ payload: RecordPayload) throws -> Data // sortedKeys, ohne Einrückung
  public static func payloadHash(_ payload: RecordPayload) throws -> String
  static var encoder: JSONEncoder { get }; static var decoder: JSONDecoder { get }   // auch für LibraryMarker (Task 2)
}
public enum ContentHash { public static func fnv1a64(_ data: Data) -> String }   // 16 Hex-Zeichen, klein
```

JSON-Form (verbindlich; so liegt sie im OneDrive der Lehrkraft):

```json
{
  "deleted" : false,
  "deviceID" : "device-A",
  "formatVersion" : 1,
  "id" : "9F0C…",
  "model" : "MaterialLink",
  "payload" : { "createdAt" : "2026-11-17T08:35:00.000Z", "displayName" : "Vokabeln", … },
  "updatedAt" : "2026-11-17T08:35:00.123Z"
}
```

`RecordEnvelope` kodiert selbst (`encode(to:)`/`init(from:)`): erst `model`, dann `payload` passend zum Modell; bei `deleted == true` fehlt `payload`. Swift-Hinweis: Ein `enum` mit zugeordneten Werten bekommt kein automatisches `Codable` in dieser Form, deshalb die eigene Implementierung in der Hülle; die acht Inhalts-Strukturen nutzen das automatisch erzeugte. Datum über `JSONEncoder.DateEncodingStrategy.custom` mit `Date.ISO8601FormatStyle(includingFractionalSeconds: true)` (UTC).

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("DataFolder Format")`)

```swift
@Test("FR-14: Hülle hin und zurück, Zeitstempel mit Millisekunden")
func envelopeRoundTrip() throws {
  let env = RecordEnvelope(id: id(1), model: .materialLink, updatedAt: Date(timeIntervalSince1970: 1_795_000_000.123),
                           deviceID: "device-A", deleted: false, payload: .materialLink(sampleLink))
  #expect(try DataFolderCoding.decode(try DataFolderCoding.encode(env)) == env)
}

@Test("Festes Dateiformat: Schlüssel sortiert, Datum als ISO-Text in UTC, Löschmarke ohne Inhalt")
func encodesPinnedLayout() throws {
  let text = String(decoding: try DataFolderCoding.encode(tombstone(id(1), at: 1_795_000_000.5)), as: UTF8.self)
  #expect(text.contains(#""updatedAt" : "2026-11-18T09:46:40.500Z""#))
  #expect(text.range(of: "\"deleted\"")!.lowerBound < text.range(of: "\"deviceID\"")!.lowerBound)
  #expect(!text.contains("payload"))
}

@Test("Nicht gelöschter Datensatz ohne Inhalt wirft payloadMissing")
func missingPayloadThrows()

@Test("Neuere Formatversion wird abgelehnt")
func rejectsNewerFormatVersion()      // "formatVersion" : 2 → .unsupportedFormatVersion(2)

@Test("Unbekannte Felder im Inhalt werden ignoriert (additive Schemaänderung)")
func ignoresUnknownPayloadFields()

@Test("Prüfsumme: gleicher Inhalt gleich, ein Zeichen anders → anders")
func payloadHashIsStable()

@Test("FNV-1a 64 bekannter Werte")
func fnvKnownValues() {
  #expect(ContentHash.fnv1a64(Data()) == "cbf29ce484222325")
  #expect(ContentHash.fnv1a64(Data("a".utf8)) == "af63dc4c8601ec8c")
}

@Test("Zuletzt geschrieben gilt; Gleichstand nach Geräte-Kennung")
func newerComparesTimeThenDevice()

@Test("Anhänge und Elternkennung je Modell")
func attachmentsAndParent()           // BoardPage → ["drawing", "backgroundImage"]; PenNote.parentID == materialLinkID; LessonInfo → [:], nil

@Test("Anwende-Reihenfolge: Eltern vor Kindern")
func applyOrderParentsFirst()

@Test("Datenort-Rohwerte laut Glossar")
func dataLocationRawValues()          // ["iCloud", "oneDrive"]
```

- [ ] **Step 2: Rot belegen** – `.\scripts\swift-test.ps1 -Filter "DataFolder Format"` → FAIL (Typen fehlen).
- [ ] **Step 3: Implementieren** gemäß Interfaces.
- [ ] **Step 4: Grün belegen** – derselbe Befehl, danach `.\scripts\swift-test.ps1` ganz → PASS.
- [ ] **Step 5: Commit** – `git commit -m "core: add data folder record format with envelope, payloads and content hash"`

---

### Task 2: Pfade im App-Ordner, Dateinamen, `library.json`

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/DataFolder/RemoteLayout.swift`, `LibraryMarker.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/DataFolder/RemoteLayoutTests.swift`

**Interfaces:**
- Consumes: `SyncModel`, `DataFolderCoding` (Task 1)
- Produces:

```swift
/// Was eine Datei im Datenordner ist. Pfade relativ zum App-Ordner, Trenner "/".
public enum RemoteEntry: Hashable, Sendable {
  case library                                                   // library.json
  case record(model: SyncModel, id: UUID)                        // <Modell>/<Kennung>.json
  case conflictCopy(model: SyncModel, id: UUID)                  // <Modell>/<Kennung><Zusatz>.json
  case attachment(model: SyncModel, id: UUID, field: String, hash: String)
  case attachmentCopy(model: SyncModel, id: UUID)                // wird entfernt
}

public enum RemoteLayout {
  public static let libraryPath = "library.json"
  public static func recordPath(model: SyncModel, id: UUID) -> String          // "MaterialLink/<UUID groß>.json"
  public static func attachmentPath(model: SyncModel, id: UUID, field: String, hash: String) -> String
  /// nil = fremde Datei (z. B. von der Lehrkraft abgelegt) – wird nie angefasst.
  public static func classify(path: String) -> RemoteEntry?
  /// Nur Pfade, die classify erkennt; kein "..", kein führendes "/", keine weiteren Ebenen.
  public static func isValidPath(_ path: String) -> Bool
}

/// Inhalt von library.json: kennzeichnet einen Datenordner eindeutig (FR-14.1).
public struct LibraryMarker: Codable, Hashable, Sendable {
  public var formatVersion: Int        // = RecordEnvelope.currentFormatVersion
  public var libraryID: UUID
  public var createdAt: Date
  public init(libraryID: UUID, createdAt: Date)
}
```

Regel für Konfliktkopien: Dateiname beginnt mit einer gültigen UUID (36 Zeichen, Groß-/Kleinschreibung egal), danach ein **nicht leerer** Zusatz, Endung `.json`. Deckt u. a. `<id>-PC-LEHRER.json` (OneDrive-Synchronisierung unter Windows), `<id> (1).json`, `<id> 2.json` ab. Anhänge: `<id>.<feld>.<hash>.bin`; anderes, das mit `<id>` beginnt und auf `.bin` endet → `attachmentCopy`.

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("DataFolder Layout")`)

```swift
@Test("Pfad eines Datensatzes und eines Anhangs")
func buildsPaths() {
  #expect(RemoteLayout.recordPath(model: .materialLink, id: id(1)) == "MaterialLink/\(id(1).uuidString).json")
  #expect(RemoteLayout.attachmentPath(model: .boardPage, id: id(2), field: "drawing", hash: "0011aabbccddeeff")
          == "BoardPage/\(id(2).uuidString).drawing.0011aabbccddeeff.bin")
}

@Test("Konfliktkopien werden erkannt")
func classifiesConflictCopies()      // Zusätze "-PC-LEHRER", " (1)", " 2" → .conflictCopy(model: .lessonInfo, id: id(3))

@Test("library.json, kleingeschriebene Kennung, Anhang-Kopie")
func classifiesSpecialNames()

@Test("Fremde Dateien werden nicht angefasst")
func ignoresForeignFiles()           // "Notizen.txt", "Unknown/<id>.json", "MaterialLink/abc.json", "MaterialLink/x/<id>.json" → nil

@Test("Nur gültige Pfade dürfen geschrieben werden")
func validPathCheck()                // recordPath → true; "../x.json", "/MaterialLink/<id>.json", "Material/Vokabeln.pdf" → false

@Test("library.json hin und zurück")
func libraryMarkerRoundTrip()
```

- [ ] **Step 2: Rot belegen** – `.\scripts\swift-test.ps1 -Filter "DataFolder Layout"`.
- [ ] **Step 3: Implementieren** – Dateiname zerlegen, erste 36 Zeichen mit `UUID(uuidString:)` prüfen; kein `NSRegularExpression`.
- [ ] **Step 4: Grün belegen**, ganze Suite.
- [ ] **Step 5: Commit** – `git commit -m "core: add data folder paths, conflict copy detection and library marker"`

---

### Task 3: `RemoteIndex` – Delta-Antworten zu einer Dateiliste

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/DataFolder/RemoteIndex.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/DataFolder/RemoteIndexTests.swift`

**Interfaces:**
- Consumes: `RemoteLayout` (Task 2)
- Produces:

```swift
/// Ausschnitt eines Graph-driveItem aus Delta oder children ($select=id,name,parentReference,file,folder,deleted,eTag,size,lastModifiedDateTime).
public struct RemoteItem: Hashable, Sendable {
  public var id: String
  public var name: String?             // fehlt bei Löschungen in OneDrive for Business
  public var parentID: String?
  public var isFolder: Bool
  public var isDeleted: Bool
  public var eTag: String?
  public var size: Int?
  public var lastModified: Date?
  public init(id:name:parentID:isFolder:isDeleted:eTag:size:lastModified:)
}
/// Eine Datei im Datenordner mit ihrem Stand.
public struct RemoteFile: Hashable, Codable, Sendable {
  public var path: String; public var itemID: String; public var eTag: String; public var size: Int; public var lastModified: Date
}

/// Bild des App-Ordners aus Delta-Seiten; wird mit dem Buch gespeichert.
public struct RemoteIndex: Codable, Equatable, Sendable {
  public init(appFolderID: String)
  public var appFolderID: String
  public var deltaLink: String?
  /// Wendet eine Seite an. Elemente nach Kennung verfolgen, späteres Vorkommen gewinnt (Graph-Doku);
  /// Ordner direkt unter dem App-Ordner merken (Kennung → Name); Dateien im App-Ordner oder genau eine Ebene
  /// darunter aufnehmen; tiefere und fremde Elemente ignorieren; gelöschte Elemente entfernen (Name nicht nötig).
  public mutating func apply(_ items: [RemoteItem])
  /// Beginn einer Neu-Aufzählung nach 410: Elemente und deltaLink verwerfen, appFolderID bleibt.
  public mutating func beginResync()
  /// Aktuelle Dateiliste (nur Pfade, die RemoteLayout.classify erkennt), sortiert nach Pfad.
  public var files: [RemoteFile] { get }
  public func file(at path: String) -> RemoteFile?
}
```

*Warum ein eigener Index:* Delta liefert Elemente ohne Pfad (`parentReference.path` fehlt) und Löschungen bei Schulkonten ohne Namen; die Zuordnung Kennung → Pfad muss also lokal gehalten werden. Der Rückfall ohne Delta (Q-33) speist dieselbe `apply`-Methode mit den Ergebnissen von `…:/children` nach `beginResync()`.

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("DataFolder RemoteIndex")`)

```swift
@Test("Datei in einem Modellordner bekommt ihren Pfad über den Elternordner")
func resolvesPathThroughParentFolder() {
  var index = RemoteIndex(appFolderID: "01APPROOT")
  index.apply([folder("F1", "MaterialLink", parent: "01APPROOT"), file("I1", "\(id(1).uuidString).json", parent: "F1", eTag: "e1")])
  #expect(index.files.map(\.path) == ["MaterialLink/\(id(1).uuidString).json"])
}

@Test("Späteres Vorkommen desselben Elements gewinnt")
func lastOccurrenceWins()             // I1 mit e1, dann I1 mit e2 → eTag "e2"

@Test("Löschung ohne Namen (Schulkonto) entfernt die Datei")
func deletionWithoutNameRemovesFile()

@Test("library.json direkt im App-Ordner, fremde und tiefere Dateien ignoriert")
func ignoresForeignAndDeepItems()

@Test("Review Focus 3: Neu-Aufzählung nach 410 baut dieselbe Liste wieder auf")
func resyncRebuildsWithoutForgettingETags() {
  // apply(A); beginResync(); apply(A) → files gleich wie vorher; deltaLink nil bis zum Ende der Aufzählung
}

@Test("Datei erscheint vor ihrem Ordner in derselben Seite")
func fileBeforeFolderInSamePage()     // Reihenfolge innerhalb einer Seite egal: erst nach der ganzen Seite Pfade bilden
```

- [ ] **Step 2: Rot belegen** – `.\scripts\swift-test.ps1 -Filter "DataFolder RemoteIndex"`.
- [ ] **Step 3: Implementieren** – Elemente in einem Wörterbuch nach Kennung, Pfade erst in `files` berechnet.
- [ ] **Step 4: Grün belegen**, ganze Suite.
- [ ] **Step 5: Commit** – `git commit -m "core: build data folder file list from Graph delta pages"`

---

### Task 4: Lokales Buch, lokale Änderungen, ausgehende Hüllen, zu lesende Dateien

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/DataFolder/SyncLedger.swift`, `DataFolderPlanner.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/DataFolder/DataFolderPlannerTests.swift`

**Interfaces:**
- Consumes: Task 1–3
- Produces:

```swift
public struct LedgerEntry: Codable, Hashable, Sendable {
  public var model: SyncModel
  public var payloadHash: String?        // nil bei Löschmarke
  public var updatedAt: Date             // Stand, der zuletzt geschrieben oder übernommen wurde
  public var deviceID: String
  public var deleted: Bool
  public var dirtySince: Date?           // lokale Änderung, noch nicht geschrieben
}

/// Lokales Buch – je Gerät, nie abgeglichen, nie gesichert.
public struct SyncLedger: Codable, Equatable, Sendable {
  public var deviceID: String
  public var entries: [UUID: LedgerEntry]
  public var seenETags: [String: String]          // Pfad → zuletzt gelesenes oder geschriebenes eTag
  public var remote: RemoteIndex
  public var lastSuccessfulSync: Date?
  public init(deviceID: String, appFolderID: String)
  public var dirtyIDs: Set<UUID> { get }
  public mutating func recordWritten(_ envelope: RecordEnvelope, payloadHash: String?, file: RemoteFile)
  public mutating func recordApplied(_ envelope: RecordEnvelope, payloadHash: String?)
  public mutating func recordSeen(_ file: RemoteFile)
}

public struct LocalRecordState: Hashable, Sendable { public var id: UUID; public var model: SyncModel; public var payloadHash: String; public init(id:model:payloadHash:) }

public enum DataFolderPlanner {
  /// `changed`: geprüfte Datensätze (Prüfsumme ≠ Buch → dirtySince = now). `liveIDs`: alle lokalen Kennungen;
  /// im Buch bekannte, nicht gelöschte, die fehlen → Löschmarke ausstehend. nil = keine Löschprüfung.
  public static func markLocalChanges(changed: [LocalRecordState], liveIDs: Set<UUID>?, ledger: SyncLedger, now: Date) -> SyncLedger
  /// Hüllen für alle ausstehenden Kennungen außer `excluding`; updatedAt = now, deviceID = ledger.deviceID.
  public static func outgoing(ledger: SyncLedger, payloads: [UUID: RecordPayload], excluding: Set<UUID>, now: Date) -> [RecordEnvelope]
  /// Zu lesen: Datensätze und Konfliktkopien aus ledger.remote.files, deren eTag von seenETags abweicht oder fehlt;
  /// Reihenfolge SyncModel.applyOrder, dann Pfad.
  public static func filesToRead(ledger: SyncLedger) -> [RemoteFile]
  /// eTag für If-Match beim Schreiben; nil = Datei unbekannt (neu anlegen).
  public static func ifMatch(for path: String, ledger: SyncLedger) -> String?
}
```

*Warum `updatedAt = now` beim Schreiben:* Die Konfliktentscheidung fällt beim Lesen mit `dirtySince` (Task 5); wer danach schreibt, hat gewonnen und ist der zuletzt Schreibende. Das trägt das Beitreten (Task 6, `dirtySince = .distantPast`) ohne Sonderweg.

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("DataFolder Planner")`)

```swift
@Test("Neuer Datensatz wird ausstehend") func newRecordBecomesDirty()
@Test("Unveränderte Prüfsumme bleibt sauber") func unchangedHashStaysClean()
@Test("Lokal gelöscht → Löschmarke ausstehend") func missingLiveIDBecomesTombstone()
@Test("liveIDs nil prüft keine Löschungen") func nilLiveIDsSkipsDeletion()
@Test("Ausgehend: eigenes Gerät, jetzt, Löschmarke ohne Inhalt; Ausgenommene fehlen") func outgoingBuildsEnvelopes()
@Test("Ausstehend, aber lokal verschwunden und nicht gelöscht → nichts") func outgoingSkipsVanished()
@Test("Nur Dateien mit neuem eTag werden gelesen; Anhänge und library.json nie") func filesToReadComparesETags()
@Test("If-Match nur für bekannte Dateien") func ifMatchFromSeenETags()
@Test("Buch hin und zurück als JSON") func ledgerCodableRoundTrip()
```

Kernzusicherungen (Beispiel `filesToReadComparesETags`): `seenETags = [a: "e1"]`, Index mit `a` (e1), `b` (e2), `<a> (1).json` (e3), einem Anhang und `library.json` → `filesToRead == [b, aCopy]`.

- [ ] **Step 2: Rot belegen** – `.\scripts\swift-test.ps1 -Filter "DataFolder Planner"`.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Grün belegen**, ganze Suite.
- [ ] **Step 5: Commit** – `git commit -m "core: add sync ledger and local change planning"`

---

### Task 5: Gelesene Dateien entscheiden – zuletzt geschrieben gilt, Löschmarken, Konfliktkopien, Aufräumen

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/DataFolder/IncomingResolver.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/DataFolder/IncomingResolverTests.swift`

**Interfaces:**
- Consumes: Task 1–4
- Produces:

```swift
public enum ReadOutcome: Sendable {
  case decoded(RecordEnvelope)
  case unreadable              // kaputt oder Download fehlgeschlagen: nächster Durchgang liest erneut
  case newerFormat(Int)        // aus einer neueren App-Version
}
public struct ReadFile: Sendable { public var file: RemoteFile; public var outcome: ReadOutcome; public init(file:outcome:) }

public struct IncomingResolution: Equatable, Sendable {
  public var apply: [RecordEnvelope]              // in SyncModel.applyOrder
  public var rewriteCanonical: [RecordEnvelope]   // Gewinner aus einer Konfliktkopie → Original neu schreiben
  public var removeFiles: [RemoteFile]            // entschiedene Kopien, abgelaufene Löschmarken (+ Anhänge), verwaiste Anhänge
  public var waitingIDs: Set<UUID>                // nicht übernehmen und nicht schreiben; Dateien nicht als gesehen markieren
  public var seenFiles: [RemoteFile]
  public var forgetIDs: Set<UUID>                 // abgelaufene Löschmarken
  public var newerFormatCount: Int
}

public enum IncomingResolver {
  public static let tombstoneLifetime: TimeInterval = 90 * 24 * 3600      // Area daten: 90 Tage
  public static let orphanAttachmentGrace: TimeInterval = 7 * 24 * 3600   // Entscheidung 7
  public static func resolve(read: [ReadFile], ledger: SyncLedger, now: Date) -> IncomingResolution
}
```

Regeln (je Kennung über Original und alle Konfliktkopien; im Code je Regel ein deutscher Kommentar mit Nummer):

1. `newerFormat` → nur `newerFormatCount`; Datei nie entfernen; Kennung in `waitingIDs` (auch eine ausstehende lokale Änderung wird dann nicht geschrieben).
2. `unreadable` → `waitingIDs`.
3. Gewinner = neueste dekodierte Hülle (`isNewer`). Fehlt ein Anhang mit genau diesem Hash in `ledger.remote.files` → `waitingIDs`.
4. Mit dem Buch vergleichen: Eintrag fehlt → übernehmen. Ausstehend → übernehmen nur, wenn `winner.updatedAt > dirtySince`; sonst gewinnt lokal. Sauber → übernehmen, wenn Gewinner neuer als (`updatedAt`, `deviceID`) des Eintrags.
5. Gewinner aus einer Konfliktkopie und nicht „lokal gewinnt“ → `rewriteCanonical`. Alle Konfliktkopien der Kennung → `removeFiles`.
6. Löschmarke im Original älter als `tombstoneLifetime` → Original und Anhänge der Kennung in `removeFiles`, Kennung in `forgetIDs`.
7. Anhang, dessen Hash in keinem bekannten Stand der Kennung vorkommt und dessen `lastModified < now − orphanAttachmentGrace` → `removeFiles`; `attachmentCopy` immer.
8. Fehlt die Datei einer im Buch bekannten Kennung, passiert nichts (Global Constraints).

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("DataFolder Incoming")`)

```swift
@Test("Unbekannter Datensatz wird übernommen") func unknownRecordIsApplied()
@Test("Neuerer Stand gewinnt gegen sauberen lokalen Stand") func newerRemoteWinsOverClean()
@Test("Gleicher Stand wie im Buch → nichts") func sameStateIsNoop()
@Test("Nebenläufigkeit: lokale Änderung nach dem gelesenen Stand gewinnt") func laterLocalChangeWins()   // dirtySince t(30), Datei t(20) → apply leer
@Test("Nebenläufigkeit: gelesener Stand nach der lokalen Änderung gewinnt") func laterRemoteBeatsPendingLocal()
@Test("Löschmarke wird übernommen") func remoteTombstoneIsApplied()
@Test("Neuere Konfliktkopie gewinnt, Original neu, Kopie entfernt") func newerConflictCopyWins()
@Test("Ältere Konfliktkopie wird nur entfernt") func olderConflictCopyIsRemoved()
@Test("Fehlender Anhang → wartet, Datei nicht gesehen") func waitsForMissingAttachment()
@Test("Unlesbare Datei wird erneut gelesen, nicht entfernt") func undecodableFileIsRetriedNotDeleted()
@Test("Fehlende Datei löscht lokal nichts") func absentFileNeverDeletesLocal()
@Test("Datei neuerer Formatversion wird nie überschrieben") func newerFormatFileIsNeverOverwritten()
@Test("Löschmarke älter als 90 Tage wird mit Anhängen entfernt") func expiredTombstoneIsRemoved()
@Test("Löschmarke jünger als 90 Tage bleibt") func freshTombstoneStays()
@Test("Verwaister Anhang älter als 7 Tage wird entfernt") func oldOrphanAttachmentIsRemoved()
@Test("Frischer verwaister Anhang bleibt (kommt vor seiner JSON-Datei an)") func freshOrphanAttachmentIsKept()
@Test("Anwenden in Eltern-vor-Kind-Reihenfolge") func applyIsOrderedByModel()
```

Kernzusicherungen (Beispiel `newerConflictCopyWins`): Original t(10) „device-A“, Kopie `<id>-PC-LEHRER.json` t(20) „device-B“ → `apply.map(\.updatedAt) == [t(20)]`, `rewriteCanonical.map(\.updatedAt) == [t(20)]`, `removeFiles.map(\.path) == [copyPath]`.

- [ ] **Step 2: Rot belegen** – `.\scripts\swift-test.ps1 -Filter "DataFolder Incoming"`.
- [ ] **Step 3: Implementieren** in der Reihenfolge der Regeln.
- [ ] **Step 4: Grün belegen**, ganze Suite.
- [ ] **Step 5: Commit** – `git commit -m "core: resolve incoming data folder files with last-writer-wins, tombstones and conflict copies"`

---

### Task 6: Beitreten und Stand des Abgleichs

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/DataFolder/DataFolderJoin.swift`, `DataFolderSyncStatus.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/DataFolder/DataFolderJoinAndStatusTests.swift`

**Interfaces:**
- Consumes: Task 1–5
- Produces:

```swift
public enum DataFolderJoin {
  /// Frisches Buch beim Wechsel auf OneDrive: jeder lokale Datensatz ausstehend seit .distantPast →
  /// im nächsten Durchgang gewinnt jeder Stand, der schon im Datenordner liegt (Entscheidung 4).
  public static func ledger(local: [LocalRecordState], deviceID: String, appFolderID: String) -> SyncLedger
}

public struct DataFolderSyncStatus: Equatable, Sendable {
  public enum Phase: Equatable, Sendable { case idle, syncing, offline, signInRequired, failed }
  public var phase: Phase
  public var lastSuccess: Date?
  public var pendingCount: Int
  public var waitingCount: Int
  public var newerFormatCount: Int
  public init(phase: Phase = .idle, lastSuccess: Date? = nil, pendingCount: Int = 0, waitingCount: Int = 0, newerFormatCount: Int = 0)
  /// Genau eine Aussage für „Stand des Abgleichs“ – in dieser Vorrangfolge.
  public var summary: DataFolderSyncSummary { get }
}
public enum DataFolderSyncSummary: Equatable, Sendable {
  case signInRequired                    // 1. Anmeldung abgelaufen oder Zustimmung fehlt
  case needsNewerApp                     // 2.
  case offline(pending: Int)             // 3.
  case failed(lastSuccess: Date?)        // 4.
  case syncing                           // 5.
  case waiting(count: Int)               // 6.
  case pending(count: Int)               // 7.
  case upToDate(since: Date)             // 8.
  case neverSynced                       // 9.
}
```

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("DataFolder Join and Status")`)

```swift
@Test("Review Focus 5: beim Beitreten gewinnt der Datenordner, nur lokal Vorhandenes wird geschrieben")
func joinPrefersFolderForSharedRecords() {
  // lokal: id(1) (auch im Datenordner, t(5) von device-B), id(2) (nur lokal)
  let ledger = DataFolderJoin.ledger(local: [state(id(1), .lessonInfo, "lokal"), state(id(2), .lessonInfo, "neu")],
                                     deviceID: "device-A", appFolderID: "01APPROOT")
  let r = IncomingResolver.resolve(read: [decoded(id(1), at: t(5), "device-B")], ledger: ledgerWithIndex(ledger), now: t(100))
  #expect(r.apply.map(\.id) == [id(1)])
  var after = ledger; r.apply.forEach { after.recordApplied($0, payloadHash: "fern") }
  #expect(DataFolderPlanner.outgoing(ledger: after, payloads: [id(2): payload2], excluding: [], now: t(100)).map(\.id) == [id(2)])
}

@Test("Review Focus 1: Statuszeile – Vorrangfolge") func summaryPriority()
  // signInRequired vor allem; offline(pending: 3) vor failed; syncing vor waiting; waiting vor pending; pending vor upToDate
@Test("Neuere App-Version nötig") func summaryNeedsNewerApp()
@Test("Ohne je erfolgreichen Durchgang: noch nicht abgeglichen") func summaryNeverSynced()
```

- [ ] **Step 2: Rot belegen** – `.\scripts\swift-test.ps1 -Filter "DataFolder Join and Status"`.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Grün belegen**, ganze Suite.
- [ ] **Step 5: Commit** – `git commit -m "core: add data folder join ledger and sync status summary"`

---

### Task 7: Kopplungs-Code und Prüfung (FR-14.1)

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/DataFolder/PairingPayload.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/DataFolder/PairingPayloadTests.swift`

**Interfaces:**
- Consumes: `DataLocation` (Task 1), `LibraryMarker` (Task 2)
- Produces:

```swift
/// Inhalt des QR-Codes (Glossar „Koppeln“, `pairing`). Überträgt keinen Zugriff, nur Kennungen.
public struct PairingPayload: Hashable, Sendable {
  public static let currentVersion = 1
  public var version: Int
  public var dataLocation: DataLocation
  public var libraryID: UUID?          // nur oneDrive
  public var driveID: String?          // nur oneDrive
  public var folderItemID: String?     // App-Ordner, nur oneDrive
  public var accountHint: String?      // gekürzt, z. B. "l…@example.com"
  public init(dataLocation: DataLocation, libraryID: UUID? = nil, driveID: String? = nil, folderItemID: String? = nil, accountHint: String? = nil)
  /// "frontstage-pair:?v=1&loc=oneDrive&lib=<UUID>&drive=<…>&item=<…>&acct=<…>" (URLComponents, Prozentkodierung).
  public var text: String { get }
  /// nil bei fremdem Text, fehlenden Pflichtfeldern (oneDrive ohne lib/drive/item) oder unbekanntem loc.
  public init?(text: String)
  /// Erstes Zeichen des Namens, „…“, alles ab „@“; ohne „@“: erstes Zeichen und „…“.
  public static func maskedAccount(_ username: String) -> String
}

public enum PairingVerdict: Equatable, Sendable {
  case ok, differentAccount, libraryMissing, differentLibrary, needsNewerApp
}
public enum PairingVerifier {
  /// Prüft, was das zweite Gerät nach der Anmeldung im eigenen App-Ordner vorfindet.
  public static func verify(_ payload: PairingPayload, foundDriveID: String, foundFolderItemID: String, library: LibraryMarker?) -> PairingVerdict
}
```

Regeln für `verify` (Reihenfolge): `payload.version > currentVersion` → `needsNewerApp`; Laufwerk oder Ordner verschieden → `differentAccount`; kein `library.json` → `libraryMissing` (erstes Gerät hat noch nicht abgeglichen); `library.formatVersion > RecordEnvelope.currentFormatVersion` → `needsNewerApp`; `libraryID` verschieden → `differentLibrary`; sonst `ok`.

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("Pairing")`)

```swift
@Test("FR-14.1: Code für OneDrive hin und zurück")
func oneDriveRoundTrip() {
  let p = PairingPayload(dataLocation: .oneDrive, libraryID: id(1), driveID: "b!drive", folderItemID: "01APPROOT", accountHint: "l…@example.com")
  #expect(p.text.hasPrefix("frontstage-pair:?v=1&loc=oneDrive"))
  #expect(PairingPayload(text: p.text) == p)
}
@Test("Code für iCloud braucht keine Kennungen") func iCloudRoundTrip()
@Test("Fremder Text, unvollständiger OneDrive-Code oder unbekannter Datenort → nil") func rejectsInvalidText()
  // "https://example.com", "frontstage-pair:?v=1&loc=oneDrive&lib=<id>", "frontstage-pair:?v=1&loc=nextcloud"
@Test("Sonderzeichen in Kennungen überstehen die Kodierung") func encodesSpecialCharacters()   // driveID "b!a+b/c=" 
@Test("Kontoname wird gekürzt") func masksAccount()     // "lehrkraft@example.com" → "l…@example.com"
@Test("AK-44: gleiche Kennungen → ok") func verifyAcceptsSameLibrary()
@Test("Review Focus 4: anderes Laufwerk → differentAccount") func verifyRejectsOtherDrive()
@Test("Review Focus 4: andere Bibliothek → differentLibrary") func verifyRejectsOtherLibrary()
@Test("Noch kein library.json → libraryMissing") func verifyLibraryMissing()
@Test("Neuere Version → needsNewerApp") func verifyNeedsNewerApp()
```

- [ ] **Step 2: Rot belegen** – `.\scripts\swift-test.ps1 -Filter "Pairing"`.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Grün belegen**, danach `.\scripts\swift-test.ps1` ganz (alle Kern-Suites).
- [ ] **Step 5: Commit** – `git commit -m "core: add pairing payload and verification"`

---

### Task 8: `RecordCodec` – Records ↔ Kern-Inhalt, Export und Übernahme

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Data/Folder/RecordCodec.swift`
- Test: `FrontstageTests/Data/Folder/RecordCodecTests.swift`

**Interfaces:**
- Consumes: die acht Records, `TimetableRecord.setBellSchedule(_:)`/`makeTimetable()` (Teilplan 02, Task 4/5), `makeStore()` (Teilplan 02, Task 4); `RecordPayload`, `AttachmentRef`, `DataFolderCoding`, `ContentHash`, `LocalRecordState`, `SyncModel` (Task 1, 4)
- Produces:

```swift
/// Ein Datensatz mit Inhalt und den Bytes seiner Anhänge (Feldname → Daten).
struct ExportedRecord: Sendable { let id: UUID; let payload: RecordPayload; let attachmentData: [String: Data] }

@MainActor enum RecordCodec {
  static func exportAll(from context: ModelContext) throws -> [ExportedRecord]
  static func export(_ identifiers: Set<PersistentIdentifier>, from context: ModelContext) throws -> [ExportedRecord]
  static func liveIDs(in context: ModelContext) throws -> Set<UUID>          // nur Feld id (propertiesToFetch)
  static func state(of record: ExportedRecord) throws -> LocalRecordState
  /// Einfügen oder nach id überschreiben; Beziehungen über timetableID/materialLinkID. Speichert NICHT.
  static func upsert(_ payload: RecordPayload, id: UUID, attachmentData: [String: Data], into context: ModelContext) throws
  static func delete(id: UUID, model: SyncModel, from context: ModelContext) throws   // Kaskaden aus 02; speichert NICHT
}
enum RecordCodecError: Error, Equatable { case missingParent(UUID), attachmentMissing(String) }
```

Records über `FetchDescriptor<T>(predicate: #Predicate { $0.id == id })` finden. `id` und `createdAt` kommen aus Hülle bzw. Inhalt – nie neu erzeugen (sonst greift „ältester bleibt“ beim Zusammenführen falsch). `AttachmentRef`: `hash = ContentHash.fnv1a64(data)`, `byteCount = data.count`.

- [ ] **Step 1: Failing Tests schreiben** (In-Memory-Stores aus `makeStore()`)

```swift
@MainActor @Suite struct RecordCodecTests {
  @Test("FR-14: Jedes der acht Modelle hin und zurück ergibt dieselbe Prüfsumme") func roundTripKeepsHashForEveryModel() throws
    // je Modell ein Record mit allen Feldern in Store A (Tafelseite mit Zeichnung und Bild, Stiftnotiz mit Zeichnung);
    // exportAll → upsert in leeren Store B → exportAll(B): gleiche ids, gleiche payloadHash je id
  @Test("Beziehungen kommen über die Kennung des Elterndatensatzes zurück") func relationsRestoredByParentID()
  @Test("Kind ohne Eltern wirft missingParent") func childWithoutParentThrows()
  @Test("Überschreiben nach id legt keinen zweiten Datensatz an") func upsertOverwritesByID()
  @Test("createdAt bleibt beim Übernehmen erhalten") func upsertKeepsCreatedAt()
  @Test("Löschen nach id nimmt Stiftnotizen mit (Kaskade aus 02)") func deleteCascades()
  @Test("liveIDs liefert alle Kennungen") func liveIDsCoverAllModels()
}
```

- [ ] **Step 2: Diff durchsehen** – Feldliste je Modell gegen Teilplan 02, Task 4 (jede Eigenschaft hin **und** zurück); kein `save()` im Codec.
- [ ] **Step 3: Implementieren** – je Modell private `payload(of:)` und `apply(_:to:)`, ein `switch` über `RecordPayload`.
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `git commit -m "data: translate records to data folder payloads and back"`

---

### Task 9: Datenort, Datenordner, Geräte-Kennung, Container je Datenort, Berechtigung

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Data/Folder/DataLocationSettings.swift`, `Frontstage/Data/Folder/DeviceIdentity.swift`, `Frontstage/Data/ModelContainerFactory+DataLocation.swift`
- Modify: `Frontstage/Storage/OneDrive/MicrosoftAccount.swift` (Teilplan 03, Task 9) – zwei Methoden ergänzen, nichts anderes ändern
- Test: `FrontstageTests/Data/Folder/DataLocationSettingsTests.swift`

**Interfaces:**
- Consumes: `ModelContainerFactory.modelTypes`, `.makeCloudContainer(identifier:)`, `.cloudKitContainerIdentifier(bundle:)`, `.makeInMemoryContainer()` (Teilplan 02, Task 4); `MicrosoftAccount`, `MicrosoftAccountError`, `AccessTokenProviding`, `AuthPresentationAnchor` (Teilplan 03, Task 9); `DataLocation` (Task 1)
- Produces:

```swift
/// Datenordner (Glossar): der Ordner der App in OneDrive, auf diesem Gerät gemerkt.
struct DataFolder: Codable, Hashable, Sendable { var driveID: String; var folderItemID: String; var libraryID: UUID; var accountUsername: String }

/// Datenort und Datenordner je Gerät (UserDefaults "dataLocation", "dataFolder"); ohne Wahl iCloud (Entscheidung 10).
struct DataLocationSettings {
  init(defaults: UserDefaults = .standard)
  var location: DataLocation { get nonmutating set }
  var dataFolder: DataFolder? { get nonmutating set }
  var hasChosen: Bool { get }
}

enum DeviceIdentity { static func current(defaults: UserDefaults = .standard) -> String }   // UserDefaults "deviceID"

extension ModelContainerFactory {
  static var oneDriveStoreURL: URL { get }                       // Application Support/Frontstage-onedrive.store
  static func makeOneDriveContainer(url: URL = oneDriveStoreURL) throws -> ModelContainer   // cloudKitDatabase: .none
  static func makeContainer(for location: DataLocation) throws -> ModelContainer           // unter Tests: In-Memory wie makeDefault
  static func removeOneDriveStore(url: URL = oneDriveStoreURL) throws                       // samt -shm/-wal
}

extension MicrosoftAccount {
  /// Berechtigung des Datenorts OneDrive (ADR-0012).
  static let dataLocationScopes = ["Files.ReadWrite"]
  /// Still erneuerter Token für genau diese Berechtigungen; wirft .interactionRequired, wenn Zustimmung fehlt.
  func accessToken(scopes: [String]) async throws -> String
  /// Nachträgliche Zustimmung (interaktiv), z. B. beim Wechsel auf OneDrive.
  func requestScopes(_ scopes: [String], anchor: AuthPresentationAnchor) async throws
}
/// Token-Lieferant für den Abgleich (Sendable-Hülle, springt auf den Hauptakteur).
struct DataLocationTokenProvider: AccessTokenProviding { init(account: MicrosoftAccount) }
```

MSAL-Hinweis: Nachträgliche Zustimmung = `MSALInteractiveTokenParameters(scopes: dataLocationScopes, …)` mit dem vorhandenen Konto (`account` gesetzt); still = `MSALSilentTokenParameters(scopes:account:)`. Beide Wege gibt es in 03 schon für `Files.Read`; hier nur mit anderen Berechtigungen.

- [ ] **Step 1: Failing Tests schreiben**

```swift
@MainActor @Suite struct DataLocationSettingsTests {
  @Test("FR-14: Ohne Wahl iCloud; Datenort und Datenordner bleiben je Gerät gespeichert") func locationAndFolderPersist()
    // UserDefaults(suiteName: "test-\(UUID())")
  @Test("Geräte-Kennung bleibt gleich") func deviceIDIsStable()
  @Test("OneDrive-Container spiegelt nicht und speichert in eigene Datei") func oneDriveContainerUsesOwnFile() throws
}
```

- [ ] **Step 2: Diff durchsehen** – `cloudKitDatabase: .none` wörtlich in `makeOneDriveContainer`; in `MicrosoftAccount.swift` nur die zwei neuen Methoden; kein Token außerhalb von MSAL.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `git commit -m "data: add data location setting, onedrive container and data location scopes"`

---

### Task 10: `OneDriveDataClient` – Graph-Zugriff auf den App-Ordner

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Data/Folder/RemoteDataFolder.swift`, `Frontstage/Data/Folder/OneDriveDataClient.swift`
- Test: `FrontstageTests/Data/Folder/OneDriveDataClientTests.swift`, `FrontstageTests/Data/Folder/InMemoryRemoteDataFolder.swift`

**Interfaces:**
- Consumes: `AccessTokenProviding` (03), `DataLocationTokenProvider` (Task 9), `RemoteItem`, `RemoteFile`, `RemoteLayout`, `LibraryMarker` (Task 2, 3); Test-Attrappe `StubURLProtocol` (Teilplan 03, Task 9)
- Produces:

```swift
enum RemoteDataFolderError: Error, Equatable {
  case offline, signInRequired, preconditionFailed(path: String), resyncRequired, throttled(retryAfter: Int?), invalidPath(String), server(Int)
}
struct AppFolderInfo: Equatable, Sendable { let driveID: String; let folderItemID: String }
struct DeltaPage: Sendable { let items: [RemoteItem]; let nextLink: String?; let deltaLink: String? }

/// Schmale Sicht auf den Datenordner; OneDriveDataClient spricht Graph, Tests nutzen InMemoryRemoteDataFolder.
protocol RemoteDataFolder: Sendable {
  func appFolder() async throws -> AppFolderInfo
  /// link nil = erste Aufzählung; sonst nextLink oder deltaLink. 410 → resyncRequired.
  func delta(link: String?) async throws -> DeltaPage
  /// Rückfall ohne Delta (Q-33): alle Elemente der Modellordner und library.json.
  func listAll() async throws -> [RemoteItem]
  func download(itemID: String) async throws -> Data
  /// Nur gültige Pfade (RemoteLayout.isValidPath / libraryPath). ifMatch gesetzt → Kopf If-Match; 412 → preconditionFailed.
  func upload(_ data: Data, to path: String, ifMatch: String?) async throws -> RemoteFile
  func delete(_ file: RemoteFile) async throws                      // If-Match: file.eTag; 404 gilt als erledigt
  func ensureModelFolders() async throws                           // je SyncModel ein Ordner; 409 gilt als vorhanden
}

struct OneDriveDataClient: RemoteDataFolder {
  init(tokens: any AccessTokenProviding, session: URLSession = .shared)
}
```

Anfragen (alle `https://graph.microsoft.com/v1.0`, Kopf `Authorization: Bearer <token>`):

| Methode | Anfrage |
|---|---|
| `appFolder` | `GET /me/drive/special/approot?$select=id,parentReference` → `id`, `parentReference.driveId` |
| `delta(nil)` | `GET /me/drive/special/approot/delta?$select=id,name,parentReference,file,folder,deleted,eTag,size,lastModifiedDateTime`; sonst die übergebene URL unverändert |
| `listAll` | `GET /me/drive/special/approot/children?$select=…` und je Modellordner `GET /me/drive/special/approot:/<Modell>:/children?$select=…&$top=200`, Folgeseiten über `@odata.nextLink` |
| `download` | `GET /me/drive/items/{id}/content` (Weiterleitung folgt `URLSession` selbst) |
| `upload` | `PUT /me/drive/special/approot:/<Pfad>:/content`, `Content-Type: text/plain` (laut Referenz Pflicht), Körper = Bytes |
| `delete` | `DELETE /me/drive/items/{id}` |
| `ensureModelFolders` | `POST /me/drive/special/approot/children` mit `{"name": "<Modell>", "folder": {}, "@microsoft.graph.conflictBehavior": "fail"}` |

Fehlerabbildung: kein Netz (`URLError.notConnectedToInternet`, `.networkConnectionLost`) → `offline`; `MicrosoftAccountError.interactionRequired` oder `401` nach einmaligem Erneuern → `signInRequired`; `410` → `resyncRequired`; `412` → `preconditionFailed`; `429`/`503` → `throttled(retryAfter:)` aus dem Kopf `Retry-After`. Pfadsegmente mit `OfficeAddress.encodeSegment` (Teilplan 03) kodieren.

`InMemoryRemoteDataFolder` (nur Testziel, `actor`): hält Dateien mit Kennung und eTag, zählt Änderungen, liefert Delta seit einem Link (Link = Zählerstand als Text), kann `412`, `410`, `offline`, `signInRequired` auf Wunsch auslösen. Zwei Geräte im Test teilen sich eine Instanz.

- [ ] **Step 1: Failing Tests schreiben** (`StubURLProtocol`, `FakeTokens` „test-token“)

```swift
@Suite struct OneDriveDataClientTests {
  @Test("App-Ordner: Kennung und Laufwerk") func appFolderDecodes() async throws
  @Test("Delta: Seite mit nextLink, gelöschtes Element ohne Namen") func deltaDecodesPage() async throws
  @Test("Review Focus 3: 410 wird resyncRequired") func goneIsResync() async throws
  @Test("Review Focus 2: Hochladen sendet If-Match, 412 wird preconditionFailed") func uploadSendsIfMatchAndMaps412() async throws
    // request.url == ".../me/drive/special/approot:/MaterialLink/<ID>.json:/content"; Kopf If-Match == "\"e1\""
  @Test("Ungültiger Pfad wird nicht gesendet") func invalidPathIsRejectedLocally() async throws   // "../Material/Vokabeln.pdf" → invalidPath, keine Anfrage
  @Test("Kein Netz → offline; Zustimmung fehlt → signInRequired; 429 → throttled") func mapsErrors() async throws
  @Test("Löschen: 404 gilt als erledigt") func deleteNotFoundIsDone() async throws
  @Test("Nur graph.microsoft.com wird angefragt (NFR-2)") func onlyGraphHost() async throws
}
```

- [ ] **Step 2: Diff durchsehen** – jede schreibende Anfrage geht durch `RemoteLayout.isValidPath` bzw. eine Kennung aus dem Index; kein Token in Logs.
- [ ] **Step 3: Implementieren.** JSON der Graph-Antworten über kleine private `Decodable`-Strukturen; `lastModifiedDateTime` mit `ISO8601DateFormatter` (`.withInternetDateTime`, `.withFractionalSeconds` optional – beide Formen kommen vor).
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `git commit -m "data: graph client for the onedrive app folder"`

---

### Task 11: `DataFolderSync` – ein Durchgang, Auslöser, Status

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Data/Folder/LedgerStore.swift`, `Frontstage/Data/Folder/DataFolderSync.swift`
- Modify: `Frontstage/Data/DataStore.swift` (Teilplan 02) – nur `applyExternalChanges(_:)` ergänzen
- Test: `FrontstageTests/Data/Folder/DataFolderSyncTests.swift`

**Interfaces:**
- Consumes: `DataStore` (`modelContext`, `revision`, `mergeDuplicates()`, Teilplan 02), `NetworkMonitor.onBecameOnline` (Teilplan 03, Task 8), `RecordCodec` (Task 8), `RemoteDataFolder` (Task 10), Kern aus Task 1–6
- Produces:

```swift
// In DataStore.swift (Teilplan 02), weil `revision` dort private(set) ist:
extension DataStore {
  /// Änderungen von außen im Kontext ausführen, speichern, revision erhöhen. Kein Zusammenführen.
  func applyExternalChanges(_ body: (ModelContext) throws -> Void) throws
}

/// Buch je Gerät: Application Support/DataFolderLedger.json, isExcludedFromBackup.
@MainActor final class LedgerStore {
  init(fileURL: URL = LedgerStore.defaultFileURL)
  static var defaultFileURL: URL { get }
  var ledger: SyncLedger? { get set }       // set schreibt atomar
  func remove()
}

@MainActor @Observable final class DataFolderSync {
  init(store: DataStore, remote: any RemoteDataFolder, ledger: LedgerStore,
       now: @escaping @MainActor () -> Date = { .now },
       saveDebounce: Duration = .seconds(1), pollInterval: Duration = .seconds(60))
  private(set) var status: DataFolderSyncStatus
  func start()                    // didSave beobachten, Abfrage alle pollInterval starten, runCycle()
  func stop()
  func sceneDidBecomeActive()     // Abfrage an, runCycle()
  func sceneDidEnterBackground()  // Abfrage aus; ausstehende Änderungen sofort schreiben (Schritte 8–10)
  func networkDidBecomeAvailable()   // runCycle()
  /// lesen → anwenden → zusammenführen → schreiben. Nie doppelt (zweiter Aufruf merkt sich „noch einmal“).
  func runCycle() async
}
```

Ablauf `runCycle()` (verbindlich; deutsche Kommentare mit den Nummern):

1. `status.phase = .syncing`. Delta abholen: `remote.delta(link: ledger.remote.deltaLink)`, Folgeseiten bis `deltaLink`, je Seite `ledger.remote.apply`. `resyncRequired` → `ledger.remote.beginResync()`, von vorn (`link: nil`). Delta nicht unterstützt (`server(400)`/`server(501)` beim ersten Aufruf) → `listAll()` nach `beginResync()` (Q-33; im Buch vermerken, dass Delta fehlt).
2. `filesToRead(ledger:)` → je Datei `remote.download` → `DataFolderCoding.decode` → `ReadOutcome` (Dekodierfehler `.unreadable`, `unsupportedFormatVersion` `.newerFormat`).
3. `resolution = IncomingResolver.resolve(read:ledger:now:)`.
4. Anwenden in `store.applyExternalChanges { ctx in … }`: je Hülle die Anhänge laden (`remote.download` über die Kennung aus `ledger.remote.file(at:)`), dann `RecordCodec.upsert` bzw. `delete`. `missingParent` oder fehlgeschlagener Anhang → Kennung zusätzlich wartend.
5. Nach erfolgreichem Speichern im selben Haupt-Akteur-Schritt: `recordApplied`, `recordSeen` (ohne Wartende), `forgetIDs` entfernen, Buch speichern. *Warum im selben Schritt:* Das `didSave` des Anwendens wirkt erst nach der Entprellzeit; dann stimmen die Prüfsummen schon mit dem Buch, übernommene Stände werden nicht zurückgeschrieben.
6. `try store.mergeDuplicates()` (Teilplan 02).
7. Lokale Änderungen erfassen: erster Durchgang nach `start()` `RecordCodec.exportAll`, sonst die im `didSave` gesammelten Kennungen → `markLocalChanges(changed:liveIDs:ledger:now:)`.
8. Schreiben: `rewriteCanonical` und `outgoing(…, excluding: resolution.waitingIDs, …)`; je Hülle erst Anhänge (fehlende im Index hochladen, ohne `If-Match` – inhaltsadressiert), dann JSON mit `ifMatch(for:ledger:)` → `recordWritten`. `preconditionFailed` → Datensatz bleibt ausstehend, nach dem Durchgang `runCycle()` noch einmal (höchstens einmal direkt hintereinander).
9. `remove`: je Datei aus `resolution.removeFiles` `remote.delete`.
10. `lastSuccessfulSync = now`; Status (`pendingCount` = `dirtyIDs.count`, `waitingCount`, `newerFormatCount`), `phase = .idle`. `offline` → `.offline`, `signInRequired` → `.signInRequired`, sonstige Fehler → `.failed`; protokolliert (`Logger`, Subsystem Bundle-ID, Kategorie `DataFolderSync`, nie Token oder Inhalte), nie als Dialog. Das Buch bleibt in jedem Fall gültig gespeichert.

Auslöser: `ModelContext.didSave` von `store.modelContext` (`NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: store.modelContext, queue: .main)` mit `MainActor.assumeIsolated { … }`, wie `SyncMergeTrigger` in 02) sammelt Kennungen aus `ModelContext.NotificationKey.insertedIdentifiers`/`.updatedIdentifiers` (bei `.deletedIdentifiers` nur `liveIDs`-Prüfung) und löst nach `saveDebounce` die Schritte 7–10 aus; Abfrage alle `pollInterval` im Vordergrund → `runCycle()`.

- [ ] **Step 1: Failing Tests schreiben** (zwei In-Memory-Stores „Mac“ und „iPad“, je eigenes `LedgerStore` und Geräte-Kennung, gemeinsamer `InMemoryRemoteDataFolder`; Entprellung `.milliseconds(20)`; `now` steuerbar)

```swift
@MainActor @Suite struct DataFolderSyncTests {
  @Test("AK-43 (Daten): Zuordnung am Mac erscheint nach einem Durchgang am iPad") func linkTravelsBetweenDevices() async throws
  @Test("AK-43 (Daten): Stiftnotiz (Ersatz im Datenort) samt Zeichnung kommt an") func penNoteWithDrawingTravels() async throws
  @Test("Löschen erreicht das andere Gerät als Löschmarke") func deletionTravelsAsTombstone() async throws
  @Test("Übernommene Stände werden nicht zurückgeschrieben") func appliedStateIsNotEchoed() async throws   // Hochlade-Zähler der Attrappe bleibt
  @Test("Speichern löst nach der Entprellzeit das Schreiben aus") func saveTriggersWrite() async throws
  @Test("Doppelter Ausfall von zwei Geräten wird nach dem Abgleich eins") func duplicatesMergeAfterSync() async throws
  @Test("Review Focus 1: Anmeldung nötig → Änderungen bleiben ausstehend, nach Anmeldung geschrieben") func signInRequiredKeepsChangesPending() async throws
  @Test("Review Focus 1: offline → Status offline, nichts verloren") func offlineKeepsChangesPending() async throws
  @Test("Review Focus 2: 412 → kein Überschreiben, nächster Durchgang entscheidet nach Zeitpunkt") func preconditionFailedRereadsInsteadOfOverwriting() async throws
  @Test("Review Focus 3: nach 410 wird nichts doppelt gelesen und nichts gelöscht") func resyncAfterGoneReadsNothingTwice() async throws
  @Test("Ohne Delta (Q-33): Auflisten liefert dasselbe Ergebnis") func listFallbackSyncs() async throws
  @Test("Zweiter gleichzeitiger Aufruf läuft danach, nicht parallel") func cyclesDoNotOverlap() async throws
  @Test("revision steigt nach übernommenen Änderungen") func revisionBumpsOnApply() async throws
}
```

Kernzusicherungen (Beispiel `linkTravelsBetweenDevices`): `try mac.store.assign(reference("Vokabeln.pdf"), to: di8b); await mac.sync.runCycle(); await ipad.sync.runCycle()` → `try ipad.store.links(for: di8b).map(\.displayName) == ["Vokabeln.pdf"]`.

- [ ] **Step 2: Diff durchsehen** – Schritt-Nummern 1–10 als Kommentare; kein `Task.detached`; Beobachter-Token gehalten und in `stop()` entfernt; `applyExternalChanges` ist die einzige Änderung an `DataStore.swift`.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `git commit -m "data: run onedrive data folder sync cycles"`

---

### Task 12: `DataLocationController` – Container je Datenort, Wechsel mit Umzug, Einbindung

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Data/DataLocationController.swift`, `Frontstage/App/DataScopedRoot.swift`
- Modify: `Frontstage/App/FrontstageApp.swift` (vorher ganz lesen, Übersicht Abstimmung 13 und 15: nichts entfernen, nur verlagern)
- Test: `FrontstageTests/Data/DataLocationControllerTests.swift`

**Interfaces:**
- Consumes: Task 8–11; `SyncMergeTrigger` (Teilplan 02, Task 10); `MicrosoftAccount`, `NetworkMonitor` (Teilplan 03); `DataFolderJoin.ledger(local:deviceID:appFolderID:)`, `LibraryMarker` (Task 2, 6)
- Produces:

```swift
enum DataLocationError: Error, Equatable { case notSignedIn, consentMissing, offline, moveFailed }

@MainActor @Observable final class DataLocationController {
  init(settings: DataLocationSettings = .init(), account: MicrosoftAccount,
       makeContainer: @escaping @MainActor (DataLocation) throws -> ModelContainer = ModelContainerFactory.makeContainer(for:),
       makeRemote: @escaping @MainActor () -> any RemoteDataFolder,
       ledgerStore: LedgerStore = .init(), deviceID: String = DeviceIdentity.current())
  private(set) var location: DataLocation
  private(set) var container: ModelContainer
  private(set) var store: DataStore
  private(set) var folderSync: DataFolderSync?           // nur bei .oneDrive
  private(set) var generation: Int
  private(set) var isMoving: Bool
  var dataFolder: DataFolder? { get }
  func start()
  func sceneDidBecomeActive(); func sceneDidEnterBackground(); func networkDidBecomeAvailable()
  /// Wechsel auf OneDrive: Zustimmung zu Files.ReadWrite (anchor), App-Ordner holen, library.json lesen oder anlegen,
  /// Umzug, Beitreten. `expectedLibraryID` beim Koppeln: abweichend → nichts ändern (PairingVerifier, Task 7).
  func switchToOneDrive(anchor: AuthPresentationAnchor, expected: PairingPayload? = nil) async throws -> PairingVerdict
  func switchToICloud() async throws
}

/// Alles, was einen DataStore hält, entsteht hier – mit .id(generation) beim Wechsel neu.
struct DataScopedRoot<Content: View>: View {
  init(controller: DataLocationController, @ViewBuilder content: @escaping (DataStore, ModelContainer) -> Content)
}
```

Ablauf `switchToOneDrive` (Entscheidungen 3, 4): `isMoving = true` → `account.requestScopes(MicrosoftAccount.dataLocationScopes, anchor:)` (fehlt die Anmeldung, vorher `account.signIn(anchor:)`) → `remote.appFolder()` → `library.json` laden (`listAll`/Index; fehlt: bei Kopplung `libraryMissing` zurückgeben und **nichts ändern**; sonst neu anlegen mit `LibraryMarker(libraryID: UUID(), createdAt: now)`) → bei Kopplung `PairingVerifier.verify` – nicht `ok` → zurückgeben, nichts ändern → `remote.ensureModelFolders()` → `RecordCodec.exportAll` aus dem aktuellen Container → `removeOneDriveStore()` → neuer OneDrive-Container → `upsert` in `SyncModel.applyOrder` → speichern → `ledgerStore.ledger = DataFolderJoin.ledger(local:deviceID:appFolderID:)` → neues `DataStore`, `SyncMergeTrigger`, `DataFolderSync` → `settings.dataFolder`, `settings.location = .oneDrive` → `generation += 1` → `await folderSync.runCycle()` → `isMoving = false`. Scheitert ein Schritt vor dem Setzen von `settings.location`, bleibt alles beim alten Datenort.
`switchToICloud`: `folderSync.runCycle()` (ausstehende Änderungen noch hinaus; offline → trotzdem weiter, Hinweis im Status) → `exportAll` → iCloud-Container → `upsert` nach `id`, nichts löschen → speichern → `mergeDuplicates()` → `ledgerStore.remove()`, `settings.dataFolder = nil`, `settings.location = .iCloud` → `generation += 1`. Der Datenordner in OneDrive bleibt unberührt.

`FrontstageApp`: `@State private var dataLocation = DataLocationController(account: …, makeRemote: { OneDriveDataClient(tokens: DataLocationTokenProvider(account: …)) })` ersetzt den Container-Aufbau aus 02 (`makeDefault()`, `DataStore(…)`, `SyncMergeTrigger`). `MicrosoftAccount` wird dafür **vor** dem Controller einmal im `App`-Typ erzeugt (er hängt nicht am Datenort). Inhalt des `WindowGroup`: `DataScopedRoot(controller: dataLocation) { store, container in … }`; alles, was 03, 04 und 05 dort mit dem `DataStore` erzeugen (`StorageService`, `AppEnvironment`, `TimetableSourceCoordinator`, `.modelContainer(container)`, `.environment(store)`), wandert unverändert in eine kleine Ansicht in der Closure, die diese Objekte in `@State` hält. Szenenphase `.active`/`.background` und `NetworkMonitor.onBecameOnline` rufen zusätzlich die Methoden des Controllers. Swift-Hinweis: `@State` in einer Ansicht mit `.id(x)` wird neu angelegt, sobald sich `x` ändert – so entstehen nach einem Wechsel alle Dienste auf dem neuen `DataStore`.

- [ ] **Step 1: Failing Tests schreiben** (In-Memory-Container je Datenort, `InMemoryRemoteDataFolder`, Attrappe für Zustimmung)

```swift
@MainActor @Suite struct DataLocationControllerTests {
  @Test("FR-14: Wechsel auf OneDrive nimmt alle Daten mit und schreibt sie in den Datenordner") func switchToOneDriveMovesAllData() async throws
    // location == .oneDrive; links(for: di8b).count == 1; Attrappe enthält MaterialLink/<id>.json und library.json; generation == 1
  @Test("Review Focus 5: Beitreten – Stand im Datenordner gewinnt, nur lokal Vorhandenes kommt dazu") func joiningFilledFolderKeepsFolderState() async throws
  @Test("Wechsel zurück auf iCloud übernimmt die Daten, der Datenordner bleibt unberührt") func switchToICloudKeepsFolderFiles() async throws
  @Test("Zustimmung abgelehnt → Datenort bleibt iCloud, nichts geändert") func consentDeniedKeepsLocation() async throws
  @Test("Kennung und Anlagezeit bleiben beim Umzug erhalten") func moveKeepsIDsAndCreatedAt() async throws
}
```

- [ ] **Step 2: Diff durchsehen** – `FrontstageApp` vorher/nachher: jede Zeile früherer Teilpläne noch da (ggf. verlagert); genau ein aktiver `ModelContainer`.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `git commit -m "data: switch data location at runtime with data move"`

---

### Task 13: Koppeln – QR-Code zeigen, scannen, übernehmen (FR-14.1)

Design-Takt: Hauptstufe (vor dem Editieren den projektlokalen Skill `apple-design` laden; nur Systemstandard)

**Files:**
- Create: `Frontstage/UI/Setup/Pairing/PairingCodeView.swift`, `PairingScannerView.swift`, `PairingFlowModel.swift`, `PairingSheet.swift`
- Modify: `project.yml` – beide Ziele `NSCameraUsageDescription` (falls Teilplan 07 ihn schon gesetzt hat: Text um das Koppeln ergänzen, Übersicht Abstimmung 15); macOS-Ziel Entitlement `com.apple.security.device.camera: true`
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/UI/PairingFlowModelTests.swift`

**Interfaces:**
- Consumes: `PairingPayload`, `PairingVerdict` (Task 7), `DataLocationController` (Task 12)
- Produces:

```swift
/// QR-Bild aus Text: CIFilter.qrCodeGenerator(), correctionLevel "M", ganzzahlig skaliert (CGAffineTransform), ohne Glättung.
enum QRCodeRenderer { static func image(for text: String, scale: CGFloat) -> CGImage? }

/// Schmale Sicht auf den Controller für Tests.
@MainActor protocol PairingControlling: AnyObject {
  var location: DataLocation { get }
  var dataFolder: DataFolder? { get }
  func switchToOneDrive(anchor: AuthPresentationAnchor, expected: PairingPayload?) async throws -> PairingVerdict
  func switchToICloud() async throws
}
extension DataLocationController: PairingControlling

@MainActor @Observable final class PairingFlowModel {
  enum Step: Equatable { case showCode, scanning, confirm(PairingPayload), working, done, rejected(PairingVerdict), invalidCode, failed }
  init(controller: any PairingControlling, accountUsername: @escaping () -> String?)
  private(set) var step: Step
  /// Code dieses Geräts (nil bei OneDrive ohne Datenordner – dann erst Datenort wählen).
  var ownPayload: PairingPayload? { get }
  func startScanning()
  func scanned(_ text: String)                 // PairingPayload(text:) → confirm, sonst invalidCode
  func confirm(anchor: AuthPresentationAnchor) async   // iCloud → switchToICloud; oneDrive → switchToOneDrive(expected:)
  func cancel()
}

/// Kamera-Scanner: iPad DataScannerViewController (recognizedDataTypes: [.barcode(symbologies: [.qr])]),
/// Mac AVCaptureSession + Vision DetectBarcodesRequest (symbologies [.qr]); onCode wird einmal gerufen.
struct PairingScannerView: View { init(onCode: @escaping (String) -> Void) ; static var isAvailable: Bool { get } }
```

Plattform-Hinweise: iPad – `UIViewControllerRepresentable` um `DataScannerViewController`; vor dem Zeigen `isSupported && isAvailable` (Quelle oben), Treffer im Delegaten `dataScanner(_:didAdd:allItems:)` → `.barcode(let b)` → `b.payloadStringValue`. Mac – `NSViewRepresentable` mit `AVCaptureVideoPreviewLayer`; `AVCaptureVideoDataOutput`-Delegat auf eigener serieller Warteschlange, höchstens alle 0,3 s `DetectBarcodesRequest().perform(on: sampleBuffer)`; Delegat-Klasse `final class …: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable` (alle Eigenschaften `let`, Rückruf über `@Sendable`-Closure auf den Hauptakteur). `isAvailable` am Mac: `AVCaptureDevice.default(for: .video) != nil`. Ohne Kamera zeigt der Ablauf: „Code am anderen Gerät scannen“ plus Verweis auf die Wahl von Hand (Task 14).

Ablauf in der Oberfläche (Systemstandard, `PairingSheet` als `.sheet`): „Gerät koppeln“ zeigt den eigenen Code (`PairingCodeView`) und darunter „Mit anderem Gerät koppeln“ (Scanner). Nach dem Scannen eine Bestätigung mit Datenort und gekürztem Konto („Daten von l…@example.com übernehmen?“), bei OneDrive danach Microsoft-Anmeldung und Zustimmung (MSAL-Dialog), dann `working` mit `ProgressView`, am Ende `done` oder `rejected` mit Text je Urteil.

Texte (Platzhalter, Wortlaut offene Kategorie):

| Schlüssel | Wert |
|---|---|
| `pairing.title` | Gerät koppeln |
| `pairing.showCode.message` | Diesen Code am anderen Gerät scannen. |
| `pairing.scan.action` | Mit anderem Gerät koppeln |
| `pairing.noCamera` | Keine Kamera verfügbar. Den Code am anderen Gerät scannen oder den Datenort von Hand wählen. |
| `pairing.confirm.iCloud` | Datenort iCloud übernehmen? |
| `pairing.confirm.oneDrive %@` | Daten von %@ aus OneDrive übernehmen? |
| `pairing.rejected.differentAccount` | Der Code gehört zu einem anderen Microsoft-Konto. |
| `pairing.rejected.libraryMissing` | Am anderen Gerät ist der Abgleich noch nicht fertig. Bitte gleich noch einmal. |
| `pairing.rejected.differentLibrary` | Der Code passt nicht zu den Daten in diesem OneDrive. |
| `pairing.rejected.needsNewerApp` | Für diesen Code ist eine neuere App-Version nötig. |
| `pairing.invalidCode` | Das ist kein Frontstage-Code. |
| `pairing.done` | Gekoppelt. |

- [ ] **Step 1: Failing Tests schreiben** (Attrappe `FakePairingController`)

```swift
@MainActor @Suite struct PairingFlowModelTests {
  @Test("AK-44: OneDrive-Code scannen, bestätigen → Wechsel mit erwarteter Bibliothek") func scanAndConfirmOneDrive() async
  @Test("AK-44: iCloud-Code stellt auf iCloud um") func scanICloudSwitchesToICloud() async
  @Test("Review Focus 4: Code eines anderen Kontos → rejected, Datenort unverändert") func pairingWithOtherAccountChangesNothing() async
  @Test("Fremder Text → invalidCode, kein Wechsel") func invalidCodeDoesNothing()
  @Test("Eigener Code enthält Datenordner und gekürztes Konto") func ownPayloadFromDataFolder()
  @Test("QR-Bild entsteht für einen Code") func rendererProducesImage()   // QRCodeRenderer.image(for: payload.text, scale: 8) != nil, Breite durch 8 teilbar
}
```

- [ ] **Step 2: Diff durchsehen** – kein Netzzugriff außer über den Controller; Scanner ruft `onCode` nur einmal; `#if os(iOS)`/`#if os(macOS)` vollständig; Kamera nur während der Scanner sichtbar ist.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen**; offene Gestaltungskategorien im Abschlussbericht nennen (Wortlaut, Größe und Ort des Codes, Ablauf beim ersten Start).
- [ ] **Step 5: Commit** – `git commit -m "ui: pair devices via QR code"`

---

### Task 14: Einrichten › Datenort und „Stand des Abgleichs“

Design-Takt: Hauptstufe (vor dem Editieren `apple-design` laden; nur Systemstandard)

**Files:**
- Create: `Frontstage/UI/Setup/DataLocationSettingsViewModel.swift`, `Frontstage/UI/Setup/DataLocationSettingsView.swift`
- Modify: `Frontstage/UI/Setup/SetupView.swift` (Teilplan 04, Task 11/14) – Abschnitt „Datenort“ vor „Ablage“
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/UI/DataLocationSettingsViewModelTests.swift`

**Interfaces:**
- Consumes: `DataLocationController` (Task 12), `PairingSheet` (Task 13), `DataFolderSyncStatus.summary` (Task 6), `MicrosoftAccount.isConfigured` (03)
- Produces:

```swift
@MainActor protocol DataLocationControlling: PairingControlling {
  var isMoving: Bool { get }
  var syncStatus: DataFolderSyncStatus? { get }        // nil bei iCloud
  func runSyncNow() async
}
extension DataLocationController: DataLocationControlling   // syncStatus = folderSync?.status

@MainActor @Observable final class DataLocationSettingsViewModel {
  init(controller: any DataLocationControlling, isOneDriveAvailable: Bool, now: @escaping () -> Date = { .now })
  var location: DataLocation { get }
  var pendingSwitch: DataLocation?        // steuert die Bestätigung vor dem Umzug
  var errorKey: String?
  var isShowingPairing: Bool
  func choose(_ location: DataLocation)   // ungleich aktuell → pendingSwitch
  func confirmSwitch(anchor: AuthPresentationAnchor) async
  func cancelSwitch()
  /// Schlüssel + Argument für die Zeile „Stand des Abgleichs“; nil bei iCloud.
  var statusLine: (key: String, argument: String?)? { get }
}
```

Ansicht (Systemstandard): `Section("setup.dataLocation.title")` mit `Picker` (`.inline`) iCloud / OneDrive (OneDrive nur, wenn `MicrosoftAccount.isConfigured`, sonst ausgeblendet mit Fußzeile); bei OneDrive `LabeledContent` mit gekürztem Konto und „Apps/Frontstage“, Statuszeile als sekundärer Text, Knopf „Jetzt abgleichen“; Knopf „Gerät koppeln“ öffnet `PairingSheet`; `.confirmationDialog` für den Umzug; `ProgressView`, solange `isMoving`. Bei `signInRequired` ein Knopf „Anmelden“ (ruft `switchToOneDrive` erneut auf – holt Zustimmung und Anmeldung nach, ohne Umzug, weil der Datenort schon gilt; im Controller als früher Ausgang: gleicher Datenordner → nur Token erneuern).

Texte (Platzhalter):

| Schlüssel | Wert |
|---|---|
| `setup.dataLocation.title` | Datenort |
| `setup.dataLocation.iCloud` | iCloud |
| `setup.dataLocation.oneDrive` | OneDrive |
| `setup.dataLocation.footer` | Auf allen Geräten muss derselbe Datenort gewählt sein. Material wird nie verändert. |
| `setup.dataLocation.oneDriveUnavailable` | OneDrive ist in dieser Version nicht eingerichtet. |
| `setup.dataLocation.folder` | Ordner in OneDrive |
| `setup.dataLocation.syncNow` | Jetzt abgleichen |
| `setup.dataLocation.pair` | Gerät koppeln |
| `setup.dataLocation.signIn` | Anmelden |
| `setup.dataLocation.confirm.title` | Datenort wechseln? |
| `setup.dataLocation.confirm.message` | Alle Daten werden an den neuen Ort übernommen. Der bisherige Ort bleibt unverändert. |
| `setup.dataLocation.confirm.action` | Wechseln |
| `setup.dataLocation.error.consent` | Ohne Zustimmung in Microsoft kann OneDrive nicht Datenort sein. |
| `sync.status.upToDate %@` | Stand des Abgleichs: %@ |
| `sync.status.syncing` | Stand des Abgleichs: wird abgeglichen … |
| `sync.status.pending %lld` | Stand des Abgleichs: %lld Änderungen warten aufs Schreiben |
| `sync.status.waiting %lld` | Stand des Abgleichs: %lld Einträge warten auf OneDrive |
| `sync.status.offline %lld` | Stand des Abgleichs: offline – %lld Änderungen warten |
| `sync.status.signInRequired` | Stand des Abgleichs: Anmeldung bei Microsoft nötig |
| `sync.status.failed` | Stand des Abgleichs: fehlgeschlagen |
| `sync.status.needsNewerApp` | Stand des Abgleichs: neuere App-Version nötig |
| `sync.status.neverSynced` | Stand des Abgleichs: noch nicht abgeglichen |

`upToDate`: Argument = Uhrzeit, wenn heute (`Date.FormatStyle` `.time(.shortened)`), sonst Datum und Uhrzeit.

- [ ] **Step 1: Failing Tests schreiben** (Attrappe `FakeDataLocationController`)

```swift
@MainActor @Suite struct DataLocationSettingsViewModelTests {
  @Test("FR-14: OneDrive wählen → Bestätigung → Wechsel") func choosingOneDriveConfirmsThenSwitches() async
  @Test("Abbrechen ändert nichts") func cancelKeepsLocation()
  @Test("Zustimmung verweigert → Meldung, Datenort bleibt") func consentErrorSetsErrorKey() async
  @Test("Statuszeile je Zusammenfassung") func statusLineKeys()   // upToDate heute 08:12 → ("sync.status.upToDate %@", "08:12"); offline(pending: 2) → ("sync.status.offline %lld", "2"); iCloud → nil
}
```

- [ ] **Step 2: Diff durchsehen** – Systemstandard; jeder Text über `Localizable.xcstrings`; keine Logik in der Ansicht.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen**; offene Gestaltungskategorien im Abschlussbericht nennen (Wortlaut, Ort der Statuszeile – nur Einrichten oder auch Tagesansicht?, Wahl des Datenorts beim ersten Start).
- [ ] **Step 5: Commit** – `git commit -m "ui: data location setting with sync status line"`

---

### Task 15: CI-Lauf (workflow_dispatch) und Ergebnis prüfen – führt der Controller aus

Design-Takt: keiner

- [ ] **Step 1: Gesamtdiff durchsehen** – `git diff main...HEAD -- Packages Frontstage FrontstageTests project.yml`: `FrontstageCore` importiert nur `Foundation`; Swift 6 strikt (`Sendable` über Akteur-Grenzen, `@unchecked Sendable` nur am Mac-Kamera-Delegaten); `cloudKitDatabase: .none` im OneDrive-Container; jede schreibende Graph-Anfrage über `RemoteLayout.isValidPath`; nur Host `graph.microsoft.com`; `FrontstageApp` enthält alles aus 02–05.
- [ ] **Step 2: Kern lokal** – `.\scripts\swift-test.ps1` → alle Suites grün.
- [ ] **Step 3: Lauf starten** (nach Möglichkeit gemeinsam mit dem nächsten fälligen Teilplan, CI-Sparregeln in `CLAUDE.md`)

```bash
git push -u origin "$(git branch --show-current)"
gh workflow run ci.yml --ref "$(git branch --show-current)"
gh run list --workflow ci.yml --limit 1
gh run watch <run-id> --exit-status
```

Erwartet: Kern-Job grün inkl. `DataFolder Format`, `DataFolder Layout`, `DataFolder RemoteIndex`, `DataFolder Planner`, `DataFolder Incoming`, `DataFolder Join and Status`, `Pairing`; App-Job (iPad-Simulator) grün mit `RecordCodecTests`, `DataLocationSettingsTests`, `OneDriveDataClientTests`, `DataFolderSyncTests`, `DataLocationControllerTests`, `PairingFlowModelTests`, `DataLocationSettingsViewModelTests`; macOS-Ziel baut.

- [ ] **Step 4: Bei Rot** – `gh run view <run-id> --log-failed`, Ursache mit superpowers:systematic-debugging klären, alle Korrekturen sammeln, **ein** neuer Lauf.

---

## Geräte-Checkliste (Mensch mit iPad und Mac, nach Task 15)

| # | Aufbau | Handlung | Erwartet | Ergebnis |
|---|---|---|---|---|
| 1 | **AK-43:** iPad und Mac ohne iCloud-Anmeldung, **privates** Microsoft-Konto | beide: Einrichten › Datenort › OneDrive, anmelden, zustimmen; Mac: Eintrag „Di 2. Std 8b Englisch“, Material zuordnen; iPad: Stiftnotiz auf ein PDF | Eintrag und Zuordnung am iPad, Notiz am Mac nach dem nächsten Abgleich; Material unverändert; in OneDrive unter `Apps/Frontstage` nur Dateien der App | ☐ |
| 2 | wie 1 mit **Schulkonto** (Microsoft 365 der Schule) | dasselbe | wie 1; **Q-33:** läuft Delta auf dem App-Ordner oder der Rückfall „auflisten“ (Konsole, Kategorie `DataFolderSync`)? **Q-34:** kam der Zustimmungsdialog oder „Administrator nötig“? | ☐ Delta ☐ Rückfall ☐ Zustimmung selbst ☐ Admin nötig |
| 3 | **AK-44:** Mac mit OneDrive und Daten; iPad frisch | Mac: „Gerät koppeln“; iPad: „Mit anderem Gerät koppeln“, scannen, anmelden, bestätigen | iPad nutzt denselben Datenordner, Daten vom Mac erscheinen | ☐ |
| 4 | AK-44 (iCloud): Mac mit iCloud | iPad scannt den Code | iPad stellt auf iCloud um | ☐ |
| 5 | AK-44 (Gegenfall): QR-Code eines Geräts mit anderem Microsoft-Konto | scannen, anmelden | Hinweis „anderes Microsoft-Konto“, Datenort unverändert | ☐ |
| 6 | Mac ohne Kamera (oder Kamera abgedeckt/abgelehnt) | „Mit anderem Gerät koppeln“ | Hinweis „am anderen Gerät scannen“, Wahl von Hand möglich | ☐ |
| 7 | beide offline | dieselben Stundenangaben an beiden ändern, dann online | ein Stand gilt (zuletzt geschrieben); keine Datei bleibt doppelt | ☐ |
| 8 | Microsoft in Einrichten abmelden (Teilplan 04) | etwas ändern | Statuszeile „Anmeldung bei Microsoft nötig“, Änderung lokal da; nach Anmelden geschrieben | ☐ |
| 9 | iPad: iCloud mit Daten | Wechsel auf OneDrive; danach zurück auf iCloud | alle Daten bleiben; `Apps/Frontstage` bleibt nach dem Zurückwechseln unverändert | ☐ |

---

## Abdeckung

| Anforderung | Task |
|---|---|
| FR-14 – Wahl iCloud/OneDrive, je Gerät | 1, 9, 12, 14 |
| FR-14 – Abgleich über den Datenordner (App-Ordner), eine Datei je Datensatz, Anhänge daneben | 1–5, 8, 10, 11 |
| FR-14 – Wechsel nimmt alle Daten mit | 6, 12 |
| FR-14.1 – Koppeln per QR-Code, ohne Server | 7, 12, 13 |
| ADR-0012 – Löschmarken 90 Tage, Konflikte je Datensatz, Delta, `Files.ReadWrite`, App-Ordner | 3, 4, 5, 9, 10, 11 |
| Area daten – Nebenläufigkeit, Zusammenführen wie nach iCloud | 5, 11 (ruft `mergeDuplicates()` aus 02) |
| FR-3.4 / NFR-2 – nur in den App-Ordner, nur Graph | 2, 10 |
| RISK-9 – Stand des Abgleichs sichtbar, Anmeldung/Netz | 6, 11, 14; Geräte-Checkliste 2, 8 |
| AK-43, AK-44 | 11, 12, 13 (Datenteil); Geräte-Checkliste 1–6 |

Nicht hier: Stiftnotizen neben dem Dokument (ADR-0011, Teilplan 06); iCloud-Spiegelung (Teilplan 02); Microsoft an/ab in Einrichten (Teilplan 04).

## Produziert für spätere Teilpläne (Zusammenfassung)

- **Kern:** `DataLocation`, `SyncModel`, `RecordPayload` samt acht Inhalts-Strukturen, `AttachmentRef`, `RecordEnvelope`, `DataFolderCoding`, `ContentHash`, `RemoteLayout`, `RemoteEntry`, `LibraryMarker`, `RemoteItem`, `RemoteFile`, `RemoteIndex`, `SyncLedger`, `LedgerEntry`, `LocalRecordState`, `DataFolderPlanner`, `IncomingResolver`, `IncomingResolution`, `ReadOutcome`, `ReadFile`, `DataFolderJoin`, `DataFolderSyncStatus`, `DataFolderSyncSummary`, `PairingPayload`, `PairingVerifier`, `PairingVerdict`.
- **App:** `RecordCodec`, `DataFolder`, `DataLocationSettings`, `DeviceIdentity`, `ModelContainerFactory.makeContainer(for:)`/`makeOneDriveContainer`, `MicrosoftAccount.accessToken(scopes:)`/`requestScopes(_:anchor:)`/`dataLocationScopes`, `DataLocationTokenProvider`, `RemoteDataFolder`, `OneDriveDataClient`, `LedgerStore`, `DataFolderSync`, `DataStore.applyExternalChanges(_:)`, `DataLocationController`, `DataScopedRoot`, `QRCodeRenderer`, `PairingScannerView`, `PairingFlowModel`, `PairingSheet`, `DataLocationSettingsView`.
- **Regel für jeden späteren Teilplan, der ein Modell oder Feld hinzufügt:** `RecordPayload` (Kern) und `RecordCodec` (App) im selben Task ergänzen und den Rundlauf-Test in `RecordCodecTests` erweitern.

## Abstimmungsbedarf

- **Teilpläne 03, 04, 05 (`FrontstageApp`):** `StorageService`, `AppEnvironment`, `TimetableSourceCoordinator` entstehen innerhalb von `DataScopedRoot`, nicht einmalig im `App`-Typ (Übersicht, Abstimmung 15). `MicrosoftAccount` bleibt im `App`-Typ.
- **Teilplan 03 (`MicrosoftAccount`):** zwei neue Methoden (Task 9). `scopes = ["Files.Read"]` bleibt für FR-5.1; die Regel „Die App schreibt nie über Graph“ aus 03 gilt nur noch für Material – in den App-Ordner schreibt Teilplan 08.
- **Teilplan 04 (Einrichten › Ablage, Microsoft an/ab):** Abmelden bei Datenort OneDrive hält den Abgleich an. Vorschlag: Beim Abmelden einen Hinweis zeigen („Datenort OneDrive gleicht dann nicht mehr ab“). Bitte in 04 aufnehmen oder als Design-Runde fahren.
- **Teilplan 07:** `NSCameraUsageDescription` wird geteilt (Tafel-Kamera und Koppeln); wer zuerst baut, legt ihn an, der Text nennt beide Zwecke.
- **Glossar:** „Stand des Abgleichs“ ist Oberflächentext; soll er eine Glossarzeile bekommen (Nähe zu „Stand“ = `sourceFetchedAt`)? Bitte entscheiden.
- **Azure-App-Registrierung:** Für `Files.ReadWrite` muss die Registrierung (Client-ID aus CI-Secret `MSAL_CLIENT_ID`) diese delegierte Berechtigung führen; der Name der Registrierung bestimmt den Ordnernamen `Apps/<Name>` – „Frontstage“ wählen.

## Offene Risiken

1. **Q-33 – Delta bei Schulkonten:** Die Graph-Referenz nennt Delta nur am Wurzelordner. Funktioniert es auf dem App-Ordner nicht, läuft jeder Durchgang über das Auflisten der acht Modellordner – mehr Anfragen, aber korrekt. Am Gerät prüfen (Checkliste 2).
2. **Q-34 – Zustimmung im Schulmandanten:** Sperrt ein Schulträger die Nutzerzustimmung zu `Files.ReadWrite`, bleibt für diese Lehrkräfte nur iCloud. Nicht technisch lösbar; Hinweis in Einrichten (`setup.dataLocation.error.consent`).
3. **Ordner → iCloud → derselbe Datenordner:** Beim erneuten Beitreten gewinnt der Datenordner (Entscheidung 4); in der iCloud-Zeit geänderte Inhalte gleicher Datensätze gehen verloren. Selten; Abhilfe später: Buch beim Verlassen behalten.
4. **Uhren der Geräte:** „zuletzt geschrieben gilt“ vergleicht Gerätezeiten; eine falsch gehende Uhr verliert öfter. Nicht abgefangen (Gerätezeit wird per Netz gestellt).
5. **Gerät länger als 90 Tage nicht geöffnet:** verpasst abgelaufene Löschmarken und behält dort gelöschte Datensätze lokal (nicht zurückgeschrieben, solange es sie nicht ändert).
6. **Ältere App-Version schreibt einen Datensatz mit unbekanntem neuen Feld zurück** und lässt es weg. Abhilfe nur über `formatVersion` bei nicht additiven Änderungen; additive Felder bleiben ein Restrisiko bei gemischten App-Versionen.
7. **`If-Match` beim Hochladen** ist in der Referenz von „Upload small files“ nicht aufgeführt. Wird er ignoriert, überschreibt ein Gerät in einem engen Zeitfenster einen fremden Stand – die Regel „zuletzt geschrieben gilt“ bleibt dabei erfüllt, nur ohne zweite Absicherung.
8. **Umfang beim ersten Durchgang:** `exportAll` lädt auch Zeichnungs- und Bilddaten aller Tafelseiten; bei vielen Tafelbildern dauert der erste Abgleich spürbar (läuft nach dem Anzeigen der Oberfläche, Fortschritt über die Statuszeile).
9. **Kontoname im QR-Code:** nur gekürzt (`l…@example.com`); wer den Bildschirm abfotografiert, erhält Laufwerks- und Ordnerkennung, aber keinen Zugriff ohne Anmeldung am Konto.
