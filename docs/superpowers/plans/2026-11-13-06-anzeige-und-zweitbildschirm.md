# Teilplan 06 — Anzeige und Zweitbildschirm: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> Rahmen: `docs/superpowers/plans/2026-11-13-00-uebersicht.md` – zuerst lesen; alles dort gilt.

**Goal:** PDFs und Bilder zeigt Frontstage selbst an, mit Stiftnotizen je Zuordnung und Seite; ein verbundener Bildschirm erhält als Zweitbildschirm einen eigenen, nicht bedienbaren Inhalt (Klassenbildschirm, Material, Tafel, Dunkel), den die Lehrkraft am Tablet über die Smartboard-Leiste mit Vorschaubild sieht und umschaltet.

**Architecture:** Die reine Zustandslogik des Zweitbildschirms (`SecondScreenState`) und die Passungsprüfung einer Stiftnotiz (`PenNoteFit`) liegen im Kern-Paket. In der App hält ein `@Observable`-Objekt `SecondScreenModel` den gemeinsamen Zustand, den die Tablet-Szene ändert und die Szene des Zweitbildschirms zeichnet; das Vorschaubild ist dieselbe SwiftUI-Ansicht verkleinert. Die Szene für den verbundenen Bildschirm entsteht in UIKit (`ExternalDisplaySceneDelegate` mit `UIHostingController`) – ab iOS 27 über ein an der Hauptansicht angemeldetes `UISceneAccessory`, auf 26 über `application(_:configurationForConnecting:options:)`. Die Anzeige nutzt `PDFView` mit je Seite einer `PKCanvasView` als Überlagerung (`PDFPageOverlayViewProvider`); Stiftnotizen liegen als `PenNoteRecord` (Teilplan 02) mit ausgelagerten Zeichnungsdaten in den App-Daten.

**Tech Stack:** Swift 6, SwiftUI, UIKit-Szenen (`UISceneAccessory`, iOS 27), PDFKit, PencilKit, SwiftData, Swift Testing.

**Spec:** `docs/PRD.md` (FR-6, FR-6.1, FR-6.2, FR-11.5, FR-11.6; AK-13, AK-22, AK-23, AK-28, AK-29, AK-35; Glossar), `docs/ARCHITECTURE.md` (Area anzeige: Zweitbildschirm, Darstellung, Stiftnotizen; Area daten), `docs/adr/0006`, `docs/adr/0007`, `DESIGN.md`, Mockups `mockup/anzeige.html`, `mockup/tagesansicht.html` (Smartboard-Leiste, „So verbinden“), `mockup/smartboard.html`.

**Quellen für Apple-Schnittstellen (gelesen 2026-11-13, über die JSON-Fassung von developer.apple.com):**

- „Presenting content on a connected display“ (`developer.apple.com/documentation/uikit/presenting-content-on-a-connected-display`): *„Beginning in iOS 27, your app receives a scene with the `windowExternalDisplayNonInteractive` role only after it registers a scene accessory. In earlier releases, the system connected this scene automatically …“*; Muster `UISceneConfiguration()` + `delegateClass` + `UISceneAccessory.externalNonInteractive(sceneConfiguration:)` + `registerSceneAccessory(_:)` → `UISceneAccessoryRegistration`; *„If more than one view controller … registers …, the system presents the registration that belongs to the topmost, most recently presented view controller“*; Trennen über `sceneDidDisconnect(_:)`; `isEnabled`, `isAvailable`, `unregisterSceneAccessory(_:)`.
- `UISceneAccessory`, `UISceneAccessoryRegistration`, `UIViewController.registerSceneAccessory(_:)`: iOS/iPadOS 27.0. `UISceneSession.Role.windowExternalDisplayNonInteractive`: iOS 16.0. `UIApplicationDelegate.application(_:configurationForConnecting:options:)` und `UISceneConfiguration.init(name:sessionRole:)`: iOS 13.
- PDFKit: `PDFView.pageOverlayViewProvider`, `PDFPageOverlayViewProvider.pdfView(_:overlayViewFor:)`, `…willDisplayOverlayView…`, `…willEndDisplayingOverlayView…`, `PDFView.isInMarkupMode` – iOS 16 / macOS 13; `PDFPage.init?(image:)` (UIImage/NSImage); `PDFPage.bounds(for:)` – Koordinaten „in page space“, Drehung beachten.
- PencilKit: `PKCanvasView` nur iOS/iPadOS/Mac Catalyst (nicht macOS nativ); `PKDrawing` ab macOS 10.15 mit `init(data:) throws`, `dataRepresentation()`, `image(from:scale:)`, `transformed(using:)`; `PKCanvasViewDelegate.canvasViewDrawingDidChange(_:)`, `canvasViewDidEndUsingTool(_:)`.
- SwiftData: `Schema.Attribute.Option.externalStorage` – *„Stores the property’s value as binary data adjacent to the model storage.“*

---

## Global Constraints

Es gelten **alle** Global Constraints der Übersicht (`2026-11-13-00-uebersicht.md`, Abschnitt „Global Constraints“) – Mindestversion 26 mit `if #available(iOS 27, *)`-Weiche, Swift 6 strikt, Kern nur `Foundation`, Swift Testing, englische Bezeichner / deutsche Kommentare, kein lokaler Bau, CI gesammelt am Ende, SwiftData-Regeln, keine Server, Datenhygiene. Teilplan-eigen:

- **Die Anzeige schreibt nie in die Ablage** (ADR-0006): Datei nur lesen; Stiftnotizen nur in `PenNoteRecord`.
- **Stiftnotizen gehören zur Zuordnung** (FR-6.1): Schlüssel ist `MaterialLinkRecord` + Seitenindex (0-basiert; Bild = Seite 0). Eine Notiz wird **nie stillschweigend verworfen** – auch nicht bei geänderter Seitengröße oder fehlender Seite.
- **Zeichnungsdaten in Seitenkoordinaten:** gespeichert wird die Zeichnung im Koordinatenraum der angezeigten Seite in PDF-Punkten (Ursprung oben links, Drehung der Seite angewandt). Umrechnung auf jede Darstellungsgröße erst beim Zeigen.
- **Speichern:** nach jeder Zeichnungsänderung mit **0,5 s** Verzögerung (spätere Änderung verschiebt), sofort beim Seitenwechsel, beim Schließen der Anzeige und beim Wechsel der App in den Hintergrund (AK-13).
- **Zweitbildschirm zeigt nie die Tagesansicht und nie Bedienelemente** (FR-6.2); Szenen-Zubehör wird an der **Hauptansicht** angemeldet, nicht in der Anzeige.
- **Zustand des Zweitbildschirms ist flüchtig** – nicht in SwiftData, nicht in `UserDefaults`.
- **Mac:** Stiftnotizen nur anzeigen, keine Zeichenfläche; keine Smartboard-Leiste, keine Zweitbildschirm-Szene (`#if os(iOS)`).
- **Gestaltung:** Werkzeuge über die System-Werkzeugpalette `PKToolPicker` (kein eigenes Stift-/Farbmenü – Farbe und Werkzeugwahl sind offene Kategorien). Alle Texte Platzhalter-Wortlaut in `Localizable.xcstrings`.

## Review Focus

1. **Bildschirm ist schon verbunden, wenn die App startet oder die Anzeige schon offen ist** – erwartet: der Zweitbildschirm zeigt sofort den aktuellen Zustand (Material, falls offen), nicht erst nach einer Umschaltung. → Test `connectingKeepsCurrentMode` (Task 5).
2. **Bildschirm wird mitten im Schreiben getrennt oder neu verbunden** – erwartet: keine Notiz geht verloren, der Zustand bleibt für das erneute Verbinden; ein beim Verbinden noch „dunkel“ geschalteter Zustand wird aufgehoben, damit der Klassenbildschirm „ohne Handgriff“ erscheint (FR-11.6). → Tests `disconnectKeepsStateAndDrawings`, `connectingClearsDark` (Task 1, Task 5).
3. **App geht mit ungespeicherter Notiz in den Hintergrund** (Material in PowerPoint geöffnet, Home-Geste, Sperre) – erwartet: Notiz ist gespeichert. → Test `flushWritesPendingDrawingImmediately` (Task 3).
4. **Datei löst nicht auf, ist nicht heruntergeladen oder kein lesbares PDF/Bild** – erwartet: Anzeige zeigt „nicht verfügbar“, Stiftnotizen der Zuordnung bleiben unberührt. → Tests `unreadableDataFailsWithoutTouchingNotes`, `loadFailureSetsUnavailable` (Task 3, Task 4).
5. **Doppelte Stiftnotiz-Datensätze derselben Zuordnung und Seite nach dem Abgleich zweier Geräte** – erwartet: die jüngste wird gezeigt und weiterbeschrieben, keine wird gelöscht (das Zusammenführen gehört Teilplan 02). → Test `duplicateRecordsUseNewest` (Task 3).

---

## Dateien

