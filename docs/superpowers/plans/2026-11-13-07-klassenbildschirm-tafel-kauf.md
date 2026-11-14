# Teilplan 07 — Klassenbildschirm, Tafel und Kauf

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> Rahmen: `docs/superpowers/plans/2026-11-13-00-uebersicht.md` (insbesondere Abstimmung Punkte 14 und 15).
> **Überarbeitet 2026-11-14:** `ClassroomServices` wird an den `DataStore` des aktuellen Datenorts gebunden (`bind(store:)` aus `ScopedServicesHolder.services(for:)`, Teilplan 04/08) statt einmal beim Start konfiguriert; die Kamera-Berechtigung teilt sich die Tafel mit dem Koppeln per QR-Code (Teilplan 08).

**Goal:** Klassenbildschirm (Verlauf der Stunde, Timer, Arbeitsform; „Dunkel“ liefert Teilplan 06), Tafel (Seiten, Hintergründe, Tafelbild je Unterrichtsstunde, letztes Tafelbild, PDF, Kamera, Vorlage, Abdecken) und den Einmalkauf, der beides freischaltet, bauen.

**Architecture:** Reine Regeln (was der Klassenbildschirm zeigt, Timer aus Endzeitpunkt, letztes Tafelbild, Abdeckung) liegen in `FrontstageCore` und sind dort voll getestet. Die App-Seite hängt Klassenbildschirm und Tafel in die Zweitbildschirm-Szene aus Teilplan 06 ein, speichert Tafelseiten als `BoardPageRecord` (Teilplan 02) und fragt die Freischaltung an genau einer Stelle (`Unlock`, StoreKit 2, ohne Server) ab. Flüchtiges (Timer, Arbeitsform, Abdeckung, Livebild) lebt nur im Speicher.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, PencilKit, PDFKit, AVFoundation (Kamera, Ton), ImageIO, StoreKit 2, StoreKitTest, Swift Testing.

**Spec:** `docs/PRD.md` (FR-11, FR-11.1–FR-11.4, FR-11.7, FR-12–FR-12.7, FR-13; AK-24–AK-28, AK-30–AK-34, AK-36–AK-40, AK-42), `docs/ARCHITECTURE.md` (Area plattform › Kauf, Area anzeige › Zweitbildschirm/Klassenbildschirm/Tafel, Area daten › Tafelseite/Stundenangaben), ADR-0005, ADR-0007, ADR-0009, ADR-0012 (Datenort: Tafelseiten liegen in den App-Daten und werden mit dem gewählten Datenort abgeglichen – iCloud oder OneDrive; die SwiftData-Regeln aus ADR-0002 gelten weiter), `DESIGN.md`. ADR-0011 (Stiftnotizen neben dem Dokument) betrifft Tafelbilder **nicht**. Mockups `mockup/smartboard.html`, `mockup/tafel.html` nur als Veranschaulichung.

## Global Constraints

Es gelten **alle** Zeilen aus `docs/superpowers/plans/2026-11-13-00-uebersicht.md`, Abschnitte „Global Constraints“ und „Gestaltung in den Aufgaben“. Teilplan-eigen kommen hinzu:

- Klassenbildschirm-Ansichten bekommen **nur** einen `ClassScreenDisplay` (Daten der einen Unterrichtsstunde) – nie `Lesson`-Listen, Zuordnungen oder Dateinamen (FR-11).
- **Kein Countdown bis Stundenbeginn** (FR-11.7, vom Nutzer verworfen).
- Timer, Arbeitsform, Abdeckung, Livebild der Kamera: **flüchtig**, nie in SwiftData, nie gespiegelt. Timer rechnet aus einem Endzeitpunkt (`Date`), nie aus gezählten Sekunden.
- Tafelseiten liegen in den App-Daten (`BoardPageRecord`, abgeglichen über den Datenort), nie in der Ablage. Einziger Weg nach außen: PDF über den Teilen-Dialog (FR-12.4). Neue Felder an `BoardPageRecord` bräuchten eine Zeile in `RecordPayload`/`RecordCodec` (Teilplan 08) – dieser Plan fügt keine hinzu.
- **Datenort (Teilplan 08, Übersicht Abstimmung 15):** Alles, was einen `DataStore` hält (`BoardStore`, `BoardSession`), entsteht beim Binden an den aktuellen `DataStore` (`ClassroomServices.bind(store:)`, aufgerufen in `ScopedServicesHolder.services(for:)` im Zweig „neuer Store“, Teilplan 04) und nach jedem Wechsel des Datenorts neu. `Unlock` und `LessonSessionState` hängen nicht am Datenort und bleiben.
- Vorlage (FR-12.6) und Standbild (FR-12.5) werden **einmal als Bild gerendert** und als Hintergrund gespeichert (JPEG, `2400 × 1350` px, Qualität `0.8`); kein Verweis auf die Datei, kein Schreiben in die Ablage.
- Logische Tafelseite: `1600 × 900` pt (16:9); Tablet und Zweitbildschirm skalieren sie einpassend. Alle Strich- und Hintergrundkoordinaten beziehen sich darauf.
- Kaufstand nur aus StoreKit (`Transaction.currentEntitlements`, `Transaction.updates`), nie gespeichert, nie gespiegelt. Nur **verifizierte**, **nicht widerrufene** Transaktionen des einen Produkts schalten frei.
- **Freischaltung (FR-13, Nutzerentscheidung 2026-11-13):** Zum Kauf gehören nur die Anzeige des Klassenbildschirms auf dem Zweitbildschirm (FR-11, FR-11.7, mit Thema und Hinweisen darauf), Timer (FR-11.2), Arbeitsform (FR-11.3) und die Tafel (FR-12 ff.). **Kostenlos** bleiben Material am Zweitbildschirm, „Dunkel“ (`SecondScreenContent.dark`, Teilplan 06) und Eintragen/Anzeigen von Thema, Bereitlegen, Hausaufgabe in Tagesansicht und Vorbereiten (Teilplan 04). Ohne Kauf zeigt der Zweitbildschirm im Ruhezustand eine neutrale Fläche; Timer, Arbeitsform und Tafel zeigen am Tablet ein Kaufangebot.
- **Einhängepunkte (Übersicht, Abstimmung Punkt 8):** Dieser Teilplan ändert **keine** Datei von Teilplan 06. Er füllt nur die Platzhalter, die 06 in seinen Ordnern anlegt und deren Besitzer er ist: `Frontstage/ClassScreen/ClassScreenView.swift` (`ClassScreenView()`), `ClassScreenOverlay.swift` (`ClassScreenOverlay()`), `ClassroomControls.swift` (`ClassroomControls()`), `ClassroomEnvironment.swift` (`classroomEnvironment()`), `Frontstage/Board/BoardView.swift` (`BoardView()`). Namen und `init()` bleiben.
- Platzhalter-Produktkennung `frontstage.classroom` (Non-Consumable, nicht familienfreigebbar); die echte Kennung legt der App-Store-Eintrag fest.
- Stift nur am Tablet (`#if os(iOS)`); am Mac Tafelbilder nur ansehen und als PDF sichern. Kamera nur iOS. Zweitbildschirm-Code nur iOS.
- Offene Gestaltungskategorien (Farben, Schriftgrößen, Symbole der Arbeitsform, Linienabstand, Deckkraft der Abdeckung am Tablet, Wortlaut, Signalton) bekommen den **Systemstandard bzw. den hier genannten Platzhalterwert** und werden im Abschlussbericht je Aufgabe in einer Zeile als Lücke genannt.

Quellen für Apple-APIs, die dieser Plan festlegt (gelesen 2026-11-13):
- StoreKit 2: `Product.purchase()`, `Product.PurchaseResult`, `Transaction.currentEntitlements`, `Transaction.updates`, `revocationDate` – Context7 `/websites/developer_apple_storekit` (developer.apple.com/documentation/storekit).
- StoreKitTest: `SKTestSession(configurationFileNamed:)`, `disableDialogs`, `clearTransactions()`, `buyProduct(identifier:options:) async throws -> Transaction` (iOS 17+), `refundTransaction(identifier: Int)` – Context7 `/websites/developer_apple_storekittest`.
- XcodeGen: Scheme-Option `run.storeKitConfiguration` – Context7 `/yonaskolb/xcodegen` (Docs/ProjectSpec.md).
- PencilKit, PDFKit, AVFoundation, ImageIO, SwiftUI `ImageRenderer`, `ShareLink`/`FileRepresentation`, StoreKit `ProductView`/`onInAppPurchaseCompletion`: aus Apple-Doku bekannt, **nicht** per Context7 belegbar (dort nicht indiziert). Wo eine Signatur unsicher ist, steht im Schritt „beim Bau gegen die Xcode-Doku prüfen“.

## Review Focus

1. **Timer läuft ab, während die App im Hintergrund ist** (Material in PowerPoint offen, FR-5): Bei Rückkehr kein verspätetes Signal; Anzeige steht auf `0:00` mit Ablauf-Kennzeichnung. → Test `signalIsSkippedWhenExpiryLongPast` in Aufgabe 2.
2. **Leere Hausaufgabe in den letzten fünf Minuten:** keine große leere Fläche, sondern Inhalt wie während der Stunde. → Test `finalMinutesWithoutHomeworkFallsBackToLessonContent` in Aufgabe 1.
3. **Doppelstunde** (zwei Unterrichtsstunden derselben Klasse und desselben Fachs an einem Tag): getrennte Tafelbilder je `LessonKey`; „letztes Tafelbild“ in der zweiten zeigt die erste. → Test `previousBoardDrawingWithinSameDayUsesLowerOrdinal` in Aufgabe 3.
4. **Kauf nicht verifiziert, erstattet oder Gerät offline:** unverifiziert/erstattet → gesperrt; offline bleibt ein gekaufter Stand frei (StoreKit liefert zwischengespeicherte Entitlements). → Tests `refundRelocks` (Aufgabe 4) und `unverifiedOrRevokedNeverUnlocks` (Aufgabe 4).
5. **Kamera verweigert oder im Split View gesperrt:** Tafel bleibt voll nutzbar, nur der Kamera-Knopf zeigt den Grund. → Test `cameraAvailabilityMapping` in Aufgabe 13.

---

## Interfaces dieses Teilplans

### Consumes – Teilplan 01 (Kern)

`CalendarDay` (inkl. `init(year:month:day:)`, `init(_:calendar:)`, Comparable), `TimeOfDay` (inkl. `init(hour:minute:)`, `init(_:calendar:)`), `SchoolClass`, `Subject`, `LessonKey` (inkl. `init(date:schoolClass:subject:ordinal:)`, `storageText`, `init?(storageText:)`), `Lesson` (inkl. öffentlichem Initialisierer), `ClassScreenPhase`, `ClassScreenCalculator.phase(now:lessons:finalMinutes:)`.

### Consumes – Teilplan 02 (Daten)

Kern: `LessonInfo` (`topic`, `toPrepare`, `homework`, alle `String?`), `BoardBackground` (`blank`, `lined`, `grid`, `image`), `MaterialReference` (`displayName`, `fileKind`), `MaterialFileKind`. App: `BoardPageRecord` (`id`, `lessonKeyText`, `position`, `backgroundRaw`, `background`, `backgroundImageData`, `drawingData`, `updatedAt`, `createdAt`) und die `DataStore`-Methoden `lessons(on:)`, `lessonInfo(for:)`, `links(for:)` (`.reference` je Zuordnung, für die Vorlage), `boardPages(for:)`, `addBoardPage(for:background:backgroundImageData:)`, `setBoardPageBackground(_:background:imageData:)`, `saveBoardPageDrawing(_:drawingData:)`, `deleteBoardPage(_:)`, `deleteBoardDrawing(for:)`, `lessonKeysWithBoardPages()`; Test-Hilfe `makeStore()`.

### Consumes – Teilplan 03 (Ablage)

`StorageService.reference(forPickedFile:)` und `StorageService.withFileURL(for:_:)` (liest nur lesend mit Ordnerfreigabe, schließt den Zugriff selbst).

### Consumes – Teilplan 04 (Oberfläche Kern)

`AppEnvironment` (`store`, `today`), `DayView`, `LessonDetailView` (`Frontstage/UI/Preparation/LessonDetailView.swift`), `SetupView`, `LessonInfoEditor` (Eingabe von Thema/Bereitlegen/Hausaufgabe – kostenlos, gehört 04). Dieser Teilplan ergänzt in `DayView`, `LessonDetailView` und `SetupView` je einen Knopf bzw. Abschnitt (`Modify`).

### Consumes – Teilplan 06 (Anzeige und Zweitbildschirm)

```swift
enum SecondScreenContent: Hashable, Sendable { case classScreen, material, board, dark }      // Kern
@MainActor @Observable final class SecondScreenState {                                        // parameterloses init
  static let shared: SecondScreenState; init()
  var content: SecondScreenContent { get }; private(set) var isConnected: Bool
  func select(_ content: SecondScreenContent); func toggleDark()
  func setBoardLesson(_ key: LessonKey?); private(set) var boardLessonKey: LessonKey?; func setBoardAvailable(_ available: Bool)
}
struct SecondScreenRootView: View; struct SmartboardBar: View                                  // zeigen die Einhängepunkte unten
struct PenCanvas: UIViewRepresentable { init(drawing: Binding<PKDrawing>, isEditable: Bool, contentSize: CGSize, onStrokeEnded: @escaping () -> Void = {}) }   // nur iOS
// Einhängepunkte – von 06 als Platzhalter angelegt, Besitzer dieser Teilplan, Inhalt hier:
struct ClassScreenView: View { init() }; struct BoardView: View { init() }
struct ClassScreenOverlay: View { init() }; struct ClassroomControls: View { init() }
extension View { func classroomEnvironment() -> some View }
```
„Dunkel“ (FR-11.4) liefert 06 vollständig (`SecondScreenContent.dark`, `toggleDark()`, Knopf in der `SmartboardBar`) – hier nichts dazu.

### Erzeugt von diesem Teilplan (Kern, `Packages/FrontstageCore/Sources/FrontstageCore/`)

```swift
public enum WorkMode: String, CaseIterable, Codable, Sendable { case individual, pairs, groups }            // FR-11.3 (Glossar)

public struct ClassScreenDisplay: Hashable, Sendable {                                                       // FR-11, FR-11.1, FR-11.7
  public enum Kind: Hashable, Sendable { case upcoming, inLesson, finalMinutes, clockOnly }
  public let kind: Kind
  public let schoolClass: String?; public let subject: String?
  public let endTime: TimeOfDay?                 // nur inLesson / finalMinutes
  public let topic: String?; public let toPrepare: String?
  public let homework: String?                   // nur finalMinutes, dann groß
  public let workMode: WorkMode?                 // nie bei clockOnly
}
public enum ClassScreenDisplayBuilder { public static func display(phase: ClassScreenPhase, info: LessonInfo?, workMode: WorkMode?) -> ClassScreenDisplay }

public struct PhaseTimer: Hashable, Sendable {                                                               // FR-11.2
  public enum State: Hashable, Sendable { case idle, running(endDate: Date), paused(remaining: TimeInterval) }
  public private(set) var state: State
  public init()
  public mutating func start(duration: TimeInterval, now: Date)
  public mutating func pause(now: Date)
  public mutating func resume(now: Date)
  public mutating func stop()
  public func remaining(at now: Date) -> TimeInterval?          // nil bei idle; nie < 0
  public func isExpired(at now: Date) -> Bool
  public func shouldPlaySignal(at now: Date, tolerance: TimeInterval = 2) -> Bool
  public static func format(_ remaining: TimeInterval) -> String   // „m:ss“, aufgerundet auf volle Sekunden
}

public enum BoardHistory { public static func previousLessonKey(before key: LessonKey, among keysWithPages: [LessonKey]) -> LessonKey? }   // FR-12.3
public struct BoardCover: Hashable, Sendable {                                                               // FR-12.7
  public enum Audience: Sendable { case tablet, secondScreen }
  public private(set) var revealedFraction: Double              // 0 = ganz verdeckt, 1 = ganz frei; Abdeckung von oben nach unten aufgezogen
  public init(revealedFraction: Double = 0)
  public mutating func reveal(to fraction: Double)              // auf 0…1 begrenzt
  public static func opacity(for audience: Audience) -> Double  // secondScreen 1.0, tablet 0.4 (Platzhalter)
}
public enum UnlockRules { public static func grantsUnlock(productID: String, isVerified: Bool, revocationDate: Date?, unlockProductID: String) -> Bool }   // FR-13
```

### Erzeugt von diesem Teilplan (App)

```swift
// Purchase/
@MainActor @Observable final class Unlock { static let productID = "frontstage.classroom"; private(set) var isUnlocked: Bool; init(listenForUpdates: Bool = true); func refresh() async; func handle(_ result: VerificationResult<Transaction>) async; func restore() async throws }
enum PaidFeature: Sendable { case classScreen, timer, workMode, board }   // FR-13: nur diese vier
struct PaidGate<Content: View>: View { init(_ feature: PaidFeature, @ViewBuilder content: () -> Content) }
struct PurchaseOfferView: View
/// Reine Regel: was ClassScreenView/BoardView am Zweitbildschirm zeigen (06-Dateien bleiben unberührt).
enum SecondScreenRendering: Hashable { case classScreen, neutral, material, board, dark; static func resolve(_ content: SecondScreenContent, isUnlocked: Bool) -> SecondScreenRendering }
/// Ein Bündel für beide Szenen; classroomEnvironment() hängt es an.
/// Der Halter ist shared, weil die Szene des Zweitbildschirms außerhalb des SwiftUI-Baums entsteht (06); was einen DataStore hält,
/// entsteht erst in bind(store:) – aufgerufen innerhalb von DataScopedRoot (08), nach jedem Wechsel des Datenorts erneut.
@MainActor @Observable final class ClassroomServices { static var shared: ClassroomServices { get }; let unlock: Unlock; let session: LessonSessionState
  private(set) var store: DataStore?; private(set) var board: BoardSession?
  func bind(store: DataStore) }   // gleicher Store → nichts; anderer → BoardSession neu, offene Tafel geschlossen
// ClassScreen/
@MainActor @Observable final class LessonSessionState { var timer: PhaseTimer; var workMode: WorkMode?; private(set) var lessonKey: LessonKey?; func lessonDidChange(to key: LessonKey?); func startTimer(minutes: Int, now: Date); func pauseTimer(now: Date); func resumeTimer(now: Date); func stopTimer() }
struct ClassScreenContentView: View { init(display: ClassScreenDisplay, now: Date) }   // reine Darstellung
struct ClassScreenView: View { init() }        // Einhängepunkt aus 06: holt Daten, ohne Kauf neutrale Fläche
struct ClassScreenOverlay: View { init() }     // Einhängepunkt aus 06: Timer-Schicht (PhaseTimerOverlay)
struct ClassroomControls: View { init() }      // Einhängepunkt aus 06: Timer, Arbeitsform in der SmartboardBar
struct PhaseTimerOverlay: View
@MainActor final class TimerSignalPlayer { func play() }
// Board/
@MainActor struct BoardStore { init(store: DataStore); … }             // Aufgabe 8, dünn über DataStore (02)
struct BoardView: View { init() }                                      // Einhängepunkt aus 06: Tafel am Zweitbildschirm
@MainActor @Observable final class BoardSession { … }                   // Aufgabe 9
enum BoardGeometry { static let canvasSize = CGSize(width: 1600, height: 900); static let lineSpacing: CGFloat = 60; static let gridSpacing: CGFloat = 50 }
struct BoardPageSnapshot: Equatable, Sendable { var background: BoardBackground; var backgroundImageData: Data?; var drawingData: Data? }
enum BoardPageRenderer { static func draw(_ page: BoardPageSnapshot, in context: CGContext, size: CGSize) }
enum BoardPDFExporter { static let pageSize = CGSize(width: 842, height: 473.625); static func makePDF(pages: [BoardPageSnapshot]) throws -> Data }
enum TemplateRenderer { static let outputPixelSize = (width: 2400, height: 1350); static func renderPDFPage(at url: URL, pageIndex: Int, crop: CGRect?) throws -> Data; static func renderImage(at url: URL, crop: CGRect?) throws -> Data }
@MainActor @Observable final class CameraFeed { private(set) var latestFrame: CGImage?; private(set) var availability: CameraAvailability; func start() async; func stop(); func stillJPEG() throws -> Data }   // nur iOS
```

## Dateien

| Datei | Verantwortung |
|---|---|
| `Packages/FrontstageCore/Sources/FrontstageCore/ClassScreen/WorkMode.swift` | Arbeitsform |
| `…/ClassScreen/ClassScreenDisplay.swift` | Was der Klassenbildschirm zeigt, aus Phase + Stundenangaben |
| `…/ClassScreen/PhaseTimer.swift` | Timer aus Endzeitpunkt |
| `…/Board/BoardHistory.swift`, `…/Board/BoardCover.swift` | Tafel-Regeln (`BoardBackground` kommt aus Teilplan 02) |
| `…/Purchase/UnlockRules.swift` | Regel „schaltet frei“ |
| `Frontstage/Purchase/Unlock.swift`, `PaidGate.swift`, `PurchaseOfferView.swift` | Freischaltung, Kaufangebot |
| `Frontstage/Resources/Frontstage.storekit` | StoreKit-Konfiguration für Tests und Läufe aus Xcode |
| `Frontstage/ClassScreen/LessonSessionState.swift`, `TimerSignalPlayer.swift` | flüchtiger Zustand der laufenden Unterrichtsstunde, Signalton |
| `Frontstage/ClassScreen/ClassScreenContentView.swift`, `PhaseTimerOverlay.swift` | Klassenbildschirm-Darstellung, Timer-Schicht |
| `Frontstage/ClassScreen/ClassScreenView.swift`, `ClassScreenOverlay.swift`, `ClassroomControls.swift`, `ClassroomEnvironment.swift`, `Frontstage/Board/BoardView.swift` | **Einhängepunkte** (Platzhalter aus 06, Inhalt hier – Modify nur dieser Dateien) |
| `Frontstage/ClassScreen/ClassroomServices.swift`, `SecondScreenRendering.swift` | Bündel für beide Szenen; Abbildung Zustand → Darstellung inkl. Freischaltung |
| `Frontstage/Board/BoardStore.swift`, `BoardSession.swift`, `BoardGeometry.swift`, `BoardPageRenderer.swift` | Tafelseiten speichern, Sitzung, Geometrie, Zeichnen |
| `Frontstage/Board/BoardScreen.swift`, `BoardPageSurface.swift` | Tafel am Tablet/Mac, Seite mit Hintergrund (Tafel am Zweitbildschirm: `BoardView`, Einhängepunkt) |
| `Frontstage/Board/BoardPDFExporter.swift`, `BoardDrawingPDF.swift` | PDF erzeugen, Teilen-Dialog |
| `Frontstage/Board/BoardCoverHandle.swift` | Abdecken am Tablet |
| `Frontstage/Board/TemplateRenderer.swift`, `TemplatePicker.swift` | Vorlage rendern und wählen |
| `Frontstage/Board/CameraFeed.swift`, `CameraAvailability.swift` | Dokumentenkamera |
| Tests: `Packages/FrontstageCore/Tests/FrontstageCoreTests/{ClassScreenDisplayTests,PhaseTimerTests,BoardRulesTests,UnlockRulesTests,CoreFixtures}.swift`, `FrontstageTests/{UnlockTests,LessonSessionStateTests,SecondScreenRenderingTests,BoardStoreTests,BoardSessionTests,BoardPDFExporterTests,BoardCoverRenderingTests,TemplateRendererTests,CameraTests,TestImages}.swift` | |

---

### Task 1: Klassenbildschirm-Inhalt im Kern (FR-11, FR-11.1, FR-11.3, FR-11.7)

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/ClassScreen/WorkMode.swift`
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/ClassScreen/ClassScreenDisplay.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/CoreFixtures.swift`, `…/ClassScreenDisplayTests.swift`

**Interfaces:**
- Consumes: `ClassScreenPhase`, `ClassScreenCalculator.phase(now:lessons:finalMinutes:)`, `Lesson`, `LessonKey`, `LessonInfo` (Teilplan 02), öffentliche Initialisierer (Teilplan 01).
- Produces: `WorkMode`, `ClassScreenDisplay`, `ClassScreenDisplayBuilder.display(phase:info:workMode:)` (s. Interfaces-Block).