| Datei | Verantwortung |
|---|---|
| `Packages/FrontstageCore/Sources/FrontstageCore/SecondScreenState.swift` | Modus des Zweitbildschirms und seine Übergänge (rein) |
| `Packages/FrontstageCore/Sources/FrontstageCore/PenNoteFit.swift` | `PageSize`, Passungsprüfung Stiftnotiz ↔ Seite |
| `Packages/FrontstageCore/Tests/FrontstageCoreTests/SecondScreenStateTests.swift` | Tests Zustand |
| `Packages/FrontstageCore/Tests/FrontstageCoreTests/PenNoteFitTests.swift` | Tests Passung |
| `Frontstage/Viewer/DrawingGeometry.swift` | `PKDrawing` ↔ Seitenkoordinaten, Seitengröße aus `PDFPage` |
| `Frontstage/Viewer/PenNoteStore.swift` | Laden, verzögertes Speichern, Sofort-Speichern von Stiftnotizen |
| `Frontstage/Viewer/MaterialDocumentLoader.swift` | Daten + Dateiart → `PDFDocument` (Bild = eine Seite) |
| `Frontstage/Viewer/ViewerModel.swift` | Zustand einer geöffneten Anzeige |
| `Frontstage/Viewer/PDFCanvasView.swift` | iPad: `PDFView` + `PKCanvasView` je Seite (`#if os(iOS)`) |
| `Frontstage/Viewer/PDFDisplayView.swift` | nur anzeigen: eine Seite + Zeichnung (Zweitbildschirm, Vorschau, Mac) |
| `Frontstage/Viewer/ViewerView.swift` | Bildschirm „Anzeige“ |
| `Frontstage/SecondScreen/SecondScreenModel.swift` | `@Observable` gemeinsamer Zustand beider Szenen |
| `Frontstage/SecondScreen/SecondScreenView.swift` | Inhalt des Zweitbildschirms (auch Vorschaubild) |
| `Frontstage/SecondScreen/SecondScreenEnvironment.swift` | eine Stelle für die Umgebung beider Szenen |
| `Frontstage/SecondScreen/SecondScreenOverlayView.swift` | Platzhalter Schicht über allen Modi außer Dunkel (Timer, Teilplan 07) |
| `Frontstage/SecondScreen/ExternalDisplaySceneDelegate.swift` | UIKit-Szene des Zweitbildschirms |
| `Frontstage/SecondScreen/SceneAccessoryRegistrar.swift` | Anmelden des Szenen-Zubehörs ab iOS 27 |
| `Frontstage/App/AppDelegate.swift` | Szene annehmen auf iOS 26 |
| `Frontstage/SecondScreen/SmartboardBar.swift` | Leiste am Tablet: Vorschaubild, Umschalter, Verbindungsstand |
| `Frontstage/SecondScreen/SmartboardBarAccessories.swift` | Platzhalter für Timer- und Arbeitsform-Knöpfe (Teilplan 07) |
| `Frontstage/SecondScreen/ConnectHowToView.swift` | „So verbinden“ |
| `Frontstage/ClassScreen/ClassScreenDisplayView.swift` | Platzhalter Klassenbildschirm (Teilplan 07 ersetzt den Körper) |
| `Frontstage/Board/BoardDisplayView.swift` | Platzhalter Tafel auf dem Zweitbildschirm (Teilplan 07 ersetzt den Körper) |
| `Frontstage/App/FrontstageApp.swift` | **Modify** (aus Teilplan 01/04): App-Delegate, Zubehör an der Hauptansicht, Umgebung |
| `Frontstage/UI/DayView/DayView.swift` | **Modify** (aus Teilplan 04): Smartboard-Leiste unten, Öffnen von PDF/Bild in der Anzeige |
| `Frontstage/Resources/Localizable.xcstrings` | **Modify**: Schlüssel dieses Teilplans |
| `FrontstageTests/DrawingGeometryTests.swift`, `FrontstageTests/PenNoteStoreTests.swift`, `FrontstageTests/ViewerModelTests.swift`, `FrontstageTests/SecondScreenModelTests.swift` | App-Tests (Simulator) |

---

## Interfaces dieses Teilplans

```swift
// ── Kern (FrontstageCore) ──
public enum SecondScreenMode: Hashable, Sendable { case classScreen, material, board, dark }
public struct SecondScreenState: Hashable, Sendable {
  public init()
  public private(set) var mode: SecondScreenMode            // Start: .classScreen
  public private(set) var isMaterialOpen: Bool               // Start: false
  public private(set) var isBoardAvailable: Bool             // Start: false
  public var availableModes: Set<SecondScreenMode> { get }   // .classScreen, .dark immer; .material/.board nur wenn verfügbar
  @discardableResult public mutating func select(_ mode: SecondScreenMode) -> Bool   // false = nicht verfügbar, unverändert
  public mutating func toggleDark()
  public mutating func materialOpened()
  public mutating func materialClosed()
  public mutating func setBoardAvailable(_ available: Bool)
  public mutating func displayConnected()                     // hebt Dunkel auf (FR-11.6)
}
public struct PageSize: Hashable, Codable, Sendable { public var width: Double; public var height: Double; public init(width: Double, height: Double) }
public enum PenNoteFit: Hashable, Sendable {
  case fits, sizeChanged, pageMissing
  public static let tolerance: Double = 1.0   // PDF-Punkte
  public static func evaluate(savedSize: PageSize?, pageIndex: Int, pageCount: Int, currentSize: PageSize?) -> PenNoteFit
}

// ── App ──
@MainActor @Observable final class SecondScreenModel {
  static let shared: SecondScreenModel
  init()
  private(set) var state: SecondScreenState
  private(set) var isConnected: Bool
  private(set) var screenAspectRatio: Double                 // Breite/Höhe, Vorgabe 16/9
  private(set) var material: MaterialPresentation?
  private(set) var boardLessonKey: LessonKey?
  func select(_ mode: SecondScreenMode)
  func toggleDark()
  func openMaterial(_ presentation: MaterialPresentation)
  func closeMaterial()
  func showPage(_ pageIndex: Int, visibleRect: CGRect?)       // visibleRect in Seitenkoordinaten, nil = ganze Seite
  func updateDrawing(_ drawing: PKDrawing, pageIndex: Int)   // Seitenkoordinaten
  func setBoardLesson(_ key: LessonKey?)                      // Teilplan 07 und Anzeige
  func displayConnected(aspectRatio: Double)
  func displayDisconnected()
}
struct MaterialPresentation: Equatable {
  let linkID: UUID; let documentData: Data; let kind: MaterialKind
  var pageIndex: Int; var visibleRect: CGRect?; var drawings: [Int: PKDrawing]
}
@MainActor final class PenNoteStore {
  init(context: ModelContext, saveDelay: Duration = .milliseconds(500))
  func loadAll(for link: MaterialLinkRecord) -> [Int: StoredPenNote]
  func scheduleSave(_ drawing: PKDrawing, pageIndex: Int, pageSize: PageSize, for link: MaterialLinkRecord)
  func flush()
}
struct StoredPenNote: Equatable { let drawing: PKDrawing; let savedSize: PageSize? }
enum DrawingGeometry {
  static func pageSize(of page: PDFPage) -> PageSize                         // .mediaBox, Drehung angewandt
  static func toPageSpace(_ drawing: PKDrawing, viewSize: CGSize, pageSize: PageSize) -> PKDrawing
  static func toViewSpace(_ drawing: PKDrawing, viewSize: CGSize, pageSize: PageSize) -> PKDrawing
}
enum MaterialDocumentLoader {
  enum LoadError: Error, Equatable { case unreadable, unsupportedKind }
  static func makeDocument(from data: Data, kind: MaterialKind) throws(LoadError) -> PDFDocument
}
@MainActor @Observable final class ViewerModel {
  enum Phase: Equatable { case loading, ready, unavailable }
  init(link: MaterialLinkRecord, store: PenNoteStore, fileReader: any MaterialFileReading, secondScreen: SecondScreenModel)
  private(set) var phase: Phase
  private(set) var document: PDFDocument?
  private(set) var pageIndex: Int
  private(set) var fitByPage: [Int: PenNoteFit]               // nur Seiten mit Notiz
  var outdatedPages: [Int] { get }                            // .sizeChanged, aufsteigend
  var missingPages: [Int] { get }                             // .pageMissing, aufsteigend
  func load() async
  func drawingChanged(_ drawingInPageSpace: PKDrawing, pageIndex: Int)
  func pageChanged(to pageIndex: Int, visibleRect: CGRect?)
  func close()                                                // flush + secondScreen.closeMaterial()
}
struct ViewerView: View { init(linkID: UUID) }                // sucht den MaterialLinkRecord selbst im ModelContext
struct SecondScreenView: View { init(model: SecondScreenModel) }
struct SmartboardBar: View { init() }                         // liest SecondScreenModel aus der Umgebung
struct ClassScreenDisplayView: View { init(model: SecondScreenModel) }   // Platzhalter → Teilplan 07
struct BoardDisplayView: View { init(model: SecondScreenModel) }         // Platzhalter → Teilplan 07
struct SecondScreenOverlayView: View { init(model: SecondScreenModel) }  // Platzhalter (leer) → Teilplan 07
struct SmartboardBarAccessories: View { init() }                         // Platzhalter (leer) → Teilplan 07
extension View { func secondScreenEnvironment() -> some View }           // eine Stelle für beide Szenen
extension View { func registersSecondScreenAccessory() -> some View }    // nur iOS, an der Hauptansicht
```

**Erwartet von Teilplan 01** (Kern):
- `public init(date: CalendarDay, schoolClass: SchoolClass, subject: Subject, ordinal: Int)` für `LessonKey` und `public init(year: Int, month: Int, day: Int)` für `CalendarDay` (die Übersicht nennt nur die Eigenschaften; öffentliche Strukturen haben keinen öffentlichen Memberwise-Init).

**Erwartet von Teilplan 02** (Daten):
```swift
@Model final class MaterialLinkRecord {
  var id: UUID = UUID()
  var lessonKeyText: String = ""          // LessonKey.storageText
  @Relationship(deleteRule: .cascade, inverse: \PenNoteRecord.materialLink) var penNotes: [PenNoteRecord]? = []
  var reference: MaterialReference? { get }   // berechnet oder gespeichert; Teilplan 02/03 entscheiden
}
@Model final class PenNoteRecord {
  var materialLink: MaterialLinkRecord?
  var pageIndex: Int = 0
  @Attribute(.externalStorage) var drawingData: Data?
  var pageWidth: Double = 0               // 0 = unbekannt
  var pageHeight: Double = 0
  var updatedAt: Date = Date()
  init(materialLink: MaterialLinkRecord?, pageIndex: Int)
}
```

**Erwartet von Teilplan 03** (Ablage):
```swift
enum MaterialKind: String, Codable, Sendable { case pdf, image, presentation, document, spreadsheet, other }
// MaterialReference trägt `kind: MaterialKind` und `displayName: String`
protocol MaterialFileReading: Sendable {
  /// Liest die Datei nur lesend (Ordnerfreigabe, koordiniertes Lesen); wirft, wenn der Verweis nicht auflöst oder die Datei nicht geladen werden kann.
  func readData(for reference: MaterialReference) async throws -> Data
}
```

**Erwartet von Teilplan 04** (Oberfläche Kern):
- `Frontstage/App/FrontstageApp.swift` mit `@main struct FrontstageApp: App` und `WindowGroup { RootView() }`; `Frontstage/UI/DayView/DayView.swift` mit `struct DayView: View`; die Tagesansicht ruft für Material mit `kind == .pdf || kind == .image` die Anzeige statt der Übergabe an eine andere App auf.
- Für AK-22: `MaterialLinkActions.copy(_ link: MaterialLinkRecord, to key: LessonKey, in context: ModelContext) -> MaterialLinkRecord` (FR-3.2, neue Zuordnung **ohne** Stiftnotizen) und `MaterialLinkActions.move(_ link: MaterialLinkRecord, to key: LessonKey)` (FR-3.3/FR-8, ändert nur `lessonKeyText`).

**Für Teilplan 07 bereitgestellt:** `SecondScreenModel` (inkl. `setBoardLesson`, `state.mode == .board`), die Platzhalter `ClassScreenDisplayView`, `BoardDisplayView`, `SecondScreenOverlayView`, `SmartboardBarAccessories` (Teilplan 07 ersetzt deren Körper, Name und `init` bleiben), `secondScreenEnvironment()` (Teilplan 07 hängt dort eigene `@Observable`-Modelle an, damit sie auch in der Zweitbildschirm-Szene ankommen – die hat eine eigene SwiftUI-Umgebung).

---

### Task 1: Zustand des Zweitbildschirms im Kern

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/SecondScreenState.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/SecondScreenStateTests.swift`

**Interfaces:**
- Consumes: –
- Produces: `SecondScreenMode`, `SecondScreenState` (siehe Interfaces-Block).

- [ ] **Step 1: Tests schreiben**

```swift
import Testing
@testable import FrontstageCore

struct SecondScreenStateTests {
  @Test("Startzustand ist Klassenbildschirm (FR-11)")
  func startsWithClassScreen() {
    let s = SecondScreenState()
    #expect(s.mode == .classScreen)
    #expect(s.availableModes == [.classScreen, .dark])
  }

  @Test("Öffnen zeigt Material, Schließen den Klassenbildschirm – nie die Tagesansicht (AK-23)")
  func openAndCloseMaterial() {
    var s = SecondScreenState()
    s.materialOpened();  #expect(s.mode == .material)
    s.materialClosed();  #expect(s.mode == .classScreen)
    #expect(!s.availableModes.contains(.material))
  }

  @Test("Dunkel und zurück zeigt wieder dasselbe Material (AK-28)")
  func darkRestoresPreviousMode() {
    var s = SecondScreenState()
    s.materialOpened()
    s.toggleDark();  #expect(s.mode == .dark)
    s.toggleDark();  #expect(s.mode == .material)
  }

  @Test("Umschalten Klassenbildschirm, Material, Tafel, Dunkel (AK-29)")
  func switchesThroughAllFourModes() {
    var s = SecondScreenState()
    s.materialOpened(); s.setBoardAvailable(true)
    for m in [SecondScreenMode.classScreen, .material, .board, .dark] {
      #expect(s.select(m)); #expect(s.mode == m)
    }
  }

  @Test("Nicht verfügbare Modi lassen den Zustand unverändert")
  func unavailableSelectionIsRejected() {
    var s = SecondScreenState()
    #expect(s.select(.material) == false); #expect(s.mode == .classScreen)
    #expect(s.select(.board) == false);    #expect(s.mode == .classScreen)
  }

  @Test("Material schließen während Dunkel: Dunkel bleibt, Rückweg führt zum Klassenbildschirm")
  func closeMaterialWhileDark() {
    var s = SecondScreenState()
    s.materialOpened(); s.toggleDark(); s.materialClosed()
    #expect(s.mode == .dark)
    s.toggleDark(); #expect(s.mode == .classScreen)
  }

  @Test("Material öffnen während Dunkel: bleibt dunkel, Rückweg zeigt das Material")
  func openMaterialWhileDark() {
    var s = SecondScreenState()
    s.toggleDark(); s.materialOpened()
    #expect(s.mode == .dark)
    s.toggleDark(); #expect(s.mode == .material)
  }

  @Test("Tafel nicht mehr verfügbar → Klassenbildschirm")
  func boardUnavailableFallsBack() {
    var s = SecondScreenState()
    s.setBoardAvailable(true); s.select(.board); s.setBoardAvailable(false)
    #expect(s.mode == .classScreen)
  }

  @Test("Verbinden hebt Dunkel auf, damit der Inhalt ohne Handgriff erscheint (AK-35)")
  func connectingClearsDark() {
    var s = SecondScreenState()
    s.toggleDark(); s.displayConnected()
    #expect(s.mode == .classScreen)
  }

  @Test("Verbinden lässt einen sichtbaren Modus unverändert (Review Focus 1)")
  func connectingKeepsVisibleMode() {
    var s = SecondScreenState()
    s.materialOpened(); s.displayConnected()
    #expect(s.mode == .material)
  }
}
```

- [ ] **Step 2: Diff durchsehen** – Tests kompilieren gegen die Signaturen im Interfaces-Block; erwartetes Ergebnis im CI-Lauf vor Step 3: Kompilierfehler „cannot find SecondScreenState“.

- [ ] **Step 3: `SecondScreenState` implementieren** in `SecondScreenState.swift`. Ein privates Feld `modeBeforeDark: SecondScreenMode` (Start `.classScreen`) trägt den Rückweg aus Dunkel. `select(.dark)` verhält sich wie `toggleDark()` aus einem hellen Modus; `select` eines hellen Modus aus Dunkel hebt Dunkel auf. `materialClosed()`/`setBoardAvailable(false)` korrigieren sowohl `mode` als auch `modeBeforeDark`, wenn sie auf den weggefallenen Modus zeigen. `///`-Doku deutsch mit Verweis auf FR-11.4, FR-11.5, FR-6.2.

- [ ] **Step 4: Diff durchsehen** – alle Zweige aus Step 1 abgedeckt; keine Importe außer `Foundation`.

- [ ] **Step 5: Commit**

```bash
git add Packages/FrontstageCore/Sources/FrontstageCore/SecondScreenState.swift Packages/FrontstageCore/Tests/FrontstageCoreTests/SecondScreenStateTests.swift
git commit -m "feat(core): second screen state with four modes"
```

---

### Task 2: Passung von Stiftnotiz und Seite im Kern

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/PenNoteFit.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/PenNoteFitTests.swift`

**Interfaces:**
- Produces: `PageSize`, `PenNoteFit.evaluate(savedSize:pageIndex:pageCount:currentSize:)`, `PenNoteFit.tolerance = 1.0`.

- [ ] **Step 1: Tests schreiben**

```swift
struct PenNoteFitTests {
  let a4 = PageSize(width: 595, height: 842)

  @Test("Gleiche Seitengröße passt (ADR-0006)")
  func sameSizeFits() {
    #expect(PenNoteFit.evaluate(savedSize: a4, pageIndex: 0, pageCount: 2, currentSize: a4) == .fits)
  }
  @Test("Abweichung bis 1 Punkt gilt als gleich")
  func withinToleranceFits() {
    #expect(PenNoteFit.evaluate(savedSize: a4, pageIndex: 0, pageCount: 1, currentSize: PageSize(width: 595.9, height: 841.2)) == .fits)
  }
  @Test("Andere Seitengröße meldet frühere Fassung")
  func differentSizeIsSizeChanged() {
    #expect(PenNoteFit.evaluate(savedSize: a4, pageIndex: 0, pageCount: 1, currentSize: PageSize(width: 842, height: 595)) == .sizeChanged)
  }
  @Test("Seite gibt es nicht mehr")
  func pageBeyondCountIsMissing() {
    #expect(PenNoteFit.evaluate(savedSize: a4, pageIndex: 2, pageCount: 2, currentSize: nil) == .pageMissing)
  }
  @Test("Unbekannte gespeicherte Größe (0 × 0 oder nil) gilt als passend")
  func unknownSavedSizeFits() {
    #expect(PenNoteFit.evaluate(savedSize: nil, pageIndex: 0, pageCount: 1, currentSize: a4) == .fits)
    #expect(PenNoteFit.evaluate(savedSize: PageSize(width: 0, height: 0), pageIndex: 0, pageCount: 1, currentSize: a4) == .fits)
  }
}
```

- [ ] **Step 2: Diff durchsehen** (erwartet im CI ohne Step 3: Kompilierfehler).
- [ ] **Step 3: `PageSize` und `PenNoteFit` implementieren.** Reihenfolge der Prüfung: `pageIndex >= pageCount` → `.pageMissing`; gespeicherte Größe fehlt oder hat Breite/Höhe ≤ 0 → `.fits`; sonst Vergleich je Achse mit `tolerance`.
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `git commit -m "feat(core): pen note fit against current page size"`

---

### Task 3: Stiftnotizen speichern und laden (Geometrie und `PenNoteStore`)

**Files:**
- Create: `Frontstage/Viewer/DrawingGeometry.swift`, `Frontstage/Viewer/PenNoteStore.swift`
- Test: `FrontstageTests/DrawingGeometryTests.swift`, `FrontstageTests/PenNoteStoreTests.swift`

**Interfaces:**
- Consumes: `PenNoteRecord`, `MaterialLinkRecord` (Teilplan 02, siehe „Erwartet“), `PageSize` (Task 2), `MaterialLinkActions` (Teilplan 04, nur im AK-22-Test).
- Produces: `DrawingGeometry`, `PenNoteStore`, `StoredPenNote`.

Hinweis Swift/SwiftData: Tests bauen einen `ModelContainer` mit `ModelConfiguration(isStoredInMemoryOnly: true)` – so laufen sie ohne iCloud und ohne Datei. `PKDrawing` lässt sich im Test aus `PKStroke`s bauen; als Prüfwert dient `drawing.strokes.count` und `drawing.bounds`.

- [ ] **Step 1: Tests schreiben**

```swift
import Testing, PencilKit, SwiftData
@testable import Frontstage

@MainActor struct DrawingGeometryTests {
  @Test("Umrechnung in Seitenkoordinaten und zurück verliert nichts")
  func roundTripKeepsBounds() {
    let d = TestDrawings.line(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 200))
    let page = PageSize(width: 595, height: 842)
    let view = CGSize(width: 1190, height: 1684)
    let back = DrawingGeometry.toViewSpace(DrawingGeometry.toPageSpace(d, viewSize: view, pageSize: page), viewSize: view, pageSize: page)
    #expect(abs(back.bounds.minX - d.bounds.minX) < 0.5 && abs(back.bounds.maxY - d.bounds.maxY) < 0.5)
  }
  @Test("Halbe Darstellungsgröße halbiert die Lage")
  func scalesToSmallerView() {
    let d = TestDrawings.line(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 300))
    let v = DrawingGeometry.toViewSpace(d, viewSize: CGSize(width: 297.5, height: 421), pageSize: PageSize(width: 595, height: 842))
    #expect(abs(v.bounds.midX - d.bounds.midX / 2) < 1)
  }
  @Test("Seitengröße berücksichtigt Drehung um 90°")
  func pageSizeAppliesRotation() {
    let page = TestDocuments.page(width: 595, height: 842, rotation: 90)
    #expect(DrawingGeometry.pageSize(of: page) == PageSize(width: 842, height: 595))
  }
}