- [ ] **Step 1: Fixtures schreiben** – `CoreFixtures.lesson(_ cls: String, _ subject: String, period: Int, from: (Int, Int), to: (Int, Int), on day: CalendarDay = CoreFixtures.tuesday, ordinal: Int = 1, cancelled: Bool = false) -> Lesson` und `CoreFixtures.tuesday = CalendarDay(year: 2026, month: 11, day: 17)`.

- [ ] **Step 2: Failing tests schreiben**

```swift
// Aufbau AK-36: Di 2. Stunde 8b Englisch 8:35–9:20, danach nur ein Ausfall (9c Mathe 5. Stunde)
let lessons = [CoreFixtures.lesson("8b", "Englisch", period: 2, from: (8,35), to: (9,20)),
               CoreFixtures.lesson("9c", "Mathe", period: 5, from: (11,30), to: (12,15), cancelled: true)]
let info = LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: "Buch, Heft", homework: "Workbook S. 34")
func show(_ h: Int, _ m: Int) -> ClassScreenDisplay {
  ClassScreenDisplayBuilder.display(phase: ClassScreenCalculator.phase(now: TimeOfDay(hour: h, minute: m), lessons: lessons), info: info, workMode: nil)
}

@Test("AK-36: 8:31 zeigt „Gleich: 8b Englisch“ und Bereitlegen, ohne Countdown und ohne Ende")
func upcomingShowsNextLessonAndToPrepare() {
  let d = show(8, 31)
  #expect(d.kind == .upcoming); #expect(d.schoolClass == "8b"); #expect(d.subject == "Englisch")
  #expect(d.toPrepare == "Buch, Heft"); #expect(d.endTime == nil); #expect(d.topic == nil); #expect(d.homework == nil)
}
@Test("AK-36/AK-42: 8:40 zeigt Klasse, Fach, Thema, Bereitlegen und „bis 9:20“")
func inLessonShowsTopicToPrepareAndEnd() {
  let d = show(8, 40)
  #expect(d.kind == .inLesson); #expect(d.endTime == TimeOfDay(hour: 9, minute: 20))
  #expect(d.topic == "Unit 4 – Wortschatz"); #expect(d.toPrepare == "Buch, Heft"); #expect(d.homework == nil)
}
@Test("AK-36: 9:16 zeigt die Hausaufgabe groß") func finalMinutesShowsHomework() {
  let d = show(9, 16); #expect(d.kind == .finalMinutes); #expect(d.homework == "Workbook S. 34"); #expect(d.topic == nil)
}
@Test("AK-36: 9:30 nur Uhrzeit und Datum – der Ausfall zählt nicht") func afterLastLessonShowsClockOnly() {
  let d = show(9, 30); #expect(d.kind == .clockOnly); #expect(d.schoolClass == nil); #expect(d.subject == nil); #expect(d.workMode == nil)
}
@Test("AK-25: leeres Bereitlegen erzeugt keine Zeile") func emptyFieldsAreNil() {
  let phase = ClassScreenCalculator.phase(now: TimeOfDay(hour: 8, minute: 40), lessons: lessons)
  let d = ClassScreenDisplayBuilder.display(phase: phase, info: LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: "  ", homework: nil), workMode: nil)
  #expect(d.topic == "Unit 4 – Wortschatz"); #expect(d.toPrepare == nil)
}
@Test("Review Focus 2: letzte fünf Minuten ohne Hausaufgabe zeigen den Inhalt der Stunde")
func finalMinutesWithoutHomeworkFallsBackToLessonContent() {
  let phase = ClassScreenCalculator.phase(now: TimeOfDay(hour: 9, minute: 16), lessons: lessons)
  let d = ClassScreenDisplayBuilder.display(phase: phase, info: LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: "Buch, Heft", homework: ""), workMode: nil)
  #expect(d.kind == .finalMinutes); #expect(d.homework == nil); #expect(d.topic == "Unit 4 – Wortschatz"); #expect(d.toPrepare == "Buch, Heft")
}
@Test("AK-24: nur Daten der laufenden Unterrichtsstunde – keine andere Klasse") func showsOnlyRunningLesson() {
  let two = [CoreFixtures.lesson("8b", "Englisch", period: 2, from: (8,35), to: (9,20)), CoreFixtures.lesson("9c", "Mathe", period: 3, from: (9,25), to: (10,10))]
  let d = ClassScreenDisplayBuilder.display(phase: ClassScreenCalculator.phase(now: TimeOfDay(hour: 8, minute: 40), lessons: two), info: nil, workMode: nil)
  let texts = [d.schoolClass, d.subject, d.topic, d.toPrepare, d.homework].compactMap { $0 }
  #expect(texts == ["8b", "Englisch"])
}
@Test("AK-27: Partnerarbeit wird gezeigt, ohne Auswahl keine") func workModeIsPassedThrough() {
  let phase = ClassScreenCalculator.phase(now: TimeOfDay(hour: 8, minute: 40), lessons: lessons)
  #expect(ClassScreenDisplayBuilder.display(phase: phase, info: nil, workMode: .pairs).workMode == .pairs)
  #expect(ClassScreenDisplayBuilder.display(phase: phase, info: nil, workMode: nil).workMode == nil)
}
```

- [ ] **Step 3: Diff durchsehen** – Tests kompilieren erst nach Step 4; alle verwendeten Kern-Initialisierer sind öffentlich (Teilplan 01, Abstimmung Punkt 1).

- [ ] **Step 4: Implementieren** – `ClassScreenDisplayBuilder.display` nach den Regeln aus den Tests: Texte trimmen (`whitespacesAndNewlines`), leer → `nil`; `schoolClass` = `SchoolClass.normalized`, `subject` = `Subject.display`; `endTime` = `lesson.time?.upperBound`; `workMode` nur bei `kind != .clockOnly`. `///`-Doku deutsch mit Verweis auf FR-11.7.

- [ ] **Step 5: Diff durchsehen** – keine Imports außer `Foundation`; keine Speicherung; Testnamen englisch, Beschreibungen deutsch mit AK.

- [ ] **Step 6: Commit**

```bash
git add Packages/FrontstageCore
git commit -m "feat(core): class screen display rules and work mode (FR-11, FR-11.1, FR-11.3, FR-11.7)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: Timer aus Endzeitpunkt (FR-11.2)

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/ClassScreen/PhaseTimer.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/PhaseTimerTests.swift`

**Interfaces:**
- Produces: `PhaseTimer` (s. Interfaces-Block).

- [ ] **Step 1: Failing tests schreiben**

```swift
let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

@Test("AK-26: 5 Minuten starten zeigt 5:00, nach 1 Minute 4:00") func countsDownFromEndDate() {
  var t = PhaseTimer(); t.start(duration: 300, now: t0)
  #expect(PhaseTimer.format(t.remaining(at: t0)!) == "5:00")
  #expect(PhaseTimer.format(t.remaining(at: t0 + 60)!) == "4:00")
  #expect(PhaseTimer.format(t.remaining(at: t0 + 30.5)!) == "4:30")   // aufgerundet
}
@Test("AK-26: Anhalten bleibt bei 4:00 stehen") func pauseFreezesRemaining() {
  var t = PhaseTimer(); t.start(duration: 300, now: t0); t.pause(now: t0 + 60)
  #expect(PhaseTimer.format(t.remaining(at: t0 + 600)!) == "4:00")
  t.resume(now: t0 + 600); #expect(PhaseTimer.format(t.remaining(at: t0 + 660)!) == "3:00")
}
@Test("AK-26: Beenden zeigt keinen Timer mehr") func stopClearsTimer() {
  var t = PhaseTimer(); t.start(duration: 300, now: t0); t.stop()
  #expect(t.remaining(at: t0 + 1) == nil); #expect(t.state == .idle)
}
@Test("AK-26: Ablauf – Restzeit 0, abgelaufen, Signal fällig") func expiresAtEndDate() {
  var t = PhaseTimer(); t.start(duration: 300, now: t0)
  #expect(t.isExpired(at: t0 + 299) == false); #expect(t.isExpired(at: t0 + 300))
  #expect(t.remaining(at: t0 + 400) == 0); #expect(t.shouldPlaySignal(at: t0 + 300.5))
}
@Test("Review Focus 1: Ablauf liegt länger zurück – kein verspätetes Signal") func signalIsSkippedWhenExpiryLongPast() {
  var t = PhaseTimer(); t.start(duration: 300, now: t0)
  #expect(t.shouldPlaySignal(at: t0 + 303) == false); #expect(t.isExpired(at: t0 + 303))
}
@Test("Angehaltener Timer läuft nie ab") func pausedNeverExpires() {
  var t = PhaseTimer(); t.start(duration: 300, now: t0); t.pause(now: t0 + 10)
  #expect(t.isExpired(at: t0 + 10_000) == false)
}
@Test("Format über eine Stunde: 61:00") func formatsLongDurations() { #expect(PhaseTimer.format(3660) == "61:00") }
```

- [ ] **Step 2: Diff durchsehen** – Tests referenzieren nur die Signaturen aus dem Interfaces-Block.

- [ ] **Step 3: Implementieren** – `remaining` = `max(0, endDate - now)` bzw. gespeicherte Restzeit; `format` rundet mit `.up` auf ganze Sekunden, Minuten nicht auf Stunden umbrechen. `pause`/`resume` aus `idle` sind wirkungslos; `start` überschreibt jeden Zustand.

- [ ] **Step 4: Diff durchsehen** – kein `Timer`, keine Uhr im Typ; `now` kommt immer von außen.

- [ ] **Step 5: Commit** – `git add Packages/FrontstageCore && git commit -m "feat(core): phase timer computed from end date (FR-11.2)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`