@MainActor struct PenNoteStoreTests {
  @Test("Notiz übersteht Schließen und erneutes Öffnen (AK-13)")
  func savedNoteIsLoadedAgain() throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let store = PenNoteStore(context: ctx)
    store.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4, for: link)
    store.flush()
    let reopened = PenNoteStore(context: ctx).loadAll(for: link)
    #expect(reopened[0]?.drawing.strokes.count == TestDrawings.word.strokes.count)
    #expect(reopened[0]?.savedSize == .a4)
  }

  @Test("flush schreibt eine ausstehende Notiz sofort (Review Focus 3)")
  func flushWritesPendingDrawingImmediately() throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let store = PenNoteStore(context: ctx, saveDelay: .seconds(60))
    store.scheduleSave(TestDrawings.word, pageIndex: 1, pageSize: .a4, for: link)
    #expect(try ctx.fetchCount(FetchDescriptor<PenNoteRecord>()) == 0)
    store.flush()
    #expect(try ctx.fetchCount(FetchDescriptor<PenNoteRecord>()) == 1)
  }

  @Test("Wiederholtes Speichern derselben Seite legt keinen zweiten Datensatz an")
  func repeatedSaveUpdatesSameRecord() throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let store = PenNoteStore(context: ctx)
    store.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4, for: link); store.flush()
    store.scheduleSave(TestDrawings.twoWords, pageIndex: 0, pageSize: .a4, for: link); store.flush()
    #expect(try ctx.fetchCount(FetchDescriptor<PenNoteRecord>()) == 1)
    #expect(store.loadAll(for: link)[0]?.drawing.strokes.count == TestDrawings.twoWords.strokes.count)
  }

  @Test("Gespeicherte Seitengröße bleibt beim Weiterschreiben auf geänderter Seite erhalten")
  func savedSizeIsKeptOnLaterSaves() throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let store = PenNoteStore(context: ctx)
    store.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4, for: link); store.flush()
    store.scheduleSave(TestDrawings.twoWords, pageIndex: 0, pageSize: PageSize(width: 842, height: 595), for: link); store.flush()
    #expect(store.loadAll(for: link)[0]?.savedSize == .a4)
  }

  @Test("Dasselbe Material in einer anderen Zuordnung beginnt ohne Notizen (FR-6.1)")
  func otherLinkStartsEmpty() throws {
    let (ctx, link8a) = try TestStore.contextWithLink()
    let link8b = TestStore.addLink(to: ctx, sameFileAs: link8a)
    let store = PenNoteStore(context: ctx)
    store.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4, for: link8a); store.flush()
    #expect(store.loadAll(for: link8b).isEmpty)
  }

  @Test("Übernehmen ohne Notizen, Schieben mit Notizen (AK-22)")
  func copyDropsNotesMoveKeepsThem() throws {
    let (ctx, link) = try TestStore.contextWithLink(key: TestKeys.tue8aEnglish)
    let store = PenNoteStore(context: ctx)
    store.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4, for: link); store.flush()
    let copy = MaterialLinkActions.copy(link, to: TestKeys.wed8bEnglish, in: ctx)
    MaterialLinkActions.move(link, to: TestKeys.thu8aEnglish)
    #expect(store.loadAll(for: copy).isEmpty)
    #expect(link.lessonKeyText == TestKeys.thu8aEnglish.storageText)
    #expect(store.loadAll(for: link)[0] != nil)
  }

  @Test("Doppelte Datensätze nach Abgleich: der jüngste gilt, keiner wird gelöscht (Review Focus 5)")
  func duplicateRecordsUseNewest() throws {
    let (ctx, link) = try TestStore.contextWithLink()
    TestStore.addNote(to: ctx, link: link, page: 0, drawing: TestDrawings.word, updatedAt: .distantPast)
    TestStore.addNote(to: ctx, link: link, page: 0, drawing: TestDrawings.twoWords, updatedAt: .now)
    let store = PenNoteStore(context: ctx)
    #expect(store.loadAll(for: link)[0]?.drawing.strokes.count == TestDrawings.twoWords.strokes.count)
    store.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4, for: link); store.flush()
    #expect(try ctx.fetchCount(FetchDescriptor<PenNoteRecord>()) == 2)
  }

  @Test("Unlesbare Zeichnungsdaten werden übersprungen, der Datensatz bleibt")
  func corruptDataIsSkippedNotDeleted() throws {
    let (ctx, link) = try TestStore.contextWithLink()
    TestStore.addNote(to: ctx, link: link, page: 0, rawData: Data([0x00, 0x01]), updatedAt: .now)
    #expect(PenNoteStore(context: ctx).loadAll(for: link)[0] == nil)
    #expect(try ctx.fetchCount(FetchDescriptor<PenNoteRecord>()) == 1)
  }
}
```

`TestDrawings`, `TestDocuments`, `TestStore`, `TestKeys` legt dieser Task in `FrontstageTests/TestSupport/ViewerTestSupport.swift` an (Create). `TestKeys` nutzt nur Klassen `8a`/`8b`, Fach „Englisch“, Daten 17.–19.11.2026. `PageSize.a4` ist eine Test-Erweiterung (`595 × 842`).

- [ ] **Step 2: Diff durchsehen** (erwartet ohne Step 3: Kompilierfehler).

- [ ] **Step 3: `DrawingGeometry` implementieren.** `pageSize(of:)`: `page.bounds(for: .mediaBox).size`, bei `page.rotation` 90/270 Breite und Höhe tauschen. `toPageSpace`/`toViewSpace`: `drawing.transformed(using: CGAffineTransform(scaleX:y:))` mit dem Verhältnis Seitengröße ÷ Darstellungsgröße bzw. umgekehrt, je Achse getrennt.

- [ ] **Step 4: `PenNoteStore` implementieren.**
  - `loadAll`: alle `link.penNotes`, je `pageIndex` der Datensatz mit dem jüngsten `updatedAt`; `PKDrawing(data:)` in `do/catch` – bei Fehler Seite auslassen, Datensatz nicht anfassen. `savedSize` = `nil`, wenn Breite oder Höhe 0.
  - `scheduleSave`: ausstehende Zeichnung je `(link.id, pageIndex)` im Speicher merken, vorhandenen Verzögerungs-`Task` abbrechen, neuen starten (`try await Task.sleep(for: saveDelay)`, dann `flush()`). Swift-Hinweis: `Task {}` erbt hier den `@MainActor`, deshalb ist der Zugriff auf `ModelContext` sicher.
  - `flush`: für jede ausstehende Seite den jüngsten Datensatz aktualisieren oder `PenNoteRecord(materialLink:pageIndex:)` anlegen; `drawingData = drawing.dataRepresentation()`, `updatedAt = .now`; `pageWidth/pageHeight` **nur** setzen, wenn der Datensatz neu ist oder bisher eine leere Zeichnung trug; danach `try context.save()` (Fehler mit `Logger` aus `os` protokollieren, ausstehende Zeichnung behalten).
  - Keine Zeile löscht einen `PenNoteRecord` (Löschen nur über `deleteRule: .cascade` der Zuordnung, Teilplan 02).

- [ ] **Step 5: Diff durchsehen** – kein Schreibzugriff außerhalb von `ModelContext`; keine Datei-API.

- [ ] **Step 6: Commit** – `git commit -m "feat(viewer): pen note store with debounced save and page-space geometry"`

---

### Task 4: Material laden und Zustand der Anzeige (`MaterialDocumentLoader`, `ViewerModel`)

**Files:**
- Create: `Frontstage/Viewer/MaterialDocumentLoader.swift`, `Frontstage/Viewer/ViewerModel.swift`
- Test: `FrontstageTests/ViewerModelTests.swift`

**Interfaces:**
- Consumes: `MaterialFileReading`, `MaterialKind`, `MaterialReference` (Teilplan 03); `PenNoteStore`, `DrawingGeometry` (Task 3); `PenNoteFit` (Task 2); `SecondScreenModel.openMaterial/closeMaterial/showPage/updateDrawing/setBoardLesson` (Task 5 – Task 5 vor Task 4 umsetzen oder beide im selben Lauf; die Signaturen stehen im Interfaces-Block).
- Produces: `MaterialDocumentLoader.makeDocument(from:kind:)`, `ViewerModel`.

- [ ] **Step 1: Tests schreiben**

```swift
@MainActor struct ViewerModelTests {
  @Test("Ein Bild wird ein Dokument mit genau einer Seite (FR-6)")
  func imageBecomesOnePageDocument() throws {
    let doc = try MaterialDocumentLoader.makeDocument(from: TestDocuments.pngData(width: 800, height: 600), kind: .image)
    #expect(doc.pageCount == 1)
  }
  @Test("Andere Dateiarten werden nicht in der Anzeige geöffnet")
  func presentationIsUnsupported() {
    #expect(throws: MaterialDocumentLoader.LoadError.unsupportedKind) {
      try MaterialDocumentLoader.makeDocument(from: Data(), kind: .presentation)
    }
  }
  @Test("Unlesbare Daten: Anzeige meldet nicht verfügbar, Notizen unberührt (Review Focus 4)")
  func unreadableDataFailsWithoutTouchingNotes() async throws {
    let (ctx, link) = try TestStore.contextWithLink(kind: .pdf)
    TestStore.addNote(to: ctx, link: link, page: 0, drawing: TestDrawings.word, updatedAt: .now)
    let model = ViewerModel(link: link, store: PenNoteStore(context: ctx), fileReader: StubReader(result: .success(Data("kein PDF".utf8))), secondScreen: SecondScreenModel())
    await model.load()
    #expect(model.phase == .unavailable)
    #expect(try ctx.fetchCount(FetchDescriptor<PenNoteRecord>()) == 1)
  }
  @Test("Verweis löst nicht auf → nicht verfügbar, Zweitbildschirm bleibt beim Klassenbildschirm")
  func loadFailureSetsUnavailable() async throws {
    let (ctx, link) = try TestStore.contextWithLink(kind: .pdf)
    let screen = SecondScreenModel()
    let model = ViewerModel(link: link, store: PenNoteStore(context: ctx), fileReader: StubReader(result: .failure(StubError.unresolvable)), secondScreen: screen)
    await model.load()
    #expect(model.phase == .unavailable)
    #expect(screen.state.mode == .classScreen)
  }
  @Test("Öffnen zeigt Seite 1 mit vorhandenen Notizen auf dem Zweitbildschirm (AK-23)")
  func openingPresentsMaterialWithNotes() async throws {
    let (ctx, link) = try TestStore.contextWithLink(kind: .pdf)
    TestStore.addNote(to: ctx, link: link, page: 0, drawing: TestDrawings.word, updatedAt: .now, size: .a4)
    let screen = SecondScreenModel()
    let model = ViewerModel(link: link, store: PenNoteStore(context: ctx), fileReader: StubReader(result: .success(TestDocuments.pdfData(pages: 2, size: .a4))), secondScreen: screen)
    await model.load()
    #expect(model.phase == .ready)
    #expect(screen.state.mode == .material)
    #expect(screen.material?.pageIndex == 0)
    #expect(screen.material?.drawings[0]?.strokes.count == TestDrawings.word.strokes.count)
  }
  @Test("Geänderte Seitengröße und fehlende Seite werden gemeldet, nicht verworfen (ADR-0006)")
  func reportsOutdatedAndMissingPages() async throws {
    let (ctx, link) = try TestStore.contextWithLink(kind: .pdf)
    TestStore.addNote(to: ctx, link: link, page: 0, drawing: TestDrawings.word, updatedAt: .now, size: PageSize(width: 842, height: 595))
    TestStore.addNote(to: ctx, link: link, page: 4, drawing: TestDrawings.word, updatedAt: .now, size: .a4)
    let model = ViewerModel(link: link, store: PenNoteStore(context: ctx), fileReader: StubReader(result: .success(TestDocuments.pdfData(pages: 2, size: .a4))), secondScreen: SecondScreenModel())
    await model.load()
    #expect(model.outdatedPages == [0])
    #expect(model.missingPages == [4])
    #expect(try ctx.fetchCount(FetchDescriptor<PenNoteRecord>()) == 2)
  }
  @Test("Schließen speichert sofort und gibt den Zweitbildschirm frei (AK-13, AK-23)")
  func closeFlushesAndReturnsToClassScreen() async throws {
    let (ctx, link) = try TestStore.contextWithLink(kind: .pdf)
    let screen = SecondScreenModel()
    let model = ViewerModel(link: link, store: PenNoteStore(context: ctx, saveDelay: .seconds(60)), fileReader: StubReader(result: .success(TestDocuments.pdfData(pages: 1, size: .a4))), secondScreen: screen)
    await model.load()
    model.drawingChanged(TestDrawings.word, pageIndex: 0)
    model.close()
    #expect(try ctx.fetchCount(FetchDescriptor<PenNoteRecord>()) == 1)
    #expect(screen.state.mode == .classScreen && screen.material == nil)
  }
}
```

`StubReader`/`StubError` in `ViewerTestSupport.swift` ergänzen.

- [ ] **Step 2: Diff durchsehen.**

- [ ] **Step 3: `MaterialDocumentLoader` implementieren.** `.pdf`: `PDFDocument(data:)`, `nil` oder `pageCount == 0` → `.unreadable`. `.image`: iOS `UIImage(data:)`, macOS `NSImage(data:)`; vor `PDFPage(image:)` die Bildausrichtung einmal in ein aufrecht gezeichnetes Bild überführen (iOS: `UIGraphicsImageRenderer`, weil `PDFPage(image:)` die EXIF-Ausrichtung sonst nicht sicher übernimmt – am Gerät mit einem Hochkant-Foto prüfen); dann ein neues `PDFDocument()` mit `insert(_:at: 0)`. Andere Arten → `.unsupportedKind`.

- [ ] **Step 4: `ViewerModel` implementieren.**
  - `load()`: Datei über `fileReader.readData(for:)` lesen → `makeDocument` → Notizen `store.loadAll(for:)` → `fitByPage` je Notizseite über `PenNoteFit.evaluate` (aktuelle Größe aus `DrawingGeometry.pageSize(of:)`) → `secondScreen.openMaterial(MaterialPresentation(linkID:documentData:kind:pageIndex: 0, visibleRect: nil, drawings:))` und `secondScreen.setBoardLesson(LessonKey(storageText: link.lessonKeyText))` (für AK-29: Tafel der Unterrichtsstunde wählbar). Jeder Fehler → `phase = .unavailable`, kein Aufruf am Zweitbildschirm.
  - `drawingChanged`: `store.scheduleSave(…, pageSize: aktuelle Seitengröße)` und `secondScreen.updateDrawing(…)`.
  - `pageChanged`: `store.flush()`, `pageIndex` setzen, `secondScreen.showPage(…)`.
  - `close()`: `store.flush()`, `secondScreen.closeMaterial()`, `secondScreen.setBoardLesson(nil)`.

- [ ] **Step 5: Diff durchsehen.**
- [ ] **Step 6: Commit** – `git commit -m "feat(viewer): load pdf and image, viewer model with note fit"`

---

### Task 5: `SecondScreenModel` – gemeinsamer Zustand beider Szenen

**Files:**
- Create: `Frontstage/SecondScreen/SecondScreenModel.swift`
- Test: `FrontstageTests/SecondScreenModelTests.swift`

**Interfaces:**
- Consumes: `SecondScreenState` (Task 1), `LessonKey` (Teilplan 01).
- Produces: `SecondScreenModel`, `MaterialPresentation` (Interfaces-Block).

Swift-Hinweis: `@Observable` (Framework Observation) macht jede gespeicherte Eigenschaft beobachtbar; eine SwiftUI-Ansicht, die sie im `body` liest, wird bei Änderung neu gezeichnet – in **beiden** Szenen, weil beide dasselbe Objekt (`SecondScreenModel.shared`) halten. `@MainActor` sorgt unter Swift 6 dafür, dass nur der Haupt-Thread es ändert.

- [ ] **Step 1: Tests schreiben**

```swift
@MainActor struct SecondScreenModelTests {
  let presentation = MaterialPresentation(linkID: UUID(), documentData: Data(), kind: .pdf, pageIndex: 0, visibleRect: nil, drawings: [:])

  @Test("Material öffnen und schließen (AK-23)")
  func openAndClose() {
    let m = SecondScreenModel()
    m.openMaterial(presentation); #expect(m.state.mode == .material && m.material != nil)
    m.closeMaterial();            #expect(m.state.mode == .classScreen && m.material == nil)
  }
  @Test("Verbinden lässt den aktuellen Modus stehen (Review Focus 1)")
  func connectingKeepsCurrentMode() {
    let m = SecondScreenModel()
    m.openMaterial(presentation); m.displayConnected(aspectRatio: 16.0 / 9.0)
    #expect(m.isConnected && m.state.mode == .material)
  }
  @Test("Trennen behält Zustand und Zeichnungen (Review Focus 2)")
  func disconnectKeepsStateAndDrawings() {
    let m = SecondScreenModel()
    m.openMaterial(presentation); m.updateDrawing(TestDrawings.word, pageIndex: 0); m.displayDisconnected()
    #expect(!m.isConnected && m.state.mode == .material)
    #expect(m.material?.drawings[0]?.strokes.count == TestDrawings.word.strokes.count)
  }
  @Test("Seitenwechsel und Zoom werden übertragen")
  func showPageUpdatesPresentation() {
    let m = SecondScreenModel()
    m.openMaterial(presentation); m.showPage(1, visibleRect: CGRect(x: 0, y: 0, width: 200, height: 100))
    #expect(m.material?.pageIndex == 1 && m.material?.visibleRect?.width == 200)
  }
  @Test("Bildformat des Bildschirms wird übernommen, Vorgabe 16:9")
  func aspectRatio() {
    let m = SecondScreenModel()
    #expect(abs(m.screenAspectRatio - 16.0 / 9.0) < 0.001)
    m.displayConnected(aspectRatio: 4.0 / 3.0)
    #expect(abs(m.screenAspectRatio - 4.0 / 3.0) < 0.001)
  }
  @Test("Tafel wählbar nur mit Unterrichtsstunde")
  func boardRequiresLesson() {
    let m = SecondScreenModel()
    m.select(.board);                     #expect(m.state.mode == .classScreen)
    m.setBoardLesson(TestKeys.tue8aEnglish); m.select(.board); #expect(m.state.mode == .board)
    m.setBoardLesson(nil);                #expect(m.state.mode == .classScreen)
  }
  @Test("Zeichnung ohne offenes Material wird ignoriert")
  func drawingWithoutMaterialIsIgnored() {
    let m = SecondScreenModel()
    m.updateDrawing(TestDrawings.word, pageIndex: 0)
    #expect(m.material == nil)
  }
}
```

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: `SecondScreenModel` implementieren** – dünne Hülle um `SecondScreenState`; `static let shared = SecondScreenModel()`; `displayConnected` ruft `state.displayConnected()`; `screenAspectRatio` nur übernehmen, wenn Wert > 0. `MaterialPresentation` in derselben Datei.
- [ ] **Step 4: Diff durchsehen** – Datei kompiliert auch für macOS (nur `PencilKit`, `Foundation`, `Observation`, `FrontstageCore`).
- [ ] **Step 5: Commit** – `git commit -m "feat(second-screen): observable shared state for both scenes"`

---

### Task 6: Anzeige am iPad und am Mac (`ViewerView`)

Design-Takt: voll

**Files:**
- Create: `Frontstage/Viewer/PDFCanvasView.swift`, `Frontstage/Viewer/PDFDisplayView.swift`, `Frontstage/Viewer/ViewerView.swift`
- Modify: `Frontstage/UI/DayView/DayView.swift` (Teilplan 04) – PDF/Bild öffnet `ViewerView(linkID:)` als `.fullScreenCover` (iOS) bzw. `.sheet` (macOS)
- Modify: `Frontstage/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `ViewerModel` (Task 4), `SecondScreenModel` aus der Umgebung (Task 5), `SmartboardBar` (Task 8 – bis dahin `EmptyView()`), `MaterialFileReading`-Instanz aus der Umgebung (Teilplan 03; Name dort festlegen, siehe Abstimmungsbedarf).
- Produces: `ViewerView(linkID: UUID)`, `PDFDisplayView(documentData: Data, pageIndex: Int, drawing: PKDrawing?, visibleRect: CGRect?)`.