### Task 3: Tafel-Regeln im Kern (FR-12.1, FR-12.3, FR-12.7)

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Board/BoardHistory.swift`, `BoardCover.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/BoardRulesTests.swift`

**Interfaces:**
- Consumes: `LessonKey`, `CalendarDay` (Comparable), `SchoolClass`, `Subject` (01). `BoardBackground` legt Teilplan 02 an (samt Test der Rohwerte) – hier nicht.
- Produces: `BoardHistory.previousLessonKey(before:among:)`, `BoardCover` (s. Interfaces-Block).

- [ ] **Step 1: Failing tests schreiben**

```swift
func key(_ d: Int, _ cls: String, _ subj: String = "Englisch", ordinal: Int = 1) -> LessonKey {
  LessonKey(date: CalendarDay(year: 2026, month: 11, day: d), schoolClass: SchoolClass(cls), subject: Subject(subj), ordinal: ordinal)
}
@Test("AK-33: letztes Tafelbild der 8b, nicht das der 8a dazwischen") func previousBoardDrawingSameClassAndSubject() {
  let keys = [key(17, "8b"), key(17, "8a"), key(10, "8b")]
  #expect(BoardHistory.previousLessonKey(before: key(18, "8b"), among: keys) == key(17, "8b"))
}
@Test("Review Focus 3: Doppelstunde – zweite Stunde findet die erste desselben Tages")
func previousBoardDrawingWithinSameDayUsesLowerOrdinal() {
  #expect(BoardHistory.previousLessonKey(before: key(17, "8b", ordinal: 2), among: [key(17, "8b", ordinal: 1), key(17, "8b", ordinal: 2)]) == key(17, "8b", ordinal: 1))
}
@Test("Anderes Fach derselben Klasse zählt nicht; ohne frühere Stunde nil") func previousBoardDrawingIgnoresOtherSubject() {
  #expect(BoardHistory.previousLessonKey(before: key(18, "8b"), among: [key(17, "8b", "Mathe"), key(19, "8b")]) == nil)
}
@Test("AK-39: Abdeckung von oben aufziehen, auf 0…1 begrenzt") func coverRevealsFromTop() {
  var c = BoardCover(); #expect(c.revealedFraction == 0)
  c.reveal(to: 0.34); #expect(c.revealedFraction == 0.34)
  c.reveal(to: 1.7);  #expect(c.revealedFraction == 1)
  c.reveal(to: -0.2); #expect(c.revealedFraction == 0)
}
@Test("AK-39: deckend am Zweitbildschirm, durchscheinend am Tablet") func coverOpacityPerAudience() {
  #expect(BoardCover.opacity(for: .secondScreen) == 1.0); #expect(BoardCover.opacity(for: .tablet) == 0.4)
}
```

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: Implementieren** – `previousLessonKey`: Filter gleiche `schoolClass` und `subject`, streng früher nach `(date, ordinal)`, Maximum davon.
- [ ] **Step 4: Diff durchsehen** – `BoardCover.opacity(.tablet)` als benannte Konstante mit Kommentar „Platzhalter, Design-Runde offen“.
- [ ] **Step 5: Commit** – `feat(core): previous board drawing and cover rules (FR-12.3, FR-12.7)`.

### Task 4: Freischaltung mit StoreKit 2 (FR-13)

**Design-Takt:** voll (`PurchaseOfferView` ist eine neue Oberfläche)

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Purchase/UnlockRules.swift`
- Create: `Frontstage/Purchase/Unlock.swift`, `Frontstage/Purchase/PaidGate.swift`, `Frontstage/Purchase/PurchaseOfferView.swift`
- Create: `Frontstage/Resources/Frontstage.storekit`
- Create: `Frontstage/ClassScreen/SecondScreenRendering.swift`, `Frontstage/ClassScreen/ClassroomServices.swift`
- Modify: `project.yml` (Test-Ziel: Ressource `Frontstage/Resources/Frontstage.storekit`, Abhängigkeit `- sdk: StoreKitTest.framework`; Schema `run.storeKitConfiguration: Frontstage/Resources/Frontstage.storekit`)
- Modify (Einhängepunkt aus 06): `Frontstage/ClassScreen/ClassroomEnvironment.swift` – `classroomEnvironment()` hängt `ClassroomServices.shared.unlock`, `.session`, `.board` und `.store` per `.environment(_:)` an (die optionalen über die Form für `Optional`); 06 ruft es über `secondScreenEnvironment()` in **beiden** Szenen auf – so hat auch die Szene des Zweitbildschirms, die keinen `DataScopedRoot` hat, den aktuellen `DataStore`.
- Modify: `Frontstage/App/ScopedAppContent.swift` (Teilplan 04) – nur in `ScopedServicesHolder.services(for:)`, Zweig „neuer Store“: `ClassroomServices.shared.bind(store: store)`. **Kein** `.task` in `ScopedAppContent`: der Rahmen entsteht einmal je Tab und je `NavigationLink`-Ziel, das Binden liefe mehrfach. `FrontstageApp` bleibt unberührt.
- Modify: `Frontstage/UI/Setup/SetupView.swift` (Abschnitt „Kauf“ mit „Käufe wiederherstellen“)
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/UnlockRulesTests.swift`, `FrontstageTests/UnlockTests.swift`, `FrontstageTests/SecondScreenRenderingTests.swift`, `FrontstageTests/ClassroomServicesTests.swift`

**Interfaces:**
- Consumes: `SecondScreenContent`, `classroomEnvironment()` (Einhängepunkt, Teilplan 06); `SetupView`, `ScopedServicesHolder` (Teilplan 04); `DataScopedRoot` (Teilplan 08, nur mittelbar).
- Produces: `UnlockRules`, `Unlock`, `PaidFeature`, `PaidGate`, `PurchaseOfferView`, `SecondScreenRendering.resolve(_:isUnlocked:)`, `ClassroomServices`.

- [ ] **Step 1: StoreKit-Konfiguration anlegen** – `Frontstage.storekit` (JSON) mit genau einem Produkt: `type: "NonConsumable"`, `productID: "frontstage.classroom"`, `referenceName: "Classroom unlock"`, `familyShareable: false`, `displayPrice: "14.99"`, Lokalisierung `de`: `displayName` „Klassenbildschirm und Tafel“, `description` „Einmalkauf, kein Abo“. Format nach Xcode-Vorlage (`version.major 4`); lässt CI das Laden scheitern, die Datei einmal an einem Mac in Xcode öffnen und speichern.

- [ ] **Step 2: Failing tests schreiben**

```swift
// Kern
@Test("Nur verifizierte, nicht widerrufene Transaktion des Produkts schaltet frei") func unverifiedOrRevokedNeverUnlocks() {
  let id = "frontstage.classroom"
  #expect(UnlockRules.grantsUnlock(productID: id, isVerified: true, revocationDate: nil, unlockProductID: id))
  #expect(!UnlockRules.grantsUnlock(productID: id, isVerified: false, revocationDate: nil, unlockProductID: id))
  #expect(!UnlockRules.grantsUnlock(productID: id, isVerified: true, revocationDate: Date(), unlockProductID: id))
  #expect(!UnlockRules.grantsUnlock(productID: "other", isVerified: true, revocationDate: nil, unlockProductID: id))
}

// App – import StoreKitTest; SKTestSession teilt eine Umgebung, daher seriell
@Suite(.serialized) @MainActor struct UnlockTests {
  let session: SKTestSession
  init() throws { session = try SKTestSession(configurationFileNamed: "Frontstage"); session.disableDialogs = true; session.clearTransactions() }
  @Test("AK-40: ohne Kauf gesperrt") func lockedWithoutPurchase() async {
    let u = Unlock(listenForUpdates: false); await u.refresh(); #expect(u.isUnlocked == false)
  }
  @Test("AK-40: nach dem Kauf frei, ohne Ablaufdatum") func unlockedAfterPurchase() async throws {
    let t = try await session.buyProduct(identifier: Unlock.productID)
    #expect(t.expirationDate == nil)
    let u = Unlock(listenForUpdates: false); await u.refresh(); #expect(u.isUnlocked)
  }
  @Test("Review Focus 4: Erstattung sperrt wieder") func refundRelocks() async throws {
    let t = try await session.buyProduct(identifier: Unlock.productID)
    try session.refundTransaction(identifier: Int(t.id))
    let u = Unlock(listenForUpdates: false); await u.refresh(); #expect(u.isUnlocked == false)
  }
}

@Test("AK-40: ohne Kauf neutrale Fläche statt Klassenbildschirm, Material und Dunkel bleiben frei") func secondScreenRenderingRespectsUnlock() {
  #expect(SecondScreenRendering.resolve(.classScreen, isUnlocked: false) == .neutral)
  #expect(SecondScreenRendering.resolve(.material, isUnlocked: false) == .material)
  #expect(SecondScreenRendering.resolve(.board, isUnlocked: false) == .neutral)
  #expect(SecondScreenRendering.resolve(.dark, isUnlocked: false) == .dark)
  #expect(SecondScreenRendering.resolve(.classScreen, isUnlocked: true) == .classScreen)
}

@MainActor @Test("Übersicht Abstimmung 15: Wechsel des Datenorts bindet die Tafel an den neuen DataStore") func bindReplacesBoardOnNewStore() throws {
  let services = ClassroomServices(unlock: Unlock(listenForUpdates: false))   // interner init für Tests
  let a = try makeStore(), b = try makeStore()
  services.bind(store: a); let boardA = services.board
  services.bind(store: a); #expect(services.board === boardA)                // gleicher Store → unverändert
  services.bind(store: b); #expect(services.board !== boardA && services.store === b)
}
```

- [ ] **Step 3: Diff durchsehen.**

- [ ] **Step 4: Implementieren**
  - `Unlock.refresh()`: über `Transaction.currentEntitlements` iterieren; `isUnlocked` = irgendein Ergebnis mit `UnlockRules.grantsUnlock(…)` (`.verified` → `isVerified: true`, `.unverified` → `false`).
  - `init(listenForUpdates:)`: bei `true` einen `Task` starten, der `for await result in Transaction.updates { await handle(result) }` läuft (`[weak self]`), dann `Task { await refresh() }`.
  - `handle(_:)`: bei `.verified` `await transaction.finish()`, danach `await refresh()` (Widerruf kommt so ebenfalls an).
  - `restore()`: `try await AppStore.sync()`, danach `refresh()`.
  - `PurchaseOfferView`: StoreKit-`ProductView(id: Unlock.productID)` (Systemdarstellung, kein eigenes Design) plus Knopf „Käufe wiederherstellen“; `.onInAppPurchaseCompletion { _, result in if case .success(.success(let v)) = result { await unlock.handle(v) } }` – Signatur beim Bau gegen die Xcode-Doku prüfen. Hinweistext „Einmalkauf, kein Abo, auf allen Geräten derselben Apple-ID“ (Wortlaut Platzhalter).
  - `PaidGate`: zeigt `content` bei `unlock.isUnlocked`, sonst `PurchaseOfferView`. Nur für `PaidFeature` (Klassenbildschirm, Timer, Arbeitsform, Tafel); nie um Material, „Dunkel“ oder Stundenangaben.
  - `ClassroomServices.shared` legt `Unlock(listenForUpdates: true)` und `LessonSessionState(signal: TimerSignalPlayer())` einmal an. `bind(store:)`: anderer Store als bisher → `BoardSession(store: BoardStore(store: store), secondScreen: .shared)` neu, `store` setzen, `SecondScreenState.shared.setBoardLesson(nil)` (eine offene Tafel des alten Datenorts schließen); gleicher Store → nichts. Aufgerufen nur aus `ScopedServicesHolder.services(for:)` (Teilplan 04/08) – nie aus dem `App`-Typ; Teilplan 04/06 bleiben sonst unberührt. `classroomEnvironment()` hängt `unlock`, `session`, `board` und `store` per `.environment(_:)` an. Ansichten, die `board` oder `store` brauchen, zeigen bei `nil` die neutrale Fläche (nur kurz beim Start, bevor gebunden ist). Swift-Hinweis: Gelesen wird in der optionalen Form `@Environment(BoardSession.self) private var board: BoardSession?` bzw. `@Environment(DataStore.self) private var store: DataStore?` – die nicht-optionale Form bricht zur Laufzeit ab, wenn das Objekt fehlt. Das gilt für `ClassScreenView` (Task 6) und `BoardView`/`BoardScreen` (Task 9) ebenso.
- [ ] **Step 5: Texte** in `Localizable.xcstrings`: `purchase.offer.title` = „Klassenbildschirm und Tafel freischalten“, `purchase.offer.note` = „Einmalkauf, kein Abo – gilt auf allen Geräten mit derselben Apple-ID.“, `purchase.restore` = „Käufe wiederherstellen“, `purchase.restore.failed` = „Wiederherstellen ist fehlgeschlagen.“, `secondScreen.neutral.accessibility` = „Kein Inhalt“.
- [ ] **Step 6: Diff durchsehen** – Kaufstand nirgends in SwiftData/`UserDefaults`; keine Netzwerkaufrufe außer StoreKit (NFR-2); `.storekit` nur in Test-Ziel und Schema, nicht in der App-Ressourcenliste.
- [ ] **Step 7: Prüfung mit `apple-design`** (Design-Takt voll) auf `PurchaseOfferView`; Lücken (Wortlaut, Anordnung) im Bericht nennen.
- [ ] **Step 8: Commit** – `feat(purchase): one-time unlock with StoreKit 2 and purchase offer (FR-13)`.

### Task 5: Flüchtiger Zustand der Unterrichtsstunde und Signalton (FR-11.2, FR-11.3)

**Files:**
- Create: `Frontstage/ClassScreen/LessonSessionState.swift`, `Frontstage/ClassScreen/TimerSignalPlayer.swift`
- Test: `FrontstageTests/LessonSessionStateTests.swift`

„Dunkel“ (FR-11.4) baut Teilplan 06 vollständig (`SecondScreenContent.dark`, `toggleDark()`); dieser Teilplan ändert dort nichts. `LessonSessionState` kommt über `ClassroomServices.shared` und `classroomEnvironment()` (Task 4) in beide Szenen – ohne weitere Änderung an `FrontstageApp`.

**Interfaces:**
- Consumes: `PhaseTimer`, `WorkMode`.
- Produces: `LessonSessionState` (s. Interfaces-Block), `TimerSignalPlayer.play()`.

- [ ] **Step 1: Failing tests schreiben**

```swift
@MainActor @Suite struct LessonSessionStateTests {
  let a = LessonKey(date: CalendarDay(year: 2026, month: 11, day: 17), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
  let b = LessonKey(date: CalendarDay(year: 2026, month: 11, day: 17), schoolClass: SchoolClass("9c"), subject: Subject("Mathe"), ordinal: 1)
  @Test("Arbeitsform gilt nur für die laufende Unterrichtsstunde") func workModeResetsOnLessonChange() {
    let s = LessonSessionState(signal: nil); s.lessonDidChange(to: a); s.workMode = .pairs
    s.lessonDidChange(to: a); #expect(s.workMode == .pairs)
    s.lessonDidChange(to: b); #expect(s.workMode == nil)
  }
  @Test("Laufender Timer überdauert den Stundenwechsel") func timerSurvivesLessonChange() {
    let s = LessonSessionState(signal: nil); let now = Date()
    s.lessonDidChange(to: a); s.startTimer(minutes: 5, now: now); s.lessonDidChange(to: b)
    #expect(s.timer.remaining(at: now) == 300)
  }
}
```

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: Implementieren**
  - `LessonSessionState(signal: TimerSignalPlayer?)`: `startTimer` setzt `timer.start(duration: minutes*60, now:)` und plant einen `Task`, der bis `endDate` schläft (`Task.sleep(until:)` mit `ContinuousClock` ist nicht an `Date` gebunden – daher `Task.sleep(for: .seconds(endDate.timeIntervalSinceNow))`), danach `if timer.shouldPlaySignal(at: .now) { signal?.play() }`. `pause`/`stop` brechen den Task ab; `resume` plant neu.
  - Kehrt die App zurück (`scenePhase == .active`), wird nicht nachgespielt – Review Focus 1 hält `shouldPlaySignal` dafür.
  - `TimerSignalPlayer`: `AVAudioEngine` + `AVAudioPlayerNode` mit einem selbst erzeugten `AVAudioPCMBuffer` (Sinus 880 Hz, drei Töne je 0,3 s mit 0,2 s Pause, Platzhalter); unter iOS vorher `AVAudioSession.sharedInstance().setCategory(.playback)` und `setActive(true)`, damit der Ton auch bei Stummschalter und über AirPlay am Bildschirm im Klassenraum kommt (Area anzeige › Klassenbildschirm). Keine Tondatei im Repo.
- [ ] **Step 4: Diff durchsehen** – Swift 6: `LessonSessionState` und `TimerSignalPlayer` `@MainActor`; der Sleep-`Task` erbt den MainActor; kein `Timer.scheduledTimer`.
- [ ] **Step 5: Commit** – `feat(class-screen): ephemeral lesson session and timer signal (FR-11.2, FR-11.3)`.

### Task 6: Klassenbildschirm am Zweitbildschirm mit Timer-Schicht (FR-11, FR-11.1, FR-11.2, FR-11.7)

**Design-Takt:** voll (neue Oberfläche, für die Klasse sichtbar)

**Files:**
- Create: `Frontstage/ClassScreen/ClassScreenContentView.swift`, `PhaseTimerOverlay.swift`
- Modify (Einhängepunkte aus 06, Besitzer dieser Teilplan): `Frontstage/ClassScreen/ClassScreenView.swift` – `ClassScreenView()` zeigt über `SecondScreenRendering.resolve(.classScreen, isUnlocked:)` den Klassenbildschirm oder ohne Kauf die neutrale Fläche (FR-13, AK-40); `Frontstage/ClassScreen/ClassScreenOverlay.swift` – `ClassScreenOverlay()` = `PhaseTimerOverlay()` oben rechts, ohne Kauf leer. `SecondScreenRootView` (06) bleibt unverändert; sie legt die Schicht nie über `.dark`.
- Modify: `Frontstage/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `ClassScreenDisplayBuilder`, `ClassScreenCalculator`, `CalendarDay(_:calendar:)`, `TimeOfDay(_:calendar:)` (01); `DataStore.lessons(on:)`, `.lessonInfo(for:)`, `.revision` (02); `LessonSessionState`, `Unlock` (über `classroomEnvironment()`).
- Produces: `ClassScreenContentView(display:now:)`, Inhalt von `ClassScreenView()` und `ClassScreenOverlay()`, `PhaseTimerOverlay`.

- [ ] **Step 1: `ClassScreenView()` füllen** – `TimelineView(.periodic(from: .now, by: 1))`; Unterrichtsstunden des Tages über `DataStore.lessons(on:)` nur neu berechnen, wenn sich Tag, Minute oder `DataStore.revision` ändern (Änderungen, auch gespiegelte, kommen über `revision` an – AK-25); Stundenangaben über `DataStore.lessonInfo(for:)`. Die Phase-`Lesson` meldet ihren Schlüssel an `LessonSessionState.lessonDidChange(to:)` (`.onChange`). Weitergereicht an `ClassScreenContentView` wird **nur** der `ClassScreenDisplay`. Ohne Kauf: neutrale Fläche (Systemhintergrund), keine Daten.
- [ ] **Step 2: `ClassScreenContentView(display:now:)`** – zeigt je `kind`: `upcoming` „Gleich:“ + Klasse + Fach + Bereitlegen; `inLesson` Klasse, Fach, „bis HH:mm“, Thema, Bereitlegen; `finalMinutes` Hausaufgabe groß (fehlt sie, wie `inLesson`); `clockOnly` Uhrzeit und Datum. Uhrzeit immer sichtbar (AK-24). Arbeitsform als `Label(text, systemImage:)` mit Platzhalter-Symbolen `person` / `person.2` / `person.3`. Leere Felder erzeugen keine Zeile. Schriftgrößen: Systemstile (`.largeTitle` u. a.), Lücke melden.
- [ ] **Step 3: `PhaseTimerOverlay`** – liest `LessonSessionState.timer`; bei `idle` nichts; sonst Restzeit `PhaseTimer.format` groß; abgelaufen → `0:00` plus Text „Zeit ist um“ (statisch, nicht nur Bewegung – DESIGN.md „Wiederkehrende Fallen“); eigene `TimelineView(.periodic(by: 1))`.
- [ ] **Step 4: Texte**: `classScreen.upcoming` = „Gleich:“, `classScreen.until %@` = „bis %@“, `classScreen.toPrepare %@` = „Bereitlegen: %@“, `classScreen.homework %@` = „Hausaufgabe: %@“, `workMode.individual` = „Einzelarbeit“, `workMode.pairs` = „Partnerarbeit“, `workMode.groups` = „Gruppenarbeit“, `timer.expired` = „Zeit ist um“.
- [ ] **Step 5: Diff durchsehen** – `ClassScreenContentView` hat keine Parameter außer `display` und `now`; keine Datei von Teilplan 06 im Diff; kein `Button` in Zweitbildschirm-Views; keine Dateinamen.
- [ ] **Step 6: Prüfung mit `apple-design`** (Lesbarkeit aus Entfernung, Kontrast, Dynamic Type); Lücken nennen (Farbe, Größen, Symbole, Wortlaut).
- [ ] **Step 7: Commit** – `feat(class-screen): class screen on second screen with timer overlay (FR-11, FR-11.7)`.

### Task 7: Bedienung am Tablet – Timer und Arbeitsform (FR-11.2, FR-11.3)

**Design-Takt:** Hauptstufe

**Files:**
- Modify (Einhängepunkt aus 06, Besitzer dieser Teilplan): `Frontstage/ClassScreen/ClassroomControls.swift` – `ClassroomControls()` füllen; `SmartboardBar` (06) zeigt es bereits.
- Modify: `Frontstage/Resources/Localizable.xcstrings`

Thema, Bereitlegen und Hausaufgabe trägt die Lehrkraft kostenlos mit `LessonInfoEditor` aus Teilplan 04 (Vorbereiten, Tagesansicht) ein; „Dunkel“ schaltet die `SmartboardBar` aus 06 – beides gehört nicht hierher (Nutzerentscheidung 2026-11-13).

**Interfaces:**
- Consumes: `LessonSessionState`, `PaidGate` (Task 4/5).
- Produces: Inhalt von `ClassroomControls()`.

- [ ] **Step 1: `ClassroomControls`**: Timer in `PaidGate(.timer)` – Dauer per `Stepper` in Minuten (1…60, Vorgabe 5, zuletzt verwendet im flüchtigen Zustand), Start/Anhalten/Weiter/Beenden; Arbeitsform in `PaidGate(.workMode)` – `Picker` mit „Keine“ + drei Fällen. Ohne Kauf ein kompakter Hinweis mit Kaufangebot statt der Knöpfe. Alles am Tablet, nichts davon am Zweitbildschirm.
- [ ] **Step 2: Texte**: `timer.title` = „Timer“, `timer.start` = „Starten“, `timer.pause` = „Anhalten“, `timer.resume` = „Weiter“, `timer.stop` = „Beenden“, `timer.minutes %lld` = „%lld Minuten“, `workMode.title` = „Arbeitsform“, `workMode.none` = „Keine“.
- [ ] **Step 3: Diff durchsehen** – keine Datei von Teilplan 06 außer dem Einhängepunkt im Diff.
- [ ] **Step 4: Commit** – `feat(class-screen): tablet controls for timer and work mode (FR-11.2, FR-11.3)`.

### Task 8: Tafelseiten speichern (FR-12.1, FR-12.2, FR-12.3)

**Files:**
- Create: `Frontstage/Board/BoardStore.swift`
- Test: `FrontstageTests/BoardStoreTests.swift`

**Interfaces:**
- Consumes: `BoardPageRecord`, `BoardBackground`, `DataStore.boardPages(for:)`, `.addBoardPage(for:background:backgroundImageData:)`, `.setBoardPageBackground(_:background:imageData:)`, `.saveBoardPageDrawing(_:drawingData:)`, `.deleteBoardPage(_:)`, `.deleteBoardDrawing(for:)`, `.lessonKeysWithBoardPages()` (Teilplan 02); `BoardHistory` (Task 3).
- Produces (dünne Hülle über dem einzigen Datenzugang `DataStore`, Übersicht Abstimmung Punkt 4):

```swift
@MainActor struct BoardStore {
  init(store: DataStore)
  func pages(for key: LessonKey) throws -> [BoardPageRecord]        // = store.boardPages(for:)
  @discardableResult func addPage(for key: LessonKey, background: BoardBackground, backgroundImageData: Data? = nil) throws -> BoardPageRecord
  func setBackground(_ background: BoardBackground, imageData: Data?, of page: BoardPageRecord) throws
  func saveDrawing(_ data: Data, to page: BoardPageRecord) throws
  func deleteBoardDrawing(for key: LessonKey) throws                // alle Seiten dieser Unterrichtsstunde
  /// FR-12.3: store.lessonKeysWithBoardPages() → BoardHistory.previousLessonKey(before:among:).
  func previousBoardDrawingKey(before key: LessonKey) throws -> LessonKey?
}
```

- [ ] **Step 1: Failing tests schreiben** (Container auf Datei im temporären Ordner mit `ModelContainerFactory.modelTypes` und `ModelConfiguration(url:cloudKitDatabase: .none)` aus Teilplan 02, `DataStore(modelContext:)` darauf, damit ein „Neustart“ prüfbar ist)

```swift
@MainActor @Suite struct BoardStoreTests {
  let tue8b = LessonKey(date: CalendarDay(year: 2026, month: 11, day: 17), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
  func dataStore(_ url: URL) throws -> DataStore {
    let schema = Schema(ModelContainerFactory.modelTypes)
    return DataStore(modelContext: ModelContext(try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))))
  }

  @Test("AK-31: neue Seite kariert und leer, Seite 1 unverändert") func addPageKeepsFirstPage() throws {
    let store = BoardStore(store: try dataStore(.temporaryDirectory.appending(path: UUID().uuidString + ".store")))
    let p1 = try store.addPage(for: tue8b, background: .blank); try store.saveDrawing(Data([1, 2, 3]), to: p1)
    try store.addPage(for: tue8b, background: .grid)
    let pages = try store.pages(for: tue8b)
    #expect(pages.count == 2); #expect(pages[1].backgroundRaw == "grid"); #expect(pages[1].drawingData == nil)
    #expect(pages[0].drawingData == Data([1, 2, 3]))
  }
  @Test("AK-32: zwei Seiten überstehen den Neustart; Löschen leert die Tafel") func boardDrawingPersistsAndDeletes() throws {
    let url = URL.temporaryDirectory.appending(path: UUID().uuidString + ".store")
    do { let s = BoardStore(store: try dataStore(url)); try s.addPage(for: tue8b, background: .blank); try s.addPage(for: tue8b, background: .lined) }   // DataStore speichert in addBoardPage
    let s2 = BoardStore(store: try dataStore(url))
    #expect(try s2.pages(for: tue8b).count == 2)
    try s2.deleteBoardDrawing(for: tue8b); #expect(try s2.pages(for: tue8b).isEmpty)
  }
  @Test("AK-33: letztes Tafelbild über gespeicherte Seiten") func previousKeyFromStoredPages() throws { /* Seiten für Di 8b, Di 8a (6. Stunde) anlegen; Mi 8b fragt → Di 8b */ }
  @Test("Gleiche Position von zwei Geräten: Reihenfolge nach Anlagezeit") func equalPositionsSortByCreation() throws { /* zwei Datensätze position 1, createdAt t und t+1 → Reihenfolge t, t+1 */ }
}
```

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: Implementieren** – jede Methode ruft genau die genannte `DataStore`-Methode (Sortierung, Speichern und Schlüssel-Rückwandlung liegen dort); `previousBoardDrawingKey`: `Array(store.lessonKeysWithBoardPages())` → `BoardHistory.previousLessonKey`.
- [ ] **Step 4: Diff durchsehen** – kein direkter `ModelContext`-Zugriff außerhalb der Test-Hilfe; kein `#Unique`.
- [ ] **Step 5: Commit** – `feat(board): board page store per lesson (FR-12.1–FR-12.3)`.

### Task 9: Tafel am Tablet, am Mac und am Zweitbildschirm (FR-12, FR-12.1, FR-12.2, FR-12.3)

**Design-Takt:** voll (neue Oberfläche)

**Files:**
- Create: `Frontstage/Board/BoardGeometry.swift`, `BoardPageRenderer.swift`, `BoardSession.swift`, `BoardScreen.swift`, `BoardPageSurface.swift`
- Modify (Einhängepunkt aus 06, Besitzer dieser Teilplan): `Frontstage/Board/BoardView.swift` – `BoardView()` zeigt die aktuelle Seite aus `BoardSession` ohne Bedienelemente; ohne Kauf neutrale Fläche (`SecondScreenRendering.resolve(.board, isUnlocked:)`). `SecondScreenRootView` (06) bleibt unverändert.
- Modify: `Frontstage/UI/DayView/DayView.swift` (Teilplan 04): Knopf „Tafel“ je `LessonRow` öffnet `BoardScreen(lessonKey:)` als Vollbild-Cover (iOS) bzw. Fenster-Sheet (macOS), in `PaidGate(.board)`; `Frontstage/UI/Preparation/LessonDetailView.swift` (Teilplan 04): Tafelbilder der Stunde ansehen und als PDF sichern (Aufgabe 10)
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/BoardSessionTests.swift`, `FrontstageTests/BoardTestSupport.swift` (`tue8b`, `wed8b`, `tue8a` als `LessonKey`; `@MainActor func makeSession() throws -> (BoardSession, SecondScreenState)` mit `makeStore()` aus Teilplan 02 und `SecondScreenState()`; auch von Aufgaben 10 und 13 genutzt)

`BoardSession` kommt über `ClassroomServices.shared` (gebunden an den aktuellen `DataStore`, Task 4) und `classroomEnvironment()` in beide Szenen; keine weitere Änderung an `FrontstageApp` oder `ScopedAppContent`.

**Interfaces:**
- Consumes: `BoardStore`, `PenCanvas`, `SecondScreenState.select(_:)`, `.setBoardLesson(_:)`, `.setBoardAvailable(_:)` (06), `BoardBackground` (02), `BoardCover`.
- Produces:

```swift
@MainActor @Observable final class BoardSession {
  enum Mode: Equatable { case closed, own(LessonKey), previous(own: LessonKey, shown: LessonKey) }   // previous = nur ansehen
  private(set) var mode: Mode
  private(set) var pages: [BoardPageSnapshot]; private(set) var pageIndex: Int
  var liveDrawing: PKDrawing                // Spiegel für den Zweitbildschirm
  var cover: BoardCover?                     // Aufgabe 11
  var isCameraLive: Bool                     // Aufgabe 13
  init(store: BoardStore, secondScreen: SecondScreenState)
  func open(_ key: LessonKey) throws         // legt Seite 1 (blank) an, wenn keine existiert; setBoardLesson(key), setBoardAvailable(true), select(.board)
  func close() throws                        // speichert sofort; setBoardAvailable(false) → 06 fällt auf .classScreen zurück
  func addPage(background: BoardBackground, imageData: Data? = nil) throws
  func setBackground(_ background: BoardBackground) throws
  func goToPage(_ index: Int)                // speichert vorher, setzt cover = nil
  func drawingChanged(_ drawing: PKDrawing)  // spiegelt sofort, speichert 1 s nach dem letzten Strich
  func showPreviousBoardDrawing() throws     // FR-12.3; ohne frühere: Fehler .noPreviousBoardDrawing
  func returnToOwnBoard() throws
  func deleteBoardDrawing() throws           // nur in .own; danach eine leere Seite 1
  func flush() throws
}
```

- [ ] **Step 1: Failing tests schreiben**

```swift
@MainActor @Suite struct BoardSessionTests {
  @Test("AK-30: ein Tipp öffnet die Tafel und schaltet den Zweitbildschirm auf Tafel") func openShowsBoardOnSecondScreen() throws {
    let (session, screen) = try makeSession()   // In-Memory-Container, SecondScreenState()
    try session.open(tue8b)
    #expect(screen.content == .board); #expect(session.pages.count == 1); #expect(session.pages[0].background == .blank)
    try session.close(); #expect(screen.content == .classScreen)
  }
  @Test("AK-33: letztes Tafelbild zeigt Di 8b, nur ansehen") func previousBoardDrawingIsReadOnly() throws {
    // Seiten für Di 8b und Di 8a anlegen; Mi 8b öffnen; showPreviousBoardDrawing()
    #expect(session.mode == .previous(own: wed8b, shown: tue8b))
  }
  @Test("AK-32: Tafelbild löschen hinterlässt leere Tafel") func deleteLeavesEmptyFirstPage() throws {
    // zwei Seiten, deleteBoardDrawing → pages.count == 1, drawingData == nil
  }
  @Test("Seitenwechsel hebt die Abdeckung auf") func pageChangeClearsCover() throws {
    // cover = BoardCover(revealedFraction: 0.3); goToPage(0) → cover == nil
  }
}
```

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: Implementieren**
  - `BoardGeometry`: Werte aus dem Interfaces-Block (Platzhalter: Linien-/Kästchenabstand, Linienfarbe `.secondary`), `func lines(for: BoardBackground, in size: CGSize) -> [(CGPoint, CGPoint)]` – skaliert aus der logischen Seite; gemeinsam von SwiftUI-`Canvas` und PDF genutzt.
  - `BoardPageRenderer.draw(_:in:size:)`: Weiß füllen, Linien, ggf. Hintergrundbild (`CGImageSource` aus `backgroundImageData`, einpassend), dann Zeichnung: `PKDrawing(data:)` → `image(from: CGRect(origin: .zero, size: BoardGeometry.canvasSize), scale:)` → `CGImage` (iOS `.cgImage`, macOS `cgImage(forProposedRect:context:hints:)`). Unlesbare Zeichnungsdaten: Seite ohne Zeichnung zeichnen, nie abstürzen.
  - `BoardPageSurface(page:drawing:cover:audience:)`: Hintergrund (`Canvas`) + Zeichnung; am Tablet darüber `PenCanvas` (iOS, `isEditable` nur in `.own`), am Mac und am Zweitbildschirm das gerenderte Bild. Seitenverhältnis 16:9, einpassend.
  - `BoardScreen` (Tablet/Mac): Seitenleiste „Seite n von m“, blättern, „Seite hinzufügen“ mit Hintergrundwahl (Leer/Liniert/Kariert), Hintergrund der aktuellen Seite ändern, „Letztes Tafelbild“, „Tafelbild löschen“ (Bestätigung), PencilKit-Werkzeugleiste (Stift, Radierer, Farben aus `PKToolPicker`) – das genügt FR-12 „Radierer und einige Farben“ ohne eigene Farbwahl.
  - `BoardView()` (Einhängepunkt): aktuelle Seite aus `BoardSession` ohne Bedienelemente; `liveDrawing` für Echtzeit; Abdeckung deckend (Aufgabe 11); Livebild bei `isCameraLive` (Aufgabe 13).
  - Am Mac: kein `PenCanvas`, `isEditable == false`, Bedienung auf Blättern, PDF, Löschen beschränkt (Area anzeige › Tafel).
- [ ] **Step 4: Texte**: `board.title` = „Tafel“, `board.page %lld %lld` = „Seite %lld von %lld“, `board.addPage` = „Seite hinzufügen“, `board.background.blank` = „Leer“, `board.background.lined` = „Liniert“, `board.background.grid` = „Kariert“, `board.previous` = „Letztes Tafelbild“, `board.previous.none` = „Kein früheres Tafelbild dieser Klasse in diesem Fach“, `board.backToOwn` = „Zurück zur Tafel dieser Stunde“, `board.delete` = „Tafelbild löschen“, `board.delete.confirm` = „Alle Seiten dieser Unterrichtsstunde löschen?“.
- [ ] **Step 5: Diff durchsehen** – `#if os(iOS)` um PencilKit-Zeichenfläche; Speichern sicher beim Schließen (`close`, `scenePhase` → `.background` ruft `flush`).
- [ ] **Step 6: Prüfung mit `apple-design`**; Lücken nennen (Linienfarbe/-abstand, Anordnung der Leiste, Wortlaut).
- [ ] **Step 7: Commit** – `feat(board): board on tablet, mac and second screen (FR-12–FR-12.3)`.

### Task 10: Tafelbild als PDF über den Teilen-Dialog (FR-12.4)

**Design-Takt:** Hauptstufe

**Files:**
- Create: `Frontstage/Board/BoardPDFExporter.swift`, `Frontstage/Board/BoardDrawingPDF.swift`
- Modify: `Frontstage/Board/BoardScreen.swift` (Knopf `ShareLink`)
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/BoardPDFExporterTests.swift`, `FrontstageTests/TestImages.swift`

**Interfaces:**
- Consumes: `BoardPageRenderer`, `BoardPageSnapshot`.
- Produces: `BoardPDFExporter.makePDF(pages:)`, `struct BoardDrawingPDF: Transferable { let pages: [BoardPageSnapshot]; let fileName: String }`.

- [ ] **Step 1: Hilfsfunktion** `TestImages.nonWhiteRatio(_ image: CGImage) -> Double` (in 8-bit-Graustufen-Kontext zeichnen, Anteil Pixel < 250).
- [ ] **Step 2: Failing tests schreiben**

```swift
@Test("AK-34: zwei Seiten samt Hintergrund im PDF, Tafelbild unverändert") func pdfHasTwoPagesWithBackground() throws {
  let pages = [BoardPageSnapshot(background: .blank, backgroundImageData: nil, drawingData: PKDrawing().dataRepresentation()),
               BoardPageSnapshot(background: .grid, backgroundImageData: nil, drawingData: nil)]
  let before = pages
  let doc = try #require(PDFDocument(data: try BoardPDFExporter.makePDF(pages: pages)))
  #expect(doc.pageCount == 2)
  #expect(doc.page(at: 0)!.bounds(for: .mediaBox).size == BoardPDFExporter.pageSize)
  let grid = doc.page(at: 1)!.thumbnail(of: CGSize(width: 400, height: 225), for: .mediaBox).cgImage!
  #expect(TestImages.nonWhiteRatio(grid) > 0.01)      // Karos sind gezeichnet
}
@MainActor @Test("AK-34: Export lässt die gespeicherten Tafelseiten unverändert") func exportDoesNotTouchStore() throws {
  let (session, _) = try makeSession(); try session.open(tue8b); try session.addPage(background: .grid)
  let before = session.pages
  _ = try BoardPDFExporter.makePDF(pages: session.pages)
  try session.close(); try session.open(tue8b)
  #expect(session.pages == before)
}
```

- [ ] **Step 3: Diff durchsehen** – Tests nur unter `#if os(iOS)` (`UIImage.cgImage`); `BoardPageSnapshot` braucht `Equatable`.
- [ ] **Step 4: Implementieren** – `makePDF`: `NSMutableData` + `CGDataConsumer` + `CGContext(consumer:mediaBox:nil)`; je Seite `beginPDFPage(nil)`, Koordinaten auf oben-links drehen, `BoardPageRenderer.draw(…, size: pageSize)`, `endPDFPage()`; am Ende `closePDF()`. `BoardDrawingPDF.transferRepresentation` = `FileRepresentation(exportedContentType: .pdf) { SentTransferredFile(try $0.writeTemporaryFile()) }` – Datei im `FileManager.default.temporaryDirectory`, Name `"Tafelbild \(Klasse) \(Fach) \(yyyy-MM-dd).pdf"`. Signatur von `FileRepresentation(exportedContentType:exporting:)` beim Bau gegen die Xcode-Doku prüfen.
- [ ] **Step 5: Texte**: `board.sharePDF` = „Als PDF sichern“, `board.pdf.fileName %@ %@ %@` = „Tafelbild %@ %@ %@“.
- [ ] **Step 6: Diff durchsehen** – kein Schreiben über eine Ordnerfreigabe; nur temporäre Datei für den Teilen-Dialog (Global Constraints, Ausnahme FR-12.4).
- [ ] **Step 7: Commit** – `feat(board): export board drawing as PDF via share sheet (FR-12.4)`.

### Task 11: Abdecken und Aufdecken (FR-12.7)

**Design-Takt:** Hauptstufe

**Files:**
- Create: `Frontstage/Board/BoardCoverHandle.swift`
- Modify: `Frontstage/Board/BoardPageSurface.swift` (Abdeckung zeichnen: Rechteck von `revealedFraction` bis Seitenende, Deckkraft `BoardCover.opacity(for: audience)`), `Frontstage/Board/BoardScreen.swift` (Knopf „Abdecken“: setzt `cover = BoardCover()`, erneut tippen hebt auf)
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/BoardCoverRenderingTests.swift`

**Interfaces:**
- Consumes: `BoardCover`, `BoardSession.cover`, `BoardPageSurface(page:drawing:cover:audience:)`.
- Produces: `BoardCoverHandle` (Ziehgriff am unteren Rand der Abdeckung, nur Tablet; setzt `cover.reveal(to:)` aus der Ziehposition relativ zur Seitenhöhe).

- [ ] **Step 1: Failing test schreiben** – Seite mit Hintergrundbild aus `TestImages.threeBars()` (drei schwarze Balken bei 20 %, 50 %, 80 % Höhe, 2400 × 1350, JPEG), gerendert mit `ImageRenderer` in 800 × 450:

```swift
@MainActor @Test("AK-39: Zweitbildschirm zeigt nur Zeile 1, Tablet alle drei durchscheinend") func coverHidesOnSecondScreenOnly() throws {
  let page = BoardPageSnapshot(background: .image, backgroundImageData: TestImages.threeBars(), drawingData: nil)
  let cover = BoardCover(revealedFraction: 0.35)
  let second = try #require(ImageRenderer(content: BoardPageSurface(page: page, drawing: PKDrawing(), cover: cover, audience: .secondScreen).frame(width: 800, height: 450)).cgImage)
  let tablet = try #require(ImageRenderer(content: BoardPageSurface(page: page, drawing: PKDrawing(), cover: cover, audience: .tablet).frame(width: 800, height: 450)).cgImage)
  #expect(TestImages.isDark(second, atY: 0.20))                       // Zeile 1 sichtbar
  #expect(TestImages.isUniform(second, from: 0.36, to: 1.0))          // Zeilen 2 und 3 deckend verdeckt
  #expect(TestImages.isUniform(tablet, from: 0.36, to: 1.0) == false) // am Tablet scheinen Zeilen 2 und 3 durch
}
```

  (`TestImages.isDark(_:atY:)` = Mittelzeile bei relativer Höhe < 64 Grau; `isUniform(_:from:to:)` = Standardabweichung der Grauwerte im Höhenband < 2.)
- [ ] **Step 2: Diff durchsehen** – `BoardPageSurface` darf für den Test keine `PenCanvas` einbauen (`audience == .secondScreen` bzw. `isEditable: false`); Test nur iOS.
- [ ] **Step 3: Implementieren** – Abdeckungsfarbe: `Color(.systemBackground)`-Äquivalent als Platzhalter; Lücke melden.
- [ ] **Step 4: Text**: `board.cover` = „Abdecken“, `board.uncover` = „Abdeckung entfernen“.
- [ ] **Step 5: Diff durchsehen** – Abdeckung nie in `BoardPageRecord`, nie im PDF.
- [ ] **Step 6: Commit** – `feat(board): cover and reveal, opaque on second screen (FR-12.7)`.

### Task 12: Vorlage aus Material oder Ablage (FR-12.6)

**Design-Takt:** Hauptstufe

**Files:**
- Create: `Frontstage/Board/TemplateRenderer.swift`, `Frontstage/Board/TemplatePicker.swift`
- Modify: `Frontstage/Board/BoardScreen.swift` (Knopf „Vorlage“ → Sheet `TemplatePicker`)
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/TemplateRendererTests.swift`

**Interfaces:**
- Consumes: `DataStore.links(for:)` → `.reference` je Zuordnung in Reihenfolge, `MaterialReference.fileKind`/`displayName` (02), `StorageService.reference(forPickedFile:)` und `StorageService.withFileURL(for:_:)` (03), `BoardSession.addPage(background:imageData:)`.
- Produces: `TemplateRenderer.renderPDFPage(at:pageIndex:crop:)`, `TemplateRenderer.renderImage(at:crop:)` → JPEG `Data`, immer `2400 × 1350` px; `crop` normiert 0…1, Ursprung oben links; `nil` = ganze Seite.

- [ ] **Step 1: Failing tests schreiben**

```swift
@Test("AK-38: Ausschnitt um Aufgabe 2 wird vergrößert Hintergrund; PDF in der Ablage unverändert") func cropIsRenderedEnlarged() throws {
  let url = try TestImages.writePDF(blackRectAt: CGRect(x: 0.1, y: 0.4, width: 0.3, height: 0.1))   // A4 hoch, 595 × 842
  let before = try Data(contentsOf: url)
  let jpeg = try TemplateRenderer.renderPDFPage(at: url, pageIndex: 0, crop: CGRect(x: 0.1, y: 0.4, width: 0.3, height: 0.1))
  let image = try #require(TestImages.decode(jpeg))
  #expect(image.width == 2400); #expect(image.height == 1350)
  #expect(TestImages.isDark(image, atY: 0.5))              // Ausschnitt füllt die Mitte
  #expect(try Data(contentsOf: url) == before)
}
@Test("Ganze Seite: Mitte bleibt hell, Ränder weiß eingepasst") func wholePageIsLetterboxed() throws { /* crop nil → Mitte hell, linker Rand weiß */ }
@Test("Ungültige Seitenzahl wirft") func invalidPageThrows() throws {
  let url = try TestImages.writePDF(blackRectAt: .zero)
  #expect(throws: TemplateRendererError.self) { try TemplateRenderer.renderPDFPage(at: url, pageIndex: 3, crop: nil) }
}
```

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: Implementieren** – PDFKit `PDFDocument(url:)`, `page.bounds(for: .cropBox)`; Bitmap-`CGContext` 2400 × 1350 weiß; Ausschnitt einpassend skalieren und mittig; `page.draw(with: .cropBox, to: context)` nach Transformation; Bilder über `CGImageSourceCreateWithURL` + `CGImageSourceCreateImageAtIndex`; JPEG über `CGImageDestinationCreateWithData` (`UTType.jpeg`, `kCGImageDestinationLossyCompressionQuality: 0.8`). `enum TemplateRendererError: Error { case unreadable, pageOutOfRange }`.
- [ ] **Step 4: `TemplatePicker`** – Liste „Material dieser Unterrichtsstunde“ (nur `.pdf` und `.image`; andere Dateiarten ausgegraut mit Hinweis „Nur PDF und Bild“), darunter „Aus der Ablage wählen …“ (`.fileImporter(allowedContentTypes: [.pdf, .image])`, Zugriff mit `startAccessingSecurityScopedResource()`/`stop…` nur für das einmalige Rendern); bei PDF Seitenauswahl mit Vorschaubildern (`PDFPage.thumbnail`); danach Ausschnitt per Ziehrechteck (optional, „Ganze Seite“ als Vorgabe); „Übernehmen“ → `addPage(background: .image, imageData:)`. Rendern außerhalb des MainActor (`Task.detached` mit `URL`, Ergebnis `Data` ist `Sendable`).
- [ ] **Step 5: Texte**: `board.template` = „Vorlage“, `board.template.lessonMaterial` = „Material dieser Unterrichtsstunde“, `board.template.fromStorage` = „Aus der Ablage wählen …“, `board.template.onlyPdfImage` = „Nur PDF und Bild“, `board.template.wholePage` = „Ganze Seite“, `board.template.apply` = „Übernehmen“.
- [ ] **Step 6: Diff durchsehen** – nur lesend; kein Verweis auf die Datei in der Tafelseite.
- [ ] **Step 7: Commit** – `feat(board): template page from lesson material or storage (FR-12.6)`.

### Task 13: Kamera als Dokumentenkamera (FR-12.5)

**Design-Takt:** Hauptstufe

**Files:**
- Create: `Frontstage/Board/CameraFeed.swift`, `Frontstage/Board/CameraAvailability.swift`
- Modify: `project.yml` – Kamera-Berechtigung **geteilt mit dem Koppeln per QR-Code** (Teilplan 08, Task 13; Übersicht Abstimmung 15): Steht `NSCameraUsageDescription` schon im iOS-Ziel, nur den Text prüfen und bei Bedarf ersetzen; sonst anlegen. Text iOS-Ziel (nennt beide Zwecke): „Die Kamera zeigt Heft, Buchseite oder Versuch an der Tafel und liest den QR-Code zum Koppeln eines zweiten Geräts.“ Das macOS-Ziel (nur Koppeln, Text aus 08) und sein Entitlement `com.apple.security.device.camera` bleiben unverändert – die Tafel-Kamera gibt es am Mac nicht. Genau ein Schlüssel je Ziel; Wortlaut Platzhalter.
- Modify: `Frontstage/Board/BoardScreen.swift` (Knopf „Kamera“ → Livebild als Hintergrund, Knöpfe „Standbild“ und „Abbrechen“), `Frontstage/Board/BoardView.swift` (Einhängepunkt, Besitzer dieser Teilplan: bei `isCameraLive` Livebild statt Seite)
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/CameraTests.swift`

**Interfaces:**
- Consumes: `BoardSession.isCameraLive`, `BoardSession.addPage(background:imageData:)`.
- Produces:

```swift
enum CameraAvailability: Equatable, Sendable { case available, notDetermined, denied, unavailableInMultitasking, noCamera
  static func from(status: AVAuthorizationStatus, hasDevice: Bool, multitaskingBlocked: Bool) -> CameraAvailability }
@MainActor @Observable final class CameraFeed { … }   // s. Interfaces-Block; nur iOS
static func stillJPEG(from frame: CGImage) throws -> Data   // einpassend in 2400 × 1350, Qualität 0.8
```

- [ ] **Step 1: Failing tests schreiben**

```swift
@Test("Review Focus 5: Kamerazustand aus Freigabe, Gerät und Multitasking") func cameraAvailabilityMapping() {
  #expect(CameraAvailability.from(status: .authorized, hasDevice: true, multitaskingBlocked: false) == .available)
  #expect(CameraAvailability.from(status: .denied, hasDevice: true, multitaskingBlocked: false) == .denied)
  #expect(CameraAvailability.from(status: .restricted, hasDevice: true, multitaskingBlocked: false) == .denied)
  #expect(CameraAvailability.from(status: .notDetermined, hasDevice: true, multitaskingBlocked: false) == .notDetermined)
  #expect(CameraAvailability.from(status: .authorized, hasDevice: false, multitaskingBlocked: false) == .noCamera)
  #expect(CameraAvailability.from(status: .authorized, hasDevice: true, multitaskingBlocked: true) == .unavailableInMultitasking)
}
@MainActor @Test("AK-37 (ohne Gerät): Standbild wird neue Seite mit Bild-Hintergrund") func stillBecomesNewPage() throws {
  let (session, _) = try makeSession(); try session.open(tue8b)
  let jpeg = try CameraFeed.stillJPEG(from: TestImages.solid(gray: 0.5, width: 1920, height: 1080))
  try session.addPage(background: .image, imageData: jpeg)
  #expect(session.pages.count == 2); #expect(session.pages[1].background == .image); #expect(session.pageIndex == 1)
  #expect(TestImages.decode(jpeg)?.width == 2400)
}
```

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: Implementieren** (`#if os(iOS)`)
  - `start()`: `AVCaptureDevice.requestAccess(for: .video)` bei `notDetermined`; Gerät `AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)` (Umschalter auf `.front` möglich); `AVCaptureSession` mit `AVCaptureVideoDataOutput`, `setSampleBufferDelegate(_:queue:)` auf eigener serieller Queue; `session.isMultitaskingCameraAccessSupported` → wenn unterstützt `isMultitaskingCameraAccessEnabled = true`, sonst bei Unterbrechung (`AVCaptureSession.wasInterruptedNotification`, Grund `videoDeviceNotAvailableInBackground`/`…WithMultipleForegroundApps`) `availability = .unavailableInMultitasking`. `startRunning()` nicht auf dem MainActor.
  - Ausrichtung: `AVCaptureDevice.RotationCoordinator(device:previewLayer: nil)`, `videoRotationAngleForHorizonLevelCapture` an `connection.videoRotationAngle` (iOS 17+) – beim Bau gegen Xcode-Doku prüfen.
  - Bilder: `CVPixelBuffer` → `CIImage` → `CIContext.createCGImage`; höchstens 15 Bilder/s an `latestFrame` (MainActor) weiterreichen; ist `CGImage` im SDK nicht `Sendable`, in eine `@unchecked Sendable`-Hülle `FrameBox` packen (Kommentar: unveränderlich).
  - Livebild wird nie gespeichert. „Standbild“: `stillJPEG(from: latestFrame)` → `BoardSession.addPage(background: .image, imageData:)` → `isCameraLive = false`, `stop()`.
  - Ohne Freigabe: Knopf zeigt Grund und „In den Einstellungen freigeben“ (`UIApplication.openSettingsURLString`); Tafel bleibt nutzbar.
- [ ] **Step 4: Texte**: `board.camera` = „Kamera“, `board.camera.freeze` = „Standbild“, `board.camera.cancel` = „Abbrechen“, `board.camera.denied` = „Kamera nicht freigegeben“, `board.camera.multitasking` = „Kamera ist in geteilter Ansicht nicht verfügbar“, `board.camera.none` = „Keine Kamera“, `board.camera.openSettings` = „In den Einstellungen freigeben“.
- [ ] **Step 5: Diff durchsehen** – Swift 6: Delegate-Klasse `nonisolated`, `@unchecked Sendable` nur für die Queue-gebundene Capture-Hülle mit Begründung; macOS-Ziel kompiliert ohne Kamera-Code.
- [ ] **Step 6: Commit** – `feat(board): tablet camera as document camera with still as new page (FR-12.5)`.

### Task 14: CI-Lauf (workflow_dispatch) und Ergebnis prüfen

**Files:** keine Änderungen, außer Korrekturen aus dem Lauf.

- [ ] **Step 1: Gesamt-Diff durchsehen** – `git diff main...HEAD`: Imports (`PencilKit`, `PDFKit`, `AVFoundation`, `StoreKit`, `StoreKitTest` nur im Test-Ziel), `#if os(iOS)` um PencilKit-Zeichenfläche, Kamera, `AVAudioSession`, `UIImage`; `@MainActor`-Grenzen; keine deutschen Bezeichner; alle neuen Texte in `Localizable.xcstrings`; `project.yml` gültiges YAML.
- [ ] **Step 2: Branch pushen und Lauf starten**

```bash
git push -u origin <branch>
gh workflow run ci.yml --ref <branch>
gh run list --workflow ci.yml --branch <branch> --limit 1
gh run watch <run-id> --exit-status
```

Erwartet: Exit 0; im Log der Kern-Tests `ClassScreenDisplayTests`, `PhaseTimerTests`, `BoardRulesTests`, `UnlockRulesTests` grün; in den App-Tests (iPad-Simulator) `UnlockTests`, `LessonSessionStateTests`, `SecondScreenRenderingTests`, `BoardStoreTests`, `BoardSessionTests`, `BoardPDFExporterTests`, `BoardCoverRenderingTests`, `TemplateRendererTests`, `CameraTests` grün; macOS-Ziel baut.
- [ ] **Step 3: Bei Fehlschlag** – `gh run view <run-id> --log-failed`; vor jedem Fix-Vorschlag `superpowers:systematic-debugging`; Korrekturen sammeln, **ein** neuer Lauf. Häufige erwartbare Ursachen: `.storekit`-Format (Step 1 in Aufgabe 4), fehlende öffentliche Initialisierer aus 01, `Sendable`-Warnungen als Fehler bei `CGImage`/`PKDrawing`.
- [ ] **Step 4: Commit** der Korrekturen – `fix: CI findings for plan 07`.

### Task 15: Geräte-Checkliste (Mensch mit iPad, Mac und Apple TV)

Abzuhaken am TestFlight-Bau, Ergebnis je Zeile eintragen (`ok` / Befund).

| AK | Aufbau | Handlung | Erwartet | Ergebnis |
|---|---|---|---|---|
| AK-37 | Tafel offen, iPad per AirPlay mit Apple TV verbunden, Kamerafreigabe erteilt | „Kamera“, Heft unter das iPad halten, „Standbild“, auf das Bild schreiben; App beenden und neu starten, Tafel derselben Unterrichtsstunde öffnen | Zweitbildschirm zeigt erst Livebild, dann Standbild mit Geschriebenem; Standbild ist neue Seite und nach Neustart da | |
| AK-40 | frisch geladene App, Sandbox-Konto, kein Kauf | Stundenplan anlegen, Material zuordnen, öffnen, mit Apple TV ein PDF zeigen; Tafel und Klassenbildschirm antippen; Einmalkauf; zweites Gerät mit derselben Apple-ID öffnen | ohne Kauf alles bis PDF am Zweitbildschirm; Tafel/Klassenbildschirm zeigen Kaufangebot, Zweitbildschirm neutrale Fläche; nach Kauf beide frei auf beiden Geräten, ohne erneute Zahlung, ohne Ablaufdatum | |
| AK-40 (Ergänzung) | wie oben, gekauft | App löschen, neu laden, „Käufe wiederherstellen“; danach Flugmodus, App neu starten | frei nach Wiederherstellen; im Flugmodus weiterhin frei | |
| AK-26 (Ton) | Klassenbildschirm am Apple TV, iPad stumm geschaltet | Timer 1 Minute, ablaufen lassen; dabei PDF zeigen | Restzeit über dem PDF sichtbar; Signalton kommt aus dem Bildschirm im Klassenraum; „Zeit ist um“ sichtbar | |
| AK-39 (Gerät) | Tafelseite mit drei geschriebenen Zeilen, verbunden | Abdecken, unter Zeile 1 ziehen, dann unter Zeile 2 | Zweitbildschirm erst Zeile 1, dann 1 und 2; am iPad alle drei durchscheinend | |
| AK-30 (Gerät) | Unterrichtsstunde läuft, verbunden | Tafel öffnen, Wort schreiben, Strich radieren; dann ohne Apple TV wiederholen | Zweitbildschirm ohne Bedienelemente, Schrift erscheint ohne spürbare Verzögerung; ohne Apple TV gleich am iPad | |

---

## Abdeckung

| Anforderung | AK | Aufgaben | Beleg |
|---|---|---|---|
| FR-11 | AK-24 | 1, 6 | Kern-Test + `apple-design`-Prüfung; Gesamtablauf am Gerät (Checkliste 06) |
| FR-11.1 | AK-25 | 1, 6 | Kern-Test (Anzeige am Zweitbildschirm); Eingabe kostenlos in Teilplan 04 |
| FR-11.2 | AK-26 | 2, 5, 6, 7 | Kern-Tests; Ton am Gerät (Aufgabe 15) |
| FR-11.3 | AK-27 | 1, 6, 7 | Kern-Test |
| FR-11.4 | AK-28 | – | Teilplan 06 (`darkRestoresPreviousMode`); hier nur: Timer-Schicht nie über `.dark` |
| FR-11.7 | AK-36, AK-42 (Anzeige „bis 9:20“) | 1, 6 | Kern-Tests |
| FR-12 | AK-30 | 9 | App-Test; Schreiben/Radieren am Gerät |
| FR-12.1 | AK-31 | 3, 8, 9 | App-Test |
| FR-12.2 | AK-32 | 8, 9 | App-Test mit Neustart über Datei-Store |
| FR-12.3 | AK-33 | 3, 8, 9 | Kern- und App-Test |
| FR-12.4 | AK-34 | 10 | App-Test (PDF-Inhalt); Ordnerwahl im Teilen-Dialog nicht automatisierbar |
| FR-12.5 | AK-37 | 13 | Teil-Test; Gerät (Aufgabe 15) |
| FR-12.6 | AK-38 | 12 | App-Test |
| FR-12.7 | AK-39 | 3, 11 | Kern- und Render-Test; Gerät |
| FR-13 | AK-40 | 4 | StoreKitTest; Gerät mit Sandbox (Aufgabe 15) |

Nicht in diesem Teilplan: FR-11.5 und FR-11.6 (AK-29, AK-35) – Teilplan 06; FR-13.1 (AK-41) – Teilplan 05; FR-13.2 [Later].

## Abstimmungsbedarf

- Keiner offen gegenüber 01–06 und 08 (abgeglichen nach Übersicht, Abschnitt „Abstimmung“, Punkte 14 und 15): Kern aus 01; `LessonInfo`, `BoardBackground`, `MaterialReference` und alle Datenzugriffe über `DataStore` (02); `withFileURL` an `StorageService` (03); `LessonDetailView`, `DayView`, `SetupView`, `LessonInfoEditor`, `ScopedAppContent` aus 04; Einhängepunkte und „Dunkel“ aus 06 (Punkt 8); Bindung an den Datenort über `ClassroomServices.bind(store:)` innerhalb `DataScopedRoot` (08); Kamera-Berechtigung mit dem Koppeln geteilt (08); Freischaltung nach Nutzerentscheidung 2026-11-13.
- **Glossar (PRD, Spalte „Im Code“):** Die Spalte führt Vorlage als `BoardTemplate` und Standbild als `CameraStill`; dieser Plan hat dafür keine eigenen Typen, sondern `BoardBackground.image` plus `TemplateRenderer` bzw. `CameraFeed.stillJPEG()`. **Offen:** entweder die Typen `BoardTemplate`/`CameraStill` einführen oder die Glossar-Spalte auf die tatsächlichen Code-Namen ändern. Fachbegriffe ohne Glossarzeile, die eine Lehrkraft sagen würde: Timer (`PhaseTimer`), Abdecken (`BoardCover`), Kaufangebot (`PurchaseOfferView`). Rein technisch und ohne Zeile (Punkt 10): `LessonSessionState`, `ClassScreenDisplay`, `ClassroomServices`, `SecondScreenRendering`.

## Annahmen, die ein Mensch bestätigen sollte

1. Logische Tafelseite 16:9 (`1600 × 900`), PDF-Seite `842 × 473,6` pt (Breite A4 quer).
2. ~~Ohne Kauf sind auch Thema/Bereitlegen/Hausaufgabe und „Dunkel“ gesperrt~~ → Nutzerentscheidung 2026-11-13: beides kostenlos; zum Kauf gehören nur Klassenbildschirm am Zweitbildschirm, Timer, Arbeitsform und Tafel.
3. Arbeitsform wird beim Wechsel der Unterrichtsstunde zurückgesetzt, ein laufender Timer nicht.
4. Vorlagen nur aus PDF und Bild; Word/PowerPoint-Seiten erst als PDF (das Mockup zeigt „Arbeitsblatt Vokabeln – Word“).
5. Am Mac bietet der Teilen-Dialog keinen „Sichern in Ordner“-Weg wie „In Dateien sichern“ am iPad; AK-34 wird am iPad belegt. Soll der Mac zusätzlich „Sichern unter …“ (`fileExporter`) bekommen, ist das eine Erweiterung der Global-Constraint-Ausnahme.
6. „Letztes Tafelbild“ wird nur angesehen und gezeigt, nicht weiterbeschrieben.
7. Signalton selbst erzeugt (Sinus 880 Hz, dreimal), Platzhalter bis zur Design-Runde.
8. Produktkennung `frontstage.classroom` als Platzhalter; nicht familienfreigebbar.
9. Kamera: Rückkamera als Vorgabe, Umschalter auf Frontkamera.