- [ ] **Step 1: Skill `apple-design` laden** (projektlokal; Hauptstufe vor dem Editieren).

- [ ] **Step 2: `PDFCanvasView` (nur `#if os(iOS)`) als `UIViewRepresentable`.** Swift-Hinweis: `UIViewRepresentable` bettet eine UIKit-Ansicht in SwiftUI ein; der `Coordinator` ist das Objekt, das UIKit-Delegates entgegennimmt.
  - `PDFView`: `displayMode = .singlePage`, `autoScales = true`, `usePageViewController(true)`, `isInMarkupMode = true` (iOS 16; überlässt Stifteingaben der Überlagerung), `pageOverlayViewProvider = coordinator`.
  - `pdfView(_:overlayViewFor:)`: je Seite eine `PKCanvasView` (`backgroundColor = .clear`, `isOpaque = false`, `drawingPolicy = .default` – folgt der Systemeinstellung „Nur Apple Pencil“), Zeichnung aus `ViewerModel` per `DrawingGeometry.toViewSpace` setzen; Canvas je Seitenindex im Coordinator merken.
  - `canvasViewDrawingDidChange(_:)` → `model.drawingChanged(DrawingGeometry.toPageSpace(…), pageIndex:)`. Beim Setzen der Zeichnung aus dem Speicher ein Flag setzen, damit dieser Rückruf nicht erneut speichert.
  - `pdfView(_:willEndDisplayingOverlayView:for:)` → `store.flush()` über `model.pageChanged`.
  - Seitenwechsel über `NotificationCenter` `.PDFViewPageChanged` → `model.pageChanged(to:visibleRect:)`; `visibleRect` = sichtbarer Ausschnitt in Seitenkoordinaten (`pdfView.convert(pdfView.bounds, to: page)`), `nil`, wenn die ganze Seite sichtbar ist.
  - Werkzeuge: `PKToolPicker()`; `addObserver(canvas)`, `setVisible(true, forFirstResponder: canvas)` für die Canvas der aktuellen Seite, `canvas.becomeFirstResponder()` – System-Werkzeugpalette mit Stift, Radierer, Farben, Rückgängig.

- [ ] **Step 3: `PDFDisplayView` (iOS und macOS) – nur anzeigen.** Eigenes `PDFDocument(data:)` je Instanz (ein Dokument nicht zwischen mehreren `PDFView`s teilen), im Coordinator nach `documentData` zwischengespeichert; `isUserInteractionEnabled = false` (iOS); Seite per `go(to:)`, Ausschnitt per `go(to:on:)`, wenn `visibleRect` gesetzt. Überlagerung: iOS eine nicht bedienbare `PKCanvasView` (`isUserInteractionEnabled = false`), macOS ein `NSImageView` mit `drawing.image(from:scale:)` (PencilKit hat am Mac keine Zeichenfläche, `PKDrawing` gibt es dort – Quelle oben). Zeichnung jeweils mit `toViewSpace` auf die Größe der Überlagerung.

- [ ] **Step 4: `ViewerView`.** Holt den `MaterialLinkRecord` per `@Query`/`FetchDescriptor` mit `#Predicate { $0.id == linkID }`, baut `ViewerModel`, ruft `.task { await model.load() }`.
  - Inhalt: iOS `PDFCanvasView`, macOS `PDFDisplayView` + Seiten-Knöpfe; `.loading` → `ProgressView`, `.unavailable` → `ContentUnavailableView` (Systemstandard) mit Text `viewer.unavailable`.
  - Navigationsleiste: Titel = `displayName` des Materials, Zurück/„Fertig“ → `model.close()` und schließen; Seitenanzeige `viewer.pageOfPages` („Seite %lld von %lld“), vorige/nächste Seite.
  - Hinweis bei `outdatedPages` nicht leer: Banner `viewer.outdatedNotes.title` / `.body` mit Seitenzahlen, Knopf `viewer.outdatedNotes.hide` (blendet für diese Sitzung aus; Notizen bleiben). Bei `missingPages` nicht leer: Banner `viewer.missingPages` mit Knopf `viewer.missingPages.show`, der die Notizen dieser Seiten als Bild (`PKDrawing.image(from: bounds, scale:)`) in einem Blatt zeigt.
  - `@Environment(\.scenePhase)`: beim Wechsel auf `.background` → `model.pageChanged(to: model.pageIndex, visibleRect: nil)` (löst `flush` aus).
  - Unten: `SmartboardBar()` nur `#if os(iOS)`.
  - Offene Kategorien (Systemstandard nehmen, im Abschlussbericht nennen): Wortlaut aller Texte, Darstellung des Hinweis-Banners, Seitenübersicht (Mockup zeigt eine; hier **nicht** gebaut – Abschlussbericht).

- [ ] **Step 5: `DayView` anpassen** – beim Tipp auf Material mit `kind == .pdf || .image` statt der Übergabe `ViewerView(linkID: link.id)` öffnen (genau eine Stelle, die Teilplan 04 dafür vorsieht).

- [ ] **Step 6: Texte** in `Localizable.xcstrings` (Schlüssel englisch, Werte deutsch, Platzhalter-Wortlaut aus dem Mockup): `viewer.unavailable` = „Material nicht verfügbar“, `viewer.pageOfPages` = „Seite %1$lld von %2$lld“, `viewer.outdatedNotes.title` = „Notizen zu einer früheren Fassung“, `viewer.outdatedNotes.body` = „Die Datei wurde in der Ablage geändert. Die Notizen dieser Stunde bleiben erhalten, liegen aber womöglich nicht mehr an der richtigen Stelle.“, `viewer.outdatedNotes.hide` = „Ausblenden“, `viewer.missingPages` = „Notizen zu Seiten, die es nicht mehr gibt“, `viewer.missingPages.show` = „Notizen ansehen“, `viewer.done` = „Fertig“.

- [ ] **Step 7: Diff durchsehen** – alle `PKCanvasView`/`PKToolPicker`/`UIView*` unter `#if os(iOS)`; macOS-Zweig ohne Zeichenfläche; kein Schreibzugriff auf die Datei.

- [ ] **Step 8: Prüfung mit `apple-design` als Prüfer** (Design-Takt voll) auf `ViewerView`; Befunde, die eine offene Kategorie entscheiden würden, nicht umsetzen, sondern im Abschlussbericht als Vorschlag für eine Design-Runde nennen.

- [ ] **Step 9: Commit** – `git commit -m "feat(viewer): pdf and image viewer with pencil notes, read-only on mac"`

---

### Task 7: Szene des Zweitbildschirms – iOS 26 und iOS 27

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/SecondScreen/SecondScreenView.swift`, `Frontstage/SecondScreen/SecondScreenEnvironment.swift`, `Frontstage/SecondScreen/SecondScreenOverlayView.swift`, `Frontstage/SecondScreen/ExternalDisplaySceneDelegate.swift`, `Frontstage/SecondScreen/SceneAccessoryRegistrar.swift`, `Frontstage/App/AppDelegate.swift`, `Frontstage/ClassScreen/ClassScreenDisplayView.swift`, `Frontstage/Board/BoardDisplayView.swift`
- Modify: `Frontstage/App/FrontstageApp.swift` (Teilplan 01/04)

**Interfaces:**
- Consumes: `SecondScreenModel` (Task 5), `PDFDisplayView` (Task 6).
- Produces: `SecondScreenView(model:)`, `secondScreenEnvironment()`, `registersSecondScreenAccessory()`, Platzhalter für Teilplan 07.

Hintergrund: Eine „Szene“ ist in UIKit eine eigene Instanz der Oberfläche mit eigenem Fenster. SwiftUI hat für die nicht bedienbare Szene des Zweitbildschirms keinen eigenen Baustein; sie wird in UIKit angelegt und zeigt die SwiftUI-Ansicht über `UIHostingController`. Die neue Szene hat **eine eigene SwiftUI-Umgebung** – deshalb `secondScreenEnvironment()` als einzige Stelle, an der beide Szenen ihre Umgebung bekommen.

- [ ] **Step 1: Skill `apple-design` laden.**

- [ ] **Step 2: `SecondScreenView(model:)`** – `switch model.state.mode`: `.classScreen` → `ClassScreenDisplayView(model:)`, `.material` → `PDFDisplayView(documentData:pageIndex:drawing: material.drawings[pageIndex], visibleRect:)` vollflächig, `.board` → `BoardDisplayView(model:)`, `.dark` → `Color.black`. Über allen Modi außer `.dark`: `SecondScreenOverlayView(model:)`. Keine Knöpfe, keine Gesten, `.allowsHitTesting(false)`, `.ignoresSafeArea()`. Ist `.material` gewählt, aber `material == nil`, zeigt sie den Klassenbildschirm (nie leer).

- [ ] **Step 3: Platzhalter** – `ClassScreenDisplayView`: neutrale Fläche (`Color(.systemBackground)` bzw. Systemstandard) mit Kommentar `// Teilplan 07 ersetzt den Körper; Name und init bleiben.`; `BoardDisplayView`: neutrale Fläche, gleicher Kommentar; `SecondScreenOverlayView`: `EmptyView()`, Kommentar „Timer-Schicht (FR-11.2), Teilplan 07“. Der Platzhalter-Klassenbildschirm zeigt **nichts** außer der Fläche (FR-11: nichts, was nicht für die Klasse bestimmt ist).

- [ ] **Step 4: `secondScreenEnvironment()`** in `SecondScreenEnvironment.swift`: `.environment(SecondScreenModel.shared)`; `///`-Doku: „Teilplan 07 hängt hier seine Modelle an.“

- [ ] **Step 5: `ExternalDisplaySceneDelegate` (nur `#if os(iOS)`)** – `final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate`, `var window: UIWindow?`.
  - `scene(_:willConnectTo:options:)`: `guard let windowScene = scene as? UIWindowScene, session.role == .windowExternalDisplayNonInteractive`; `UIWindow(windowScene:)`, `rootViewController = UIHostingController(rootView: SecondScreenView(model: .shared).secondScreenEnvironment())`, `makeKeyAndVisible()`; `SecondScreenModel.shared.displayConnected(aspectRatio: windowScene.screen.bounds.width / windowScene.screen.bounds.height)`.
  - `sceneDidDisconnect(_:)`: `window = nil`, `SecondScreenModel.shared.displayDisconnected()`.
  - `windowScene(_:didUpdate:interfaceOrientation:traitCollection:)`: Seitenverhältnis neu melden.
  - Quelle: Apple, „Presenting content on a connected display“, Abschnitte „Attach a window to a scene“, „Handle disconnection“.

- [ ] **Step 6: Weg iOS 26 – `AppDelegate` (nur `#if os(iOS)`)** – `final class AppDelegate: NSObject, UIApplicationDelegate` mit

```swift
func application(_ application: UIApplication,
                 configurationForConnecting connectingSceneSession: UISceneSession,
                 options: UIScene.ConnectionOptions) -> UISceneConfiguration {
  // Bis iOS 26 verbindet das System die Szene des Zweitbildschirms von selbst; wir nehmen sie an.
  // Ab iOS 27 kommt sie nur über das Szenen-Zubehör (Apple rät, die Rollenprüfung dort zu entfernen).
  if #unavailable(iOS 27), connectingSceneSession.role == .windowExternalDisplayNonInteractive {
    let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    configuration.delegateClass = ExternalDisplaySceneDelegate.self
    return configuration
  }
  return connectingSceneSession.configuration   // SwiftUI-Hauptszene unverändert
}
```

(Ausnahme vom Proportionsgebot: genau dieser Körper, weil die Versionsweiche und die Rückgabe für die SwiftUI-Hauptszene nicht aus der Signatur folgen.)

- [ ] **Step 7: Weg iOS 27 – `SceneAccessoryRegistrar` (nur `#if os(iOS)`)** – `UIViewControllerRepresentable` mit einem unsichtbaren `AccessoryHostViewController`. In `viewDidAppear(_:)` einmalig, nur `if #available(iOS 27, *)`: Ziel ist `view.window?.rootViewController` (die Hauptansicht, damit das Zubehör gilt, solange die App im Vordergrund ist – auch unter einem `.fullScreenCover` der Anzeige), sonst `self`:

```swift
let configuration = UISceneConfiguration(name: nil, sessionRole: .windowExternalDisplayNonInteractive)
configuration.delegateClass = ExternalDisplaySceneDelegate.self
registration = target.registerSceneAccessory(.externalNonInteractive(sceneConfiguration: configuration))
```

`registration` als `AnyObject?` speichern (der Typ `UISceneAccessoryRegistration` existiert erst ab 27). `registersSecondScreenAccessory()` = `.background(SceneAccessoryRegistrar().frame(width: 0, height: 0))`. Quelle: Apple, Abschnitt „Register a scene accessory for noninteractive content“ (Code dort mit `UISceneConfiguration()` + `delegateClass`; `init(name:sessionRole:)` ist gleichwertig und setzt die Rolle ausdrücklich).

- [ ] **Step 8: `FrontstageApp` anpassen** – unter `#if os(iOS)`: `@UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate` (Swift-Hinweis: verbindet einen UIKit-App-Delegate mit dem SwiftUI-Lebenszyklus); Hauptansicht im `WindowGroup` erhält `.registersSecondScreenAccessory()`. Für beide Plattformen: `.secondScreenEnvironment()` an der Hauptansicht.

- [ ] **Step 9: Diff durchsehen** – jede Nutzung von `UISceneAccessory`/`registerSceneAccessory` hinter `#available(iOS 27, *)`; die iOS-26-Rollenprüfung hinter `#unavailable(iOS 27)`; macOS-Ziel sieht nichts davon; `Info.plist`/`project.yml` unverändert (SwiftUI erzeugt das Szenen-Manifest). Fällt am Gerät die Szene auf 26 nicht an, ist der erste Prüfschritt `UIApplicationSceneManifest` in `project.yml` (Geräte-Checkliste, Punkt 23-d).

- [ ] **Step 10: Commit** – `git commit -m "feat(second-screen): non-interactive external display scene for iOS 26 and 27"`

---

### Task 8: Smartboard-Leiste, Vorschaubild und „So verbinden“

Design-Takt: voll

**Files:**
- Create: `Frontstage/SecondScreen/SmartboardBar.swift`, `Frontstage/SecondScreen/SmartboardBarAccessories.swift`, `Frontstage/SecondScreen/ConnectHowToView.swift`
- Modify: `Frontstage/Viewer/ViewerView.swift` (Platzhalter durch `SmartboardBar()` ersetzen), `Frontstage/UI/DayView/DayView.swift` (Teilplan 04: `.safeAreaInset(edge: .bottom) { SmartboardBar() }` nur `#if os(iOS)`), `Frontstage/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `SecondScreenModel` aus der Umgebung, `SecondScreenView` (Task 7).
- Produces: `SmartboardBar()`, `SmartboardBarAccessories()` (Platzhalter für Teilplan 07), `ConnectHowToView()`.

- [ ] **Step 1: Skill `apple-design` laden.**

- [ ] **Step 2: `SmartboardBar`** – eine Zeile mit:
  - **Vorschaubild** (FR-11.5): `SecondScreenView(model:)` – dieselbe Ansicht, kein Bildschirmfoto – in einem Rahmen mit `model.screenAspectRatio`, gezeichnet in einer festen virtuellen Größe von 960 Punkten Breite und per `.scaleEffect` auf die Vorschaubreite verkleinert, damit Schriftgrößen des Klassenbildschirms im selben Verhältnis erscheinen; `.allowsHitTesting(false)`; Bedienungshilfe-Text `secondScreen.preview.accessibility` mit dem Modusnamen und, wenn getrennt, `secondScreen.disconnected`. Das Vorschaubild ist auch ohne verbundenen Bildschirm sichtbar.
  - **Umschalter**: `Picker` mit `.segmented` über `[.classScreen, .material, .board, .dark]`, Bindung liest `model.state.mode` und ruft `model.select(_:)`; nicht verfügbare Modi `.disabled` (Systemstandard; Darstellung ist offene Kategorie).
  - `SmartboardBarAccessories()` (Platzhalter `EmptyView()`, Kommentar „Timer und Arbeitsform, Teilplan 07“).
  - **Verbindungsstand**: verbunden → Symbol + `secondScreen.connected`; getrennt → `secondScreen.disconnected` und Knopf `secondScreen.howTo`, der `ConnectHowToView` als `.sheet` öffnet. Der Name des Apple TV wird nicht gezeigt (keine Schnittstelle dafür; Mockup zeigt ihn nur zur Veranschaulichung).
  - Änderungen erscheinen ohne Zutun, weil die Leiste `model.isConnected` beobachtet (AK-35: „wenige Sekunden nach dem Verbinden“).

- [ ] **Step 3: `ConnectHowToView`** – Titel `secondScreen.howTo.title`, Abschnitt AirPlay mit drei nummerierten Schritten, Abschnitt Kabel, Hinweis `secondScreen.howTo.autoDetect`, Knopf `viewer.done`. Kein Sprung ins Kontrollzentrum (keine Schnittstelle, FR-11.6). Schließt sich von selbst, sobald `model.isConnected` wahr wird.

- [ ] **Step 4: Texte** (Platzhalter-Wortlaut aus `mockup/anzeige.html`, unpersönlich): `secondScreen.mode.classScreen` = „Klassenbildschirm“, `secondScreen.mode.material` = „Material“, `secondScreen.mode.board` = „Tafel“, `secondScreen.mode.dark` = „Dunkel“, `secondScreen.connected` = „Bildschirm verbunden“, `secondScreen.disconnected` = „Kein Bildschirm verbunden“, `secondScreen.howTo` = „So verbinden“, `secondScreen.howTo.title` = „Mit dem Bildschirm verbinden“, `secondScreen.howTo.autoDetect` = „Frontstage erkennt die Verbindung von selbst und zeigt dann den Klassenbildschirm.“, `secondScreen.howTo.airplay` = „Per AirPlay“, `secondScreen.howTo.step1` = „Von der rechten oberen Ecke nach unten wischen: Das Kontrollzentrum öffnet sich.“, `secondScreen.howTo.step2` = „„Bildschirmsynchronisierung“ antippen.“, `secondScreen.howTo.step3` = „Das Apple TV des Raums wählen.“, `secondScreen.howTo.cable` = „Per Kabel“, `secondScreen.howTo.cableText` = „Adapter (USB-C auf HDMI) anstecken – fertig. Das geht ohne Handgriff und auch, wenn das Schulnetz ausfällt.“, `secondScreen.preview.accessibility` = „Vorschaubild des Zweitbildschirms: %@“.

- [ ] **Step 5: Diff durchsehen** – Leiste und Anleitung nur `#if os(iOS)`; Vorschaubild nutzt `SecondScreenView`, keine zweite Darstellungslogik.

- [ ] **Step 6: Prüfung mit `apple-design` als Prüfer** (Design-Takt voll) auf Leiste und Anleitung; offene Kategorien (Platz der Leiste, Dichte, Wortlaut, Darstellung von „nicht verbunden“) nicht entscheiden, im Abschlussbericht als Kandidaten für `/design:design-runde` nennen.

- [ ] **Step 7: Commit** – `git commit -m "feat(second-screen): smartboard bar with live preview, switcher and connect guide"`

---

### Task 9: CI-Lauf (workflow_dispatch) und Ergebnis prüfen

**Files:** –

- [ ] **Step 1: Gesamtdiff des Teilplans durchsehen** gegen die Global Constraints: Kern ohne Fremdimporte; `#available`-/`#unavailable`-Weichen; `#if os(iOS)` um UIKit, `PKCanvasView`, `PKToolPicker`, `SmartboardBar`; keine Bezeichner außerhalb der Glossar-Spalte und der Interfaces-Blöcke; Datenhygiene in Tests (nur `8a`/`8b`, erfundene Materialnamen).
- [ ] **Step 2: Branch pushen und Lauf anstoßen**

```bash
git push -u origin "$(git branch --show-current)"
gh workflow run ci.yml --ref "$(git branch --show-current)"
gh run watch "$(gh run list --workflow ci.yml --branch "$(git branch --show-current)" --limit 1 --json databaseId --jq '.[0].databaseId')"
```

Erwartet: Job `core` (`swift test --package-path Packages/FrontstageCore`) grün mit `SecondScreenStateTests` (10 Tests) und `PenNoteFitTests` (5); Job `app` (`xcodebuild test`, iPad-Simulator) grün mit `DrawingGeometryTests` (3), `PenNoteStoreTests` (8), `ViewerModelTests` (7), `SecondScreenModelTests` (7); macOS-Ziel baut.
- [ ] **Step 3: Bei Fehlschlag** `gh run view --log-failed`, Ursache mit superpowers:systematic-debugging klären, alle Korrekturen sammeln, Diff durchsehen, **ein** neuer Lauf.

---

## Geräte-Checkliste (Mensch mit iPad, Apple TV, Mac)

Nach grünem CI über TestFlight auf ein iPad mit **iPadOS 26** und eines mit **iPadOS 27** (beide Wege, ADR-0007). Ergebnis je Zeile eintragen.

| # | AK | Schritte | Erwartet | iPadOS 26 | iPadOS 27 |
|---|---|---|---|---|---|
| 13 | AK-13 | PDF zugeordnet; antippen, mit dem Stift auf Seite 1 schreiben, schließen, erneut öffnen | Notiz ist da | ☐ | ☐ |
| 13-b | AK-13 | wie oben, statt Schließen sofort Home-Geste; App aus dem App-Umschalter beenden; erneut öffnen | Notiz ist da | ☐ | ☐ |
| 22 | AK-22 | PDF Di 8a zugeordnet, per „Für 8b übernehmen“ auch Mi 8b; nächste 8a-Stunde Do. Di 8a Seite 1 beschreiben; Mi 8b öffnen; Di 8a „in die nächste Stunde“; Do öffnen; Datei am Mac prüfen | Mi 8b ohne Notiz; Do 8a mit Notiz vom Di; Datei unverändert (Änderungsdatum) | ☐ | ☐ |
| 22-b | ADR-0006 | PDF in der Ablage am Mac durch Fassung mit Querformat-Seite 1 ersetzen; am iPad öffnen | Notiz sichtbar, Hinweis „frühere Fassung“; nichts verschwunden | ☐ | ☐ |
| 23 | AK-23 | per AirPlay mit Apple TV verbunden; Tagesansicht öffnen; PDF antippen; Seite 1 beschreiben; schließen | Tagesansicht nie am Apple TV; PDF-Seite im Vollbild ohne Bedienelemente; Notiz erscheint dort beim Schreiben; nach dem Schließen Klassenbildschirm(-Platzhalter), Tagesansicht nur am iPad | ☐ | ☐ |
| 23-b | AK-23 | denselben Ablauf ohne Apple TV | geht vollständig am iPad allein | ☐ | ☐ |
| 23-c | Area anzeige | verbunden; Einrichten/ein Blatt über der Tagesansicht öffnen; Anzeige als Vollbild öffnen | Zweitbildschirm bleibt beim eigenen Inhalt, spiegelt nie | ☐ | ☐ |
| 23-d | ADR-0007 | App mit bereits verbundenem Bildschirm starten | Zweitbildschirm zeigt sofort eigenen Inhalt (auf 26: sonst `UIApplicationSceneManifest` prüfen) | ☐ | ☐ |
| 23-e | Area anzeige | verbunden; Seite blättern und zoomen | Zweitbildschirm folgt Seite und Ausschnitt; Verzögerung beim Schreiben im Schulnetz notieren: ___ | ☐ | ☐ |
| 29 | AK-29 | verbunden, PDF offen; nacheinander Klassenbildschirm, Material, Tafel, Dunkel wählen | Zweitbildschirm wechselt jeweils; Vorschaubild zeigt jedes Mal dasselbe (Klassenbildschirm und Tafel bis Teilplan 07 als Platzhalter-Fläche) | ☐ | ☐ |
| 28 | AK-28 | PDF am Zweitbildschirm; „Dunkel“, erneut „Dunkel“ | schwarz, dann dieselbe PDF-Seite; iPad zeigt durchgehend das PDF | ☐ | ☐ |
| 35 | AK-35 | nicht verbunden, Tagesansicht offen; „So verbinden“; den Schritten folgen und im Kontrollzentrum das Apple TV wählen; später trennen; dann Kabel (USB-C auf HDMI) anstecken | Anleitung nennt Bildschirmsynchronisierung und Kabel; wenige Sekunden nach dem Verbinden zeigt das iPad „verbunden“ und der Zweitbildschirm den Klassenbildschirm ohne Handgriff; nach dem Trennen „nicht verbunden“; Kabel wie AirPlay | ☐ | ☐ |
| 35-b | Review Focus 2 | während des Schreibens AirPlay im Kontrollzentrum beenden, neu verbinden | keine Striche verloren; Zweitbildschirm zeigt danach das PDF | ☐ | ☐ |
| M | Area anzeige | Mac: Unterrichtsstunde mit am iPad beschriebenem PDF öffnen | Notizen sichtbar, an derselben Stelle; kein Zeichnen möglich | ☐ (macOS 26) | ☐ (macOS 27) |
| M-b | Area anzeige | Hochkant-Foto (iPhone) als Material am iPad öffnen | aufrecht dargestellt | ☐ | ☐ |

---

## Abdeckung

| Anforderung | Task | AK | Beleg |
|---|---|---|---|
| FR-6 | 3, 4, 6 | AK-13 | `savedNoteIsLoadedAgain`, `closeFlushesAndReturnsToClassScreen`; Gerät 13, 13-b |
| FR-6.1 | 3 | AK-22 | `otherLinkStartsEmpty`, `copyDropsNotesMoveKeepsThem`; Gerät 22 |
| FR-6.2 | 1, 5, 7 | AK-23 | `openAndCloseMaterial`, `openingPresentsMaterialWithNotes`; Gerät 23–23-e |
| FR-11.4 (nur Umschalten) | 1 | AK-28 | `darkRestoresPreviousMode`; Gerät 28 |
| FR-11.5 | 1, 8 | AK-29 | `switchesThroughAllFourModes`; Gerät 29 |
| FR-11.6 | 1, 7, 8 | AK-35 | `connectingClearsDark`; Gerät 35 |

Nicht in diesem Teilplan: FR-11, FR-11.1–11.3, FR-11.7 (Inhalt des Klassenbildschirms, Timer, Arbeitsform) und FR-12 ff. (Tafel) – Teilplan 07 über die Platzhalter; FR-13 (Kaufangebot statt Klassenbildschirm ohne Kauf) – Teilplan 07, der `ClassScreenDisplayView` füllt. Material am Zweitbildschirm bleibt hier ohne Kaufprüfung (FR-13 „kostenlos“).

## Abstimmungsbedarf

- **Teilplan 01:** öffentliche Initialisierer `LessonKey(date:schoolClass:subject:ordinal:)` und `CalendarDay(year:month:day:)` (für Tests).
- **Teilplan 02:** `MaterialLinkRecord.id: UUID`, `.lessonKeyText`, `.penNotes` mit `deleteRule: .cascade`; `PenNoteRecord` mit `materialLink`, `pageIndex`, `@Attribute(.externalStorage) drawingData`, `pageWidth`, `pageHeight`, `updatedAt`, `init(materialLink:pageIndex:)`; Zusammenführen doppelter `PenNoteRecord` derselben Zuordnung und Seite (behält den jüngsten Inhalt, Area daten).
- **Teilplan 03:** `MaterialKind` (mit `.pdf`, `.image`), `MaterialReference.kind`, `.displayName`; Protokoll `MaterialFileReading.readData(for:)` und wie eine Instanz in die SwiftUI-Umgebung kommt (Vorschlag: `@Environment(\.materialFileReader)`).
- **Teilplan 04:** Dateinamen `Frontstage/App/FrontstageApp.swift` (oder Teilplan 01), `Frontstage/UI/DayView/DayView.swift`; Abzweig „PDF/Bild → `ViewerView(linkID:)`“ in der Tagesansicht; `MaterialLinkActions.copy(_:to:in:)` und `.move(_:to:)`; Platz für `SmartboardBar` unten in der Tagesansicht.
- **Teilplan 07:** ersetzt die Körper von `ClassScreenDisplayView`, `BoardDisplayView`, `SecondScreenOverlayView`, `SmartboardBarAccessories` (Namen und `init(model:)`/`init()` bleiben); hängt eigene Modelle in `secondScreenEnvironment()` an; ruft `SecondScreenModel.setBoardLesson(_:)` und, für die geöffnete Tafel, `select(.board)`; Kaufprüfung im Klassenbildschirm. Falls die Tafel am Tablet eigene Übergänge braucht (`boardOpened`/`boardClosed`), ergänzt Teilplan 07 sie in `SecondScreenState` mit Tests.
- **Glossar:** keine neuen Fachbegriffe; `SecondScreenMode`, `PenNoteFit`, `PageSize`, `MaterialPresentation` sind technische Namen ohne Fachbedeutung. Falls „Smartboard-Leiste“ als Begriff in Dokumente eingeht, braucht sie eine Glossar-Zeile (Code-Name hier: `SmartboardBar`).

## Annahmen, die ein Mensch bestätigen sollte

1. **Verbinden hebt „Dunkel“ auf** (`displayConnected`), damit FR-11.6 „ohne weiteren Handgriff“ gilt; Öffnen eines Materials während „Dunkel“ lässt den Bildschirm dagegen dunkel.
2. **Schließen der Anzeige → Klassenbildschirm**, auch wenn vorher „Material“ gewählt war.
3. **„Tafel“ ist aus der Anzeige heraus wählbar** und zeigt die Tafel der Unterrichtsstunde des Materials (aus AK-29 und dem Mockup abgeleitet).
4. **Gespeicherte Seitengröße bleibt die erste**, auch wenn auf der geänderten Seite weitergeschrieben wird – der Hinweis „frühere Fassung“ bleibt dann bestehen.
5. **Zeichnen mit dem Finger** folgt der Systemeinstellung („Nur Apple Pencil“), kein eigener Schalter.
6. **Keine Seitenübersicht** in der ersten Fassung der Anzeige (Mockup zeigt eine); Blättern über Wischen und Knöpfe.
7. Anmelden des Szenen-Zubehörs am **Root-View-Controller** des Fensters genügt, damit es auch unter `.sheet`/`.fullScreenCover` gilt (Apple-Doku sagt das nicht ausdrücklich – Geräteprüfung 23-c).
8. Auf iOS 26 liefert das System die Szene im SwiftUI-Lebenszyklus ohne Eintrag `UIApplicationSupportsMultipleScenes` (Geräteprüfung 23-d).
