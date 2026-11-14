# Teilplan 06 — Anzeige und Zweitbildschirm: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> Rahmen: `docs/superpowers/plans/2026-11-13-00-uebersicht.md` – zuerst lesen; alles dort gilt (insbesondere Abstimmung Punkte 14 und 15).
> **Überarbeitet 2026-11-14** auf ADR-0011 (Stiftnotizen neben dem Dokument, löst ADR-0006 ab) und Teilplan 08 (`DataScopedRoot`). Die frühere Fassung mit `PenNoteStore` auf dem `DataStore` ist ersetzt; `PenNoteRecord` dient nur noch als Ersatz.

**Goal:** PDFs und Bilder zeigt Frontstage selbst an, mit Stiftnotizen je Unterrichtsstunde, die **neben dem Dokument** liegen – als Notiz-Datei `<Name>.frontstage-notizen/<Stunde>.json` und als lesbares Notiz-PDF `<Name> – Notizen <Klasse> <JJJJ-MM-TT>.pdf` (ADR-0011); ein verbundener Bildschirm erhält als Zweitbildschirm einen eigenen, nicht bedienbaren Inhalt (Klassenbildschirm, Material, Tafel, Dunkel), den die Lehrkraft am Tablet über die Smartboard-Leiste mit Vorschaubild sieht und umschaltet.

**Architecture:** Alles, was ohne Datei und ohne PencilKit entscheidbar ist, liegt im Kern-Paket und wird lokal getestet: Zustand des Zweitbildschirms (`SecondScreenSelection`), Passung Notiz ↔ Seite (`PenNoteFit`), Dateinamen und Format der Notiz-Datei (`PenNoteFileLayout`, `PenNoteFile`, `PenNoteFileCoding`) und die Abbildung von Schieben und Neu verknüpfen auf Dateioperationen (`PenNoteRelocation`). In der App liest und schreibt `PenNoteFileStore` die Dateien neben dem Dokument – über die Ordnerfreigabe des Materials (`StorageService.withDocumentLocation(for:_:)`, Ergänzung zu Teilplan 03) mit Dateikoordination; `PenNoteStore` hält die Notizen einer geöffneten Anzeige, speichert verzögert und fällt nur dann auf `PenNoteRecord` im `DataStore` zurück, wenn der Ordner nicht beschreibbar ist. `PenNotePDFWriter` erzeugt beim Schließen das Notiz-PDF (PDFKit-Ink-Anmerkungen). `PenNoteFileService` benennt Notiz-Datei und Notiz-PDF beim Schieben um und nimmt sie beim Neu verknüpfen mit (Naht `PenNoteFileRelocating` aus Teilplan 04). Der Zweitbildschirm bleibt wie geplant: `SecondScreenState` (`@Observable`, beide Szenen), UIKit-Szene `ExternalDisplaySceneDelegate` mit `UIHostingController`, ab iOS 27 über ein an der Hauptansicht angemeldetes `UISceneAccessory`, auf 26 über `application(_:configurationForConnecting:options:)`. Die Anzeige nutzt `PDFView` mit je Seite einer `PKCanvasView` als Überlagerung (`PDFPageOverlayViewProvider`).

**Tech Stack:** Swift 6, SwiftUI, UIKit-Szenen (`UISceneAccessory`, iOS 27), PDFKit (inkl. `PDFAnnotation` vom Typ `.ink`), PencilKit, `NSFileCoordinator`, SwiftData (nur Ersatz), Swift Testing.

**Spec:** `docs/PRD.md` (FR-6, FR-6.1 samt Änderung 2026-11-14, FR-6.2, FR-3.4 Präzisierung, FR-11.5, FR-11.6; AK-13, AK-22, AK-23, AK-28, AK-29, AK-35; Glossar: Stiftnotiz `PenNote`, Notiz-Datei `PenNoteFile`, Notiz-PDF `PenNotePDF`), `docs/ARCHITECTURE.md` (Area anzeige: Zweitbildschirm, Darstellung, Stiftnotizen; Area daten: Modell Stiftnotiz als Ersatz), `docs/adr/0011-stiftnotizen-neben-dem-dokument.md`, `docs/adr/0007`, `docs/adr/0012` (Datenort; Stiftnotizen laufen **nicht** über ihn), `DESIGN.md`, Mockups `mockup/anzeige.html`, `mockup/tagesansicht.html` (Smartboard-Leiste, „So verbinden“), `mockup/smartboard.html`.

**Baut auf:** 01 (Kern, Code auf `main`), 02 (`DataStore`, `MaterialLinkRecord`, `PenNoteRecord`), 03 (`StorageService`, `MaterialResolver`, `ScopedFile`; Ordnerfreigaben **lesend und schreibend** – Bookmark ohne Nur-lesen-Option, macOS-Entitlement `com.apple.security.files.user-selected.read-write`), 04 (`AppEnvironment`, `ScopedAppContent`, `DayView`, Naht `PenNoteFileRelocating`), 08 (`DataScopedRoot`, `DeviceIdentity`).

**Quellen für Apple-Schnittstellen (gelesen 2026-11-13, PDFKit-Anmerkungen 2026-11-14 über Context7 `/websites/developer_apple_pdfkit`):**

- „Presenting content on a connected display“ (`developer.apple.com/documentation/uikit/presenting-content-on-a-connected-display`): *„Beginning in iOS 27, your app receives a scene with the `windowExternalDisplayNonInteractive` role only after it registers a scene accessory. In earlier releases, the system connected this scene automatically …“*; Muster `UISceneConfiguration()` + `delegateClass` + `UISceneAccessory.externalNonInteractive(sceneConfiguration:)` + `registerSceneAccessory(_:)` → `UISceneAccessoryRegistration`; *„If more than one view controller … registers …, the system presents the registration that belongs to the topmost, most recently presented view controller“*; Trennen über `sceneDidDisconnect(_:)`; `isEnabled`, `isAvailable`, `unregisterSceneAccessory(_:)`.
- `UISceneAccessory`, `UISceneAccessoryRegistration`, `UIViewController.registerSceneAccessory(_:)`: iOS/iPadOS 27.0. `UISceneSession.Role.windowExternalDisplayNonInteractive`: iOS 16.0. `UIApplicationDelegate.application(_:configurationForConnecting:options:)` und `UISceneConfiguration.init(name:sessionRole:)`: iOS 13.
- PDFKit: `PDFView.pageOverlayViewProvider`, `PDFPageOverlayViewProvider.pdfView(_:overlayViewFor:)`, `…willDisplayOverlayView…`, `…willEndDisplayingOverlayView…`, `PDFView.isInMarkupMode` – iOS 16 / macOS 13; `PDFPage.init?(image:)` (UIImage/NSImage); `PDFPage.bounds(for:)` – Koordinaten „in page space“, Drehung beachten. `PDFAnnotation(bounds:forType: .ink, withProperties: nil)`, `add(_:)` mit `UIBezierPath` (iOS) bzw. `NSBezierPath` (macOS) – *„The path is specified in annotation-space coordinates“*; `PDFDocument.dataRepresentation()`.
- PencilKit: `PKCanvasView` nur iOS/iPadOS/Mac Catalyst (nicht macOS nativ); `PKDrawing` ab macOS 10.15 mit `init(data:) throws`, `dataRepresentation()`, `image(from:scale:)`, `transformed(using:)`, `appending(_:)`; `PKStroke.path` (`PKStrokePath`, `interpolatedPoints(by:)`), `PKStroke.transform`, `PKStroke.ink.color`; `PKCanvasViewDelegate.canvasViewDrawingDidChange(_:)`, `canvasViewDidEndUsingTool(_:)`.
- Foundation: `NSFileCoordinator.coordinate(readingItemAt:options:error:byAccessor:)`, `coordinate(writingItemAt:options:error:byAccessor:)` mit `.forReplacing`, `.forMoving`, `.forDeleting`; `Data.write(to:options: .atomic)`; Fehler `CocoaError.fileWriteNoPermission`, `.fileWriteVolumeReadOnly`, POSIX `EACCES`, `EPERM`, `EROFS`.

---

## Global Constraints

Es gelten **alle** Global Constraints der Übersicht (`2026-11-13-00-uebersicht.md`, Abschnitt „Global Constraints“) – Mindestversion 26 mit `if #available(iOS 27, *)`-Weiche, Swift 6 strikt, Kern nur `Foundation`, Swift Testing, englische Bezeichner / deutsche Kommentare, Kern lokal mit `.\scripts\swift-test.ps1` (TDD, RED/GREEN belegen), App nur per CI (gesammelt am Ende), SwiftData-Regeln, keine Server, Datenhygiene. Teilplan-eigen:

- **Das Original wird nie verändert** (FR-3.4, ADR-0011). Geschrieben werden neben dem Dokument **nur** drei Arten von Pfaden, die `PenNoteFileLayout` bildet: der Ordner `<Name>.frontstage-notizen/`, Dateien darin mit Endung `.json`, und Notiz-PDFs `<Name> – Notizen …pdf`. Jeder Schreib-, Verschiebe- und Löschaufruf läuft über `PenNoteFileStore`, das vor dem Zugriff `PenNoteFileLayout.isNotesPath(_:documentFileName:)` prüft.
- **Schreiben nur über die Ordnerfreigabe des Materials** (`StorageService.withDocumentLocation(for:_:)`), immer koordiniert (`NSFileCoordinator`) und atomar. Nie über Graph, nie über den Datenort (ADR-0012: Stiftnotizen laufen über den Zugriff auf das Material).
- **Stiftnotizen gehören zur Unterrichtsstunde** (FR-6.1): Schlüssel ist (Dokument, `LessonKey`) – die Stunden-Datei `<Schlüssel>.json`; Seitenindex 0-basiert (Bild = Seite 0). Eine Notiz wird **nie stillschweigend verworfen** – auch nicht bei geänderter Seitengröße, fehlender Seite, unlesbarer oder neuerer Datei.
- **Nie blind überschreiben:** Vor jedem Schreiben wird die Stunden-Datei neu gelesen und seitenweise zusammengeführt (`PenNoteFile.merged`); ist sie vorhanden, aber nicht lesbar (noch nicht geladen, beschädigt, neueres Format), wird **nicht** geschrieben und die Anzeige erlaubt kein Schreiben.
- **Ersatz:** Nur wenn das Schreiben mit „nicht beschreibbar“ scheitert (Rechte, nur lesend geteilter Ordner, schreibgeschütztes Volume), liegen die Notizen dieser Zuordnung in `PenNoteRecord` (Teilplan 02) und die Anzeige sagt das (ADR-0011). Wird der Ordner später beschreibbar, wandern sie beim nächsten Öffnen in die Notiz-Datei.
- **Zeichnungsdaten in Seitenkoordinaten:** gespeichert wird die Zeichnung im Koordinatenraum der angezeigten Seite in PDF-Punkten (Ursprung oben links, Drehung der Seite angewandt). Umrechnung auf jede Darstellungsgröße erst beim Zeigen, auf PDF-Seitenkoordinaten erst im Notiz-PDF.
- **Speichern:** nach jeder Zeichnungsänderung mit **0,5 s** Verzögerung (spätere Änderung verschiebt), sofort beim Seitenwechsel, beim Schließen der Anzeige und beim Wechsel der App in den Hintergrund (AK-13). Das Notiz-PDF wird beim Schließen geschrieben, wenn in dieser Sitzung geändert wurde oder es fehlt, obwohl Striche existieren.
- **Alles mit `DataStore` oder `StorageService` entsteht innerhalb von `DataScopedRoot`** (Übersicht, Abstimmung 15): `ViewerView` holt beide aus der Umgebung; `PenNoteFileService` legt `ScopedServicesHolder.services(for:)` (Teilplan 04, Datei `ScopedAppContent.swift`) an. Nur `SecondScreenState.shared` ist App-weit – es hält keinen `DataStore`.
- **Zweitbildschirm zeigt nie die Tagesansicht und nie Bedienelemente** (FR-6.2); Szenen-Zubehör wird an der **Hauptansicht** angemeldet, nicht in der Anzeige.
- **Zustand des Zweitbildschirms ist flüchtig** – nicht in SwiftData, nicht in `UserDefaults`.
- **Mac:** Stiftnotizen nur anzeigen, keine Zeichenfläche; keine Smartboard-Leiste, keine Zweitbildschirm-Szene (`#if os(iOS)`). Umbenennen und Mitnehmen von Notizen (Vorbereiten am Mac) laufen auch am Mac.
- **Gestaltung:** Werkzeuge über die System-Werkzeugpalette `PKToolPicker` (kein eigenes Stift-/Farbmenü – Farbe und Werkzeugwahl sind offene Kategorien). Alle Texte Platzhalter-Wortlaut in `Localizable.xcstrings`.
- Testdaten: Material „Arbeitsblatt Vokabeln.pdf“, Klassen `8a`/`8b`, Fach „Englisch“, Daten 17.–19.11.2026, Geräte-Kennung `"device-A"`.

## Entscheidungen dieses Teilplans (mit Begründung)

1. **Dateiname der Stunden-Datei = `LessonKey.storageText` in dateisicherer Form**: `|` → `_`, `%` → `-`, also `2026-11-17_8b_englisch_1.json`. *Grund:* `storageText` enthält `|`, das OneDrive, SharePoint und Windows in Dateinamen verbieten; die Abbildung ist umkehrbar, weil `_` und `-` in den kodierten Teilen sonst nicht vorkommen. Maßgeblich bleibt das Feld `lessonKey` in der Datei (ungekürzter `storageText`).
2. **Zwei Dokumente gleichen Namens mit verschiedener Endung** (`Tafelbild.pdf`, `Tafelbild.png`) teilen sich den Ordner `Tafelbild.frontstage-notizen/`. Die Datei nennt ihr Dokument (`document`); gehört die Stunden-Datei einem anderen Dokument, schreibt die App `<Schlüssel>.<endung>.json` daneben. *Verworfen:* Endung im Ordnernamen – widerspräche dem in ADR-0011 festgelegten Namen.
3. **Je Seite gilt der zuletzt geschriebene Stand**: Vor dem Schreiben wird die Datei neu gelesen; in dieser Sitzung geänderte Seiten kommen aus dem Speicher, alle anderen von der Platte. *Grund:* Zwei Geräte in derselben Stunde verlieren so nur bei derselben Seite etwas (Area daten, Nebenläufigkeit: „zuletzt abgeglichener Stand der Seite gilt“).
4. **Gespeicherte Seitengröße bleibt die erste** (wie zuvor): Weiterschreiben auf einer geänderten Seite ändert `width`/`height` nicht; der Hinweis „frühere Fassung“ bleibt.
5. **Notiz-PDF beim Schließen nur nach Änderung oder wenn es fehlt**; ohne Striche wird ein vorhandenes Notiz-PDF entfernt. *Grund:* ADR-0011 sagt „bei jedem Schließen neu geschrieben“ – wörtlich genommen schriebe jedes bloße Ansehen (auch am Mac) eine Datei, die der Ablage-Anbieter dann zwischen Geräten abgleicht. Inhaltlich gleich, weil sich ohne Änderung nichts am PDF ändert. *Zur Bestätigung vorgelegt (Annahmen).*
6. **Zweite Unterrichtsstunde desselben Fachs am Tag**: Notiz-PDF heißt `… <JJJJ-MM-TT> (2).pdf` (laufende Nummer > 1). Gleiches Dokument in zwei **verschiedenen** Fächern derselben Klasse am selben Tag ergibt denselben PDF-Namen; dann gilt das zuletzt geschlossene – die Notiz-Dateien bleiben getrennt und verlustfrei (*Kosten, selten*).
7. **Umbenennen beim Schieben über eine Geräte-lokale Warteliste** (`PendingPenNoteMoves`, Application Support, nicht gesichert): Der Umzug wird erst eingetragen, dann ausgeführt und bei Erfolg ausgetragen; Scheitern (Datei noch nicht geladen, offline) holt das nächste Aktivwerden oder Öffnen der Anzeige nach. *Grund:* Das Schieben selbst (Teilplan 04, `DataStore`) ist sofort und synchron; die Dateien folgen, ohne dass die Oberfläche warten muss.
8. **Ziel existiert schon** (Schieben in eine Stunde, die dasselbe Dokument mit Notizen hat): Stunden-Dateien werden seitenweise vereinigt, auf derselben Seite werden die Striche aneinandergehängt (`PKDrawing.appending`); das alte Notiz-PDF wird entfernt und das Ziel neu erzeugt. Nichts geht verloren.

## Review Focus

1. **Bildschirm ist schon verbunden, wenn die App startet oder die Anzeige schon offen ist** – erwartet: der Zweitbildschirm zeigt sofort den aktuellen Zustand (Material, falls offen), nicht erst nach einer Umschaltung. → Test `connectingKeepsCurrentMode` (Task 4).
2. **Bildschirm wird mitten im Schreiben getrennt oder neu verbunden** – erwartet: keine Notiz geht verloren, der Zustand bleibt für das erneute Verbinden; ein beim Verbinden noch „dunkel“ geschalteter Zustand wird aufgehoben, damit der Klassenbildschirm „ohne Handgriff“ erscheint (FR-11.6). → Tests `disconnectKeepsStateAndDrawings`, `connectingClearsDark` (Task 1, Task 4).
3. **App geht mit ungespeicherter Notiz in den Hintergrund** (Material in PowerPoint geöffnet, Home-Geste, Sperre) – erwartet: Notiz ist in der Stunden-Datei. → Test `flushWritesPendingDrawingImmediately` (Task 6).
4. **Stunden-Datei vorhanden, aber nicht lesbar** (Ablage-Anbieter hat sie noch nicht geladen, beschädigt, neueres Format eines späteren Frontstage) – erwartet: keine Überschreibung, Anzeige meldet „Notizen gerade nicht lesbar“ und lässt nicht schreiben. → Tests `unreadableFileIsNeverOverwritten`, `newerFormatIsReadOnly` (Task 6), `decodeRejectsNewerFormat` (Task 2).
5. **Ordner des Dokuments nicht beschreibbar** – erwartet: Notizen in `PenNoteRecord`, Hinweis in der Anzeige; sobald beschreibbar, wandern sie in die Notiz-Datei, ohne Verlust. → Tests `notWritableFallsBackToAppData`, `fallbackNotesMoveIntoFileOnceWritable` (Task 6).
6. **Zwei Geräte schreiben dieselbe Stunde** – erwartet: Seiten, die nur das andere Gerät geändert hat, bleiben erhalten. → Test `mergeKeepsPagesWrittenElsewhere` (Task 2), `saveRereadsBeforeWriting` (Task 6).
7. **Datei löst nicht auf, ist nicht heruntergeladen oder kein lesbares PDF/Bild** – erwartet: Anzeige zeigt „nicht verfügbar“, Notizen bleiben unberührt. → Tests `unreadableDataFailsWithoutTouchingNotes`, `loadFailureSetsUnavailable` (Task 7).
8. **Schieben, während die Notiz-Datei noch nicht geladen ist oder offline** – erwartet: Umbenennen wird nachgeholt, nie doppelt ausgeführt. → Tests `failedMoveStaysPendingAndRetries`, `chainedMovesRunInOrder` (Task 9).

---

## Dateien

| Datei | Verantwortung |
|---|---|
| `Packages/FrontstageCore/Sources/FrontstageCore/SecondScreen/SecondScreenSelection.swift` | Modus des Zweitbildschirms und seine Übergänge (rein) |
| `Packages/FrontstageCore/Sources/FrontstageCore/PenNotes/PenNoteFit.swift` | `PageSize`, Passungsprüfung Stiftnotiz ↔ Seite |
| `…/PenNotes/PenNoteFileLayout.swift` | Ordner-, Stunden-Datei- und PDF-Namen, Umkehrung, Pfadprüfung |
| `…/PenNotes/PenNoteFile.swift`, `PenNoteFileCoding.swift` | Format der Notiz-Datei, Zusammenführen, JSON |
| `…/PenNotes/PenNoteRelocation.swift` | Schieben und Neu verknüpfen → Dateioperationen |
| `Packages/FrontstageCore/Tests/FrontstageCoreTests/SecondScreen/SecondScreenSelectionTests.swift`, `…/PenNotes/PenNoteFitTests.swift`, `PenNoteFileLayoutTests.swift`, `PenNoteFileTests.swift`, `PenNoteRelocationTests.swift` | Kern-Tests |
| `Frontstage/SecondScreen/SecondScreenState.swift` | `@Observable` gemeinsamer Zustand beider Szenen |
| `Frontstage/Viewer/DrawingGeometry.swift` | `PKDrawing` ↔ Seitenkoordinaten, Seitengröße aus `PDFPage`, Seite → PDF-Koordinaten |
| `Frontstage/Storage/StorageService.swift`, `Frontstage/Storage/MaterialResolver.swift` | **Modify** (Teilplan 03): `withDocumentLocation(for:_:)`, `resolveFolder(of:)` |
| `Frontstage/Viewer/PenNotes/PenNoteFileStore.swift` | Lesen, Schreiben, Verschieben, Löschen neben dem Dokument (koordiniert) |
| `Frontstage/Viewer/PenNotes/PenNoteFileAccess.swift` | Protokoll `PenNoteFileAccessing`, Umsetzung `StoragePenNoteFiles` über `StorageService` |
| `Frontstage/Viewer/PenNotes/PenNoteStore.swift` | Notizen einer geöffneten Anzeige: Ort wählen, laden, verzögert speichern, Ersatz |
| `Frontstage/Viewer/PenNotes/PenNotePDFWriter.swift` | Notiz-PDF mit Ink-Anmerkungen |
| `Frontstage/Viewer/PenNotes/PenNoteFileService.swift`, `PendingPenNoteMoves.swift` | Naht `PenNoteFileRelocating` (04): Schieben, Neu verknüpfen, Warteliste |
| `Frontstage/Data/DataStore+MaterialLinks.swift` | **Modify** (Teilplan 02, Abschnitt „Stiftnotizen“ neben `penNotes(for:)`/`savePenNote`): `removePenNotes(for:)` – einzige Ergänzung |
| `Frontstage/Viewer/MaterialDocumentLoader.swift` | Daten + Dateiart → `PDFDocument` (Bild = eine Seite) |
| `Frontstage/Viewer/ViewerModel.swift` | Zustand einer geöffneten Anzeige |
| `Frontstage/Viewer/PDFCanvasView.swift` | iPad: `PDFView` + `PKCanvasView` je Seite (`#if os(iOS)`) |
| `Frontstage/Viewer/PDFDisplayView.swift` | nur anzeigen: eine Seite + Zeichnung (Zweitbildschirm, Vorschau, Mac) |
| `Frontstage/Viewer/ViewerView.swift` | Bildschirm „Anzeige“ |
| `Frontstage/Viewer/PenCanvas.swift` | `PKCanvasView` als SwiftUI-Ansicht (nur iOS) – auch für die Tafel in Teilplan 07 |
| `Frontstage/Viewer/ScopedFileReader.swift` | `MaterialFileReading` über `StorageService.readableFile(for:)` (03) |
| `Frontstage/SecondScreen/SecondScreenRootView.swift` | Inhalt des Zweitbildschirms (auch Vorschaubild) |
| `Frontstage/SecondScreen/SecondScreenEnvironment.swift` | eine Stelle für die Umgebung beider Szenen |
| `Frontstage/SecondScreen/ExternalDisplaySceneDelegate.swift` | UIKit-Szene des Zweitbildschirms |
| `Frontstage/SecondScreen/SceneAccessoryRegistrar.swift` | Anmelden des Szenen-Zubehörs ab iOS 27 |
| `Frontstage/App/AppDelegate.swift` | Szene annehmen auf iOS 26 |
| `Frontstage/SecondScreen/SmartboardBar.swift` | Leiste am Tablet: Vorschaubild, Umschalter, Verbindungsstand |
| `Frontstage/SecondScreen/ConnectHowToView.swift` | „So verbinden“ |
| **Einhängepunkte für Teilplan 07** (Übersicht, Abstimmung Punkt 8) – dieser Teilplan legt sie als Platzhalter in den Ordnern von 07 an; **Besitzer ist 07**, das nur ihren Inhalt ersetzt und keine andere Datei dieses Teilplans ändert: | |
| `Frontstage/ClassScreen/ClassScreenView.swift` | `ClassScreenView()` – Inhalt `.classScreen` des Zweitbildschirms (Platzhalter: neutrale Fläche) |
| `Frontstage/Board/BoardView.swift` | `BoardView()` – Inhalt `.board` des Zweitbildschirms (Platzhalter: neutrale Fläche) |
| `Frontstage/ClassScreen/ClassScreenOverlay.swift` | `ClassScreenOverlay()` – Schicht über allen Inhalten außer `.dark` (Platzhalter: leer; 07: Timer) |
| `Frontstage/ClassScreen/ClassroomControls.swift` | `ClassroomControls()` – Knöpfe in der Smartboard-Leiste (Platzhalter: leer; 07: Timer, Arbeitsform) |
| `Frontstage/ClassScreen/ClassroomEnvironment.swift` | `extension View { func classroomEnvironment() -> some View }` (Platzhalter: `self`; 07: eigene Modelle in die Umgebung beider Szenen) |
| `Frontstage/App/FrontstageApp.swift` | **Modify** (Inhalt aus 04/08): App-Delegate, Zubehör und Umgebung am `DataScopedRoot` |
| `Frontstage/App/ScopedAppContent.swift` | **Modify** (Teilplan 04): in `ScopedServicesHolder.services(for:)` `viewerAvailable`, `penNotes` |
| `Frontstage/App/RootView.swift` | **Modify** (Teilplan 04): Nachholen der Warteliste in `activate(_:)`; den Platzhalter-Kommentar zum Szenen-Zubehör am Ende von `body` auf `FrontstageApp` verweisen lassen (angemeldet wird dort, Task 11 Step 8) |
| `Frontstage/UI/DayView/DayView.swift` | **Modify** (aus Teilplan 04): Smartboard-Leiste unten, Öffnen von PDF/Bild in der Anzeige |
| `Frontstage/Resources/Localizable.xcstrings` | **Modify**: Schlüssel dieses Teilplans |
| `FrontstageTests/Viewer/*Tests.swift`, `FrontstageTests/SecondScreen/SecondScreenStateTests.swift`, `FrontstageTests/TestSupport/ViewerTestSupport.swift` | App-Tests (Simulator) |

---

## Interfaces dieses Teilplans

```swift
// ── Kern (FrontstageCore) ──
public enum SecondScreenContent: Hashable, Sendable { case classScreen, material, board, dark }
public struct SecondScreenSelection: Hashable, Sendable {
  public init()
  public private(set) var mode: SecondScreenContent            // Start: .classScreen
  public private(set) var isMaterialOpen: Bool               // Start: false
  public private(set) var isBoardAvailable: Bool             // Start: false
  public var availableModes: [SecondScreenContent] { get }   // feste Reihenfolge classScreen, material?, board?, dark; .classScreen und .dark immer
  @discardableResult public mutating func select(_ mode: SecondScreenContent) -> Bool   // false = nicht verfügbar, unverändert
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

/// Namen neben dem Dokument (ADR-0011). Alle Namen NFC; `documentFileName` mit Endung, ohne Pfad.
public enum PenNoteFileLayout {
  public static let folderSuffix = ".frontstage-notizen"
  public static func notesFolderName(documentFileName: String) -> String            // "Arbeitsblatt Vokabeln.frontstage-notizen"
  public static func lessonFileName(for key: LessonKey) -> String                    // "2026-11-17_8b_englisch_1.json"
  /// Ausweichname, wenn die Stunden-Datei einem gleichnamigen Dokument anderer Endung gehört (Entscheidung 2).
  public static func alternateLessonFileName(for key: LessonKey, documentFileName: String) -> String   // "2026-11-17_8b_englisch_1.pdf.json"
  public static func lessonKey(fromLessonFileName name: String) -> LessonKey?        // beide Formen; sonst nil
  public static func notesPDFName(documentFileName: String, key: LessonKey) -> String   // "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf"
  /// Ist `name` ein Notiz-PDF dieses Dokuments? Liefert den Teil hinter „<Name> – Notizen “ (z. B. „8b 2026-11-17.pdf“).
  public static func notesPDFSuffix(_ name: String, documentFileName: String) -> String?
  /// true nur für den Notiz-Ordner, Dateien darin auf .json und Notiz-PDFs dieses Dokuments (relativ zum Ordner des Dokuments).
  public static func isNotesPath(_ relativePath: String, documentFileName: String) -> Bool
  public static func sanitized(_ component: String) -> String                        // / \ : * ? " < > | → -
}

/// Notiz-Datei einer Unterrichtsstunde (Glossar „Notiz-Datei“, `PenNoteFile`).
public struct PenNotePage: Codable, Hashable, Sendable {
  public var index: Int; public var width: Double; public var height: Double   // Seitengröße beim ersten Zeichnen, 0 = unbekannt
  public var drawing: Data                                                      // PKDrawing.dataRepresentation(), im JSON Base64
  public var updatedAt: Date
  public init(index: Int, width: Double, height: Double, drawing: Data, updatedAt: Date)
}
public struct PenNoteFile: Codable, Hashable, Sendable {
  public static let currentFormat = 1
  public var format: Int; public var lessonKey: String; public var document: String
  public var device: String; public var updatedAt: Date; public var pages: [PenNotePage]   // nach index sortiert, je index einmal
  public init(lessonKey: LessonKey, document: String, device: String, updatedAt: Date, pages: [PenNotePage])
  public func belongs(toDocument fileName: String) -> Bool                    // NFC, Groß/Klein egal
  /// Seite setzen; vorhandene Größe > 0 bleibt (Entscheidung 4).
  public func updating(pageIndex: Int, drawing: Data, currentSize: PageSize, now: Date, device: String) -> PenNoteFile
  /// Vor dem Schreiben: `changedPages` aus self, alle anderen aus `onDisk` (Entscheidung 3).
  public static func merged(local: PenNoteFile, changedPages: Set<Int>, onDisk: PenNoteFile?) -> PenNoteFile
  /// Schieben in eine Stunde mit vorhandener Datei: Seiten vereinigen, gleiche Seite über `combine` (App: PKDrawing.appending).
  public static func union(_ a: PenNoteFile, _ b: PenNoteFile, into key: LessonKey, now: Date, device: String, combine: (Data, Data) -> Data) -> PenNoteFile
  public func relabeled(lessonKey: LessonKey? = nil, document: String? = nil) -> PenNoteFile
}
public enum PenNoteFileDecodeError: Error, Equatable { case unreadable, newerFormat(Int) }
public enum PenNoteFileCoding {
  public static func encode(_ file: PenNoteFile) throws -> Data      // ISO 8601 UTC mit Millisekunden, Schlüssel sortiert, eingerückt
  public static func decode(_ data: Data) throws(PenNoteFileDecodeError) -> PenNoteFile
}

/// Eine Dateioperation, Pfade relativ zum Ordner des Dokuments (Quelle) bzw. des neuen Dokuments (Ziel).
public struct PenNoteTransfer: Hashable, Sendable {
  public enum Kind: Hashable, Sendable { case move, mergeNotes, dropDerived }   // dropDerived: Quell-PDF entfernen, Ziel wird neu erzeugt
  public var kind: Kind; public var from: String; public var to: String
}
public struct PenNoteRelocationPlan: Hashable, Sendable {
  public var transfers: [PenNoteTransfer]
  public var regeneratePDFFor: [String]            // lessonKey-Texte, deren Notiz-PDF danach neu zu erzeugen ist
  public var updatesDocumentName: String?          // Neu verknüpfen: neues `document` in jeder bewegten Stunden-Datei
}
public enum PenNoteRelocation {
  /// Schieben / Weiterreichen (FR-6.1): `existing` = vorhandene relative Pfade im Ordner des Dokuments.
  public static func planMove(documentFileName: String, from: LessonKey, to: LessonKey, existing: Set<String>) -> PenNoteRelocationPlan
  /// Neu verknüpfen (ADR-0011): alle Stunden-Dateien und Notiz-PDFs des alten Dokuments neben das neue.
  public static func planRelink(oldDocumentFileName: String, existingAtOld: Set<String>, newDocumentFileName: String, existingAtNew: Set<String>) -> PenNoteRelocationPlan
}

// ── App ──
/// Gemeinsamer, flüchtiger Zustand beider Szenen (Übersicht, Abstimmung Punkt 8).
@MainActor @Observable final class SecondScreenState {
  static let shared: SecondScreenState
  init()
  private(set) var state: SecondScreenSelection
  var content: SecondScreenContent { get }                    // = state.mode; „Dunkel“ ist .dark und gehört diesem Teilplan (FR-11.4)
  private(set) var isConnected: Bool
  private(set) var screenAspectRatio: Double                 // Breite/Höhe, Vorgabe 16/9
  private(set) var material: MaterialPresentation?
  private(set) var boardLessonKey: LessonKey?
  func select(_ mode: SecondScreenContent)
  func toggleDark()
  func openMaterial(_ presentation: MaterialPresentation)
  func closeMaterial()
  func showPage(_ pageIndex: Int, visibleRect: CGRect?)       // visibleRect in Seitenkoordinaten, nil = ganze Seite
  func updateDrawing(_ drawing: PKDrawing, pageIndex: Int)   // Seitenkoordinaten
  func setBoardLesson(_ key: LessonKey?)                      // Teilplan 07 und Anzeige
  func setBoardAvailable(_ available: Bool)                   // reicht an SecondScreenSelection durch (Teilplan 07)
  func displayConnected(aspectRatio: Double)
  func displayDisconnected()
}
struct MaterialPresentation: Equatable {
  let linkID: UUID; let documentData: Data; let kind: MaterialFileKind
  var pageIndex: Int; var visibleRect: CGRect?; var drawings: [Int: PKDrawing]
}

extension StorageService {   // Modify in StorageService.swift (Teilplan 03)
  /// Öffnet den Zugriff der Ordnerfreigabe (lesend und schreibend), ruft `body` außerhalb des Hauptthreads mit der URL,
  /// an der das Dokument liegt oder lag – die Datei selbst muss nicht existieren (Neu verknüpfen) – und schließt danach.
  /// Wirft StorageReadError.unresolvable, wenn Freigabe oder Ordner fehlen.
  func withDocumentLocation<T: Sendable>(for reference: MaterialReference, _ body: @escaping @Sendable (URL) throws -> T) async throws -> T
}
extension MaterialResolver { func resolveFolder(of reference: MaterialReference) -> ResolvedMaterial? }   // Modify: Ordner auflösen, letzte Komponente ungeprüft anhängen

enum PenNoteFileRead: Equatable, Sendable {
  case none                                     // keine Stunden-Datei für dieses Dokument
  case notes(PenNoteFile, fileName: String)
  case blocked(PenNoteBlockReason)              // vorhanden, aber nicht lesbar → nie überschreiben
}
enum PenNoteBlockReason: Equatable, Sendable { case notDownloaded, unreadable, newerFormat }
enum PenNoteWriteError: Error, Equatable { case notWritable, blocked(PenNoteBlockReason), failed }
/// Dateizugriff neben dem Dokument; `documentURL` aus StorageService.withDocumentLocation.
struct PenNoteFileStore: Sendable {
  func read(documentURL: URL, key: LessonKey) -> PenNoteFileRead
  /// Liest neu, führt mit `changedPages` zusammen (PenNoteFile.merged) und schreibt atomar; liefert den geschriebenen Stand.
  func write(_ local: PenNoteFile, changedPages: Set<Int>, documentURL: URL, key: LessonKey) throws(PenNoteWriteError) -> PenNoteFile
  func writePDF(_ data: Data, documentURL: URL, key: LessonKey) throws(PenNoteWriteError)
  func removePDF(documentURL: URL, key: LessonKey) throws(PenNoteWriteError)
  func existingNotesPaths(documentURL: URL) -> Set<String>
  func apply(_ plan: PenNoteRelocationPlan, sourceDocumentURL: URL, targetDocumentURL: URL, combine: (Data, Data) -> Data) throws(PenNoteWriteError)
}
/// Schmale Sicht für PenNoteStore, ViewerModel und PenNoteFileService; im Test durch `InMemoryPenNoteFiles` ersetzt.
protocol PenNoteFileAccessing: Sendable {
  func read(_ reference: MaterialReference, key: LessonKey) async -> PenNoteFileRead
  func write(_ local: PenNoteFile, changedPages: Set<Int>, reference: MaterialReference, key: LessonKey) async throws(PenNoteWriteError) -> PenNoteFile
  func writePDF(_ data: Data, reference: MaterialReference, key: LessonKey) async throws(PenNoteWriteError)
  func removePDF(reference: MaterialReference, key: LessonKey) async throws(PenNoteWriteError)
  func existingNotesPaths(_ reference: MaterialReference) async -> Set<String>?        // nil = Ort nicht erreichbar
  func apply(_ plan: PenNoteRelocationPlan, from: MaterialReference, to: MaterialReference) async throws(PenNoteWriteError)
}
struct StoragePenNoteFiles: PenNoteFileAccessing { init(storage: StorageService) }   // @MainActor-Aufrufe an storage, Datei-Arbeit im body

enum PenNoteLocation: Equatable { case besideDocument, appDataFallback, blocked(PenNoteBlockReason) }
struct StoredPenNote: Equatable { let drawing: PKDrawing; let savedSize: PageSize? }
/// Notizen einer geöffneten Anzeige: (Zuordnung → Dokument, Unterrichtsstunde).
@MainActor final class PenNoteStore {
  init(link: MaterialLinkRecord, files: any PenNoteFileAccessing, fallback: DataStore,
       deviceID: String = DeviceIdentity.current(), now: @escaping () -> Date = Date.init, saveDelay: Duration = .milliseconds(500))
  private(set) var location: PenNoteLocation               // nach loadAll() gültig
  private(set) var hasChangesThisSession: Bool
  var isEditable: Bool { get }                             // false bei .blocked
  func loadAll() async -> [Int: StoredPenNote]
  func scheduleSave(_ drawing: PKDrawing, pageIndex: Int, pageSize: PageSize)
  func flush() async
  func currentNotes() -> [Int: StoredPenNote]              // Stand im Speicher (für das Notiz-PDF)
}
enum PenNotePDFWriter {
  /// Seiten des Dokuments plus je Strich eine Ink-Anmerkung in PDF-Seitenkoordinaten; nil, wenn keine Striche.
  static func makePDF(document: PDFDocument, notes: [Int: StoredPenNote]) -> Data?
}
/// Umsetzung der Naht aus Teilplan 04 (Interfaces dort): Umbenennen beim Schieben, Mitnehmen beim Neu verknüpfen.
@MainActor final class PenNoteFileService: PenNoteFileRelocating {
  init(files: any PenNoteFileAccessing, pending: PendingPenNoteMoves = .init(), makePDF: @escaping @MainActor (MaterialReference, LessonKey) async -> Void)
  func linksMoved(_ moves: [PenNoteMove])                  // sofort in die Warteliste, dann abarbeiten
  func retryPending() async                                // Teil der Naht (04): beim Aktivwerden und vor dem Laden in der Anzeige
  func notesCount(beside old: MaterialReference) async -> Int
  func moveNotes(from old: MaterialReference, to new: MaterialReference) async throws
}
/// Geräte-lokale Warteliste der Umbenennungen (Application Support/PenNotes/pending-moves.json, isExcludedFromBackup).
struct PendingPenNoteMoves { init(directory: URL? = nil); func load() -> [PenNoteMove]; func save(_ moves: [PenNoteMove]) }

/// Liest Material nur lesend; Umsetzung `ScopedFileReader` über StorageService.readableFile(for:) → ScopedFile,
/// koordiniertes Lesen, danach close() (Übersicht, Abstimmung Punkt 9).
protocol MaterialFileReading: Sendable { func readData(for reference: MaterialReference) async throws -> Data }
struct ScopedFileReader: MaterialFileReading { init(storage: StorageService) }
#if os(iOS)
/// PKCanvasView als SwiftUI-Ansicht; Werkzeuge über PKToolPicker. Auch Teilplan 07 (Tafel) nutzt sie.
struct PenCanvas: UIViewRepresentable {
  init(drawing: Binding<PKDrawing>, isEditable: Bool, contentSize: CGSize, onStrokeEnded: @escaping () -> Void = {})
}
#endif
enum DrawingGeometry {
  static func pageSize(of page: PDFPage) -> PageSize                         // .mediaBox, Drehung angewandt
  static func toPageSpace(_ drawing: PKDrawing, viewSize: CGSize, pageSize: PageSize) -> PKDrawing
  static func toViewSpace(_ drawing: PKDrawing, viewSize: CGSize, pageSize: PageSize) -> PKDrawing
  /// Seitenkoordinaten (oben links, Drehung angewandt) → PDF-Seitenkoordinaten der mediaBox (unten links, ungedreht).
  static func pdfTransform(for page: PDFPage) -> CGAffineTransform
}
enum MaterialDocumentLoader {
  enum LoadError: Error, Equatable { case unreadable, unsupportedKind }
  static func makeDocument(from data: Data, kind: MaterialFileKind) throws(LoadError) -> PDFDocument
}
@MainActor @Observable final class ViewerModel {
  enum Phase: Equatable { case loading, ready, unavailable }
  init(link: MaterialLinkRecord, notes: PenNoteStore, fileReader: any MaterialFileReading, files: any PenNoteFileAccessing,
       secondScreen: SecondScreenState, beforeLoad: @escaping @MainActor () async -> Void = {})   // beforeLoad: PenNoteFileService.retryPending
  private(set) var phase: Phase
  private(set) var document: PDFDocument?
  private(set) var pageIndex: Int
  private(set) var fitByPage: [Int: PenNoteFit]               // nur Seiten mit Notiz
  var outdatedPages: [Int] { get }                            // .sizeChanged, aufsteigend
  var missingPages: [Int] { get }                             // .pageMissing, aufsteigend
  var notesLocation: PenNoteLocation { get }                  // für den Hinweis in der Anzeige
  var canDraw: Bool { get }                                   // iOS und notes.isEditable
  func load() async
  func drawingChanged(_ drawingInPageSpace: PKDrawing, pageIndex: Int)
  func pageChanged(to pageIndex: Int, visibleRect: CGRect?) async
  func flushNow() async                                       // Hintergrund
  func close() async                                          // flush, Notiz-PDF, secondScreen.closeMaterial()
}
struct ViewerView: View { init(linkID: UUID) }                // DataStore, StorageService, AppEnvironment aus der Umgebung (innerhalb DataScopedRoot)
struct SecondScreenRootView: View { init(state: SecondScreenState) }   // zeichnet content; .dark = Schwarz ohne Schicht
struct SmartboardBar: View { init() }                         // liest SecondScreenState aus der Umgebung; Umschalter inkl. „Dunkel“
// Einhängepunkte – Platzhalter dieses Teilplans, Besitzer und Inhalt: Teilplan 07
struct ClassScreenView: View { init() }                       // Inhalt .classScreen
struct BoardView: View { init() }                             // Inhalt .board
struct ClassScreenOverlay: View { init() }                    // Schicht über allen Inhalten außer .dark
struct ClassroomControls: View { init() }                     // Knöpfe in der SmartboardBar
extension View { func classroomEnvironment() -> some View }   // Modelle von 07 in die Umgebung beider Szenen
extension View { func secondScreenEnvironment() -> some View }           // eine Stelle für beide Szenen; ruft classroomEnvironment()
extension View { func registersSecondScreenAccessory() -> some View }    // nur iOS, an der Hauptansicht
```

**Consumes – Teilplan 01** (Kern): `LessonKey` (inkl. `init(date:schoolClass:subject:ordinal:)`, `storageText`, `init?(storageText:)`), `CalendarDay` (inkl. `init(year:month:day:)`, `storageText`), `SchoolClass.normalized`.

**Consumes – Teilplan 02** (Daten): `MaterialFileKind` (`.pdf`, `.image`, `opensInViewer`), `MaterialReference` (`folderGrantName`, `relativePath`, `fileKind`, `displayName`, `locationKey`); `MaterialLinkRecord` (`id`, `lessonKey`, `lessonKeyText`, `reference`, `penNotes`), `PenNoteRecord` (`materialLink`, `pageIndex`, `drawingData`, `pageWidth`, `pageHeight`, `updatedAt`); `DataStore.link(id:)`, `.penNotes(for:)`, `.penNote(for:pageIndex:)`, `.savePenNote(for:pageIndex:drawingData:pageWidth:pageHeight:)`, `.copyMaterialLinks(from:to:)`, `.moveLink(_:to:)`, `.assign(_:to:at:)`, `.links(for:)`; Test-Hilfe `makeStore()`.

**Consumes – Teilplan 03** (Ablage): `StorageService.readableFile(for:) -> ScopedFile?`, `ScopedFile.url`/`.close()`, `OpenOutcome.showInViewer(ScopedFile)`, `StorageReadError`, `MaterialResolver.resolve(_:)`, `ResolvedMaterial` (`fileURL`, `grantURL`), `FolderGrantStore`. Ordnerfreigaben sind lesend **und** schreibend (Umsetzung von 03).

**Consumes – Teilplan 04** (Oberfläche Kern): `ScopedServicesHolder.services(for:)` (Dienste je `DataStore`; `ScopedAppContent` ist nur der zustandslose Rahmen je Bereich), `RootView.activate(_:)` (Szenen-Haken), `AppEnvironment` (`viewerAvailable`, `penNotes`), `RootView`, `DayView`, `MaterialOpenAction.viewer(MaterialLinkItem)`, `PenNoteFileRelocating`, `PenNoteMove` (`reference`, `from`, `to`), `NoPenNoteFileRelocation`.

**Consumes – Teilplan 08** (Datenort): `DataScopedRoot`, `DeviceIdentity.current()`.

**Für Teilplan 07 bereitgestellt (Übersicht, Abstimmung Punkt 8):** `SecondScreenContent` (`classScreen`, `material`, `board`, `dark`), `SecondScreenState` (parameterloses `init`, `content`, `select(_:)`, `toggleDark()`, `setBoardLesson(_:)`, `boardLessonKey`, `isConnected`), `SecondScreenRootView`, `SmartboardBar`, `PenCanvas(drawing:isEditable:contentSize:onStrokeEnded:)` und die Einhängepunkte `ClassScreenView()`, `BoardView()`, `ClassScreenOverlay()`, `ClassroomControls()`, `classroomEnvironment()` – Platzhalter in den Ordnern von 07, deren Inhalt 07 ersetzt (Name und `init` bleiben). 07 ändert keine andere Datei dieses Teilplans. „Dunkel“ (FR-11.4) gehört als `.dark` diesem Teilplan und ist kostenlos (FR-13, Nutzerentscheidung 2026-11-13).

---

### Task 1: Zustand des Zweitbildschirms im Kern

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/SecondScreen/SecondScreenSelection.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/SecondScreen/SecondScreenSelectionTests.swift`

**Interfaces:**
- Consumes: –
- Produces: `SecondScreenContent`, `SecondScreenSelection` (siehe Interfaces-Block).

- [ ] **Step 1: Tests schreiben**

```swift
import Testing
@testable import FrontstageCore

struct SecondScreenSelectionTests {
  @Test("Startzustand ist Klassenbildschirm (FR-11)")
  func startsWithClassScreen() {
    let s = SecondScreenSelection()
    #expect(s.mode == .classScreen)
    #expect(s.availableModes == [.classScreen, .dark])
  }

  @Test("Öffnen zeigt Material, Schließen den Klassenbildschirm – nie die Tagesansicht (AK-23)")
  func openAndCloseMaterial() {
    var s = SecondScreenSelection()
    s.materialOpened();  #expect(s.mode == .material)
    s.materialClosed();  #expect(s.mode == .classScreen)
    #expect(!s.availableModes.contains(.material))
  }

  @Test("Dunkel und zurück zeigt wieder dasselbe Material (AK-28)")
  func darkRestoresPreviousMode() {
    var s = SecondScreenSelection()
    s.materialOpened()
    s.toggleDark();  #expect(s.mode == .dark)
    s.toggleDark();  #expect(s.mode == .material)
  }

  @Test("Umschalten Klassenbildschirm, Material, Tafel, Dunkel (AK-29)")
  func switchesThroughAllFourModes() {
    var s = SecondScreenSelection()
    s.materialOpened(); s.setBoardAvailable(true)
    for m in [SecondScreenContent.classScreen, .material, .board, .dark] {
      #expect(s.select(m)); #expect(s.mode == m)
    }
  }

  @Test("Nicht verfügbare Modi lassen den Zustand unverändert")
  func unavailableSelectionIsRejected() {
    var s = SecondScreenSelection()
    #expect(s.select(.material) == false); #expect(s.mode == .classScreen)
    #expect(s.select(.board) == false);    #expect(s.mode == .classScreen)
  }

  @Test("Material schließen während Dunkel: Dunkel bleibt, Rückweg führt zum Klassenbildschirm")
  func closeMaterialWhileDark() {
    var s = SecondScreenSelection()
    s.materialOpened(); s.toggleDark(); s.materialClosed()
    #expect(s.mode == .dark)
    s.toggleDark(); #expect(s.mode == .classScreen)
  }

  @Test("Material öffnen während Dunkel: bleibt dunkel, Rückweg zeigt das Material")
  func openMaterialWhileDark() {
    var s = SecondScreenSelection()
    s.toggleDark(); s.materialOpened()
    #expect(s.mode == .dark)
    s.toggleDark(); #expect(s.mode == .material)
  }

  @Test("Tafel nicht mehr verfügbar → Klassenbildschirm")
  func boardUnavailableFallsBack() {
    var s = SecondScreenSelection()
    s.setBoardAvailable(true); s.select(.board); s.setBoardAvailable(false)
    #expect(s.mode == .classScreen)
  }

  @Test("Verbinden hebt Dunkel auf, damit der Inhalt ohne Handgriff erscheint (AK-35)")
  func connectingClearsDark() {
    var s = SecondScreenSelection()
    s.toggleDark(); s.displayConnected()
    #expect(s.mode == .classScreen)
  }

  @Test("Verbinden lässt einen sichtbaren Modus unverändert (Review Focus 1)")
  func connectingKeepsVisibleMode() {
    var s = SecondScreenSelection()
    s.materialOpened(); s.displayConnected()
    #expect(s.mode == .material)
  }
}
```

- [ ] **Step 2: RED belegen** – `.\scripts\swift-test.ps1 -Filter SecondScreenSelection` → Kompilierfehler „cannot find 'SecondScreenSelection' in scope“.

- [ ] **Step 3: `SecondScreenSelection` implementieren** in `SecondScreenSelection.swift`. Ein privates Feld `modeBeforeDark: SecondScreenContent` (Start `.classScreen`) trägt den Rückweg aus Dunkel. `select(.dark)` verhält sich wie `toggleDark()` aus einem hellen Modus; `select` eines hellen Modus aus Dunkel hebt Dunkel auf. `materialClosed()`/`setBoardAvailable(false)` korrigieren sowohl `mode` als auch `modeBeforeDark`, wenn sie auf den weggefallenen Modus zeigen. `///`-Doku deutsch mit Verweis auf FR-11.4, FR-11.5, FR-6.2.

- [ ] **Step 4: GREEN belegen** – `.\scripts\swift-test.ps1 -Filter SecondScreenSelection` grün; alle Zweige aus Step 1 abgedeckt; keine Importe außer `Foundation`.

- [ ] **Step 5: Commit**

```bash
git add Packages/FrontstageCore/Sources/FrontstageCore/SecondScreen Packages/FrontstageCore/Tests/FrontstageCoreTests/SecondScreen
git commit -m "feat(core): second screen state with four modes"
```

---

### Task 2: Notiz-Datei im Kern – Passung, Namen, Format, Zusammenführen

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/PenNotes/PenNoteFit.swift`, `PenNoteFileLayout.swift`, `PenNoteFile.swift`, `PenNoteFileCoding.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/PenNotes/PenNoteFitTests.swift`, `PenNoteFileLayoutTests.swift`, `PenNoteFileTests.swift`

**Interfaces:**
- Consumes: `LessonKey` (`storageText`, `init?(storageText:)`), `CalendarDay.storageText`, `SchoolClass.normalized` (Teilplan 01).
- Produces: `PageSize`, `PenNoteFit`, `PenNoteFileLayout`, `PenNotePage`, `PenNoteFile`, `PenNoteFileCoding`, `PenNoteFileDecodeError` (Interfaces-Block).

- [ ] **Step 1: Failing Tests schreiben**

```swift
import Foundation
import Testing
@testable import FrontstageCore

struct PenNoteFitTests {
  let a4 = PageSize(width: 595, height: 842)

  @Test("Gleiche Seitengröße passt (ADR-0011)")
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

struct PenNoteFileLayoutTests {
  let tue8b = LessonKey(date: CalendarDay(year: 2026, month: 11, day: 17), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)

  @Test("Notiz-Ordner heißt wie das Dokument ohne Endung (ADR-0011)")
  func folderNameDropsExtension() {
    #expect(PenNoteFileLayout.notesFolderName(documentFileName: "Arbeitsblatt Vokabeln.pdf") == "Arbeitsblatt Vokabeln.frontstage-notizen")
    #expect(PenNoteFileLayout.notesFolderName(documentFileName: "Ohne Endung") == "Ohne Endung.frontstage-notizen")
  }
  @Test("Stunden-Datei: Schlüsseltext ohne verbotene Zeichen (Entscheidung 1)")
  func lessonFileNameIsFileSafe() {
    #expect(PenNoteFileLayout.lessonFileName(for: tue8b) == "2026-11-17_8b_englisch_1.json")
    let french = LessonKey(date: tue8b.date, schoolClass: SchoolClass("8/9"), subject: Subject("Französisch"), ordinal: 2)
    let name = PenNoteFileLayout.lessonFileName(for: french)
    #expect(!name.contains(where: { "|/\\:*?\"<>%".contains($0) }))
    #expect(PenNoteFileLayout.lessonKey(fromLessonFileName: name) == french)
  }
  @Test("Ausweichname für gleichnamiges Dokument anderer Endung (Entscheidung 2)")
  func alternateNameCarriesExtension() {
    let name = PenNoteFileLayout.alternateLessonFileName(for: tue8b, documentFileName: "Tafelbild.png")
    #expect(name == "2026-11-17_8b_englisch_1.png.json")
    #expect(PenNoteFileLayout.lessonKey(fromLessonFileName: name) == tue8b)
  }
  @Test("Fremde Dateien im Notiz-Ordner sind keine Stunden-Dateien")
  func foreignFileIsNoLessonFile() {
    #expect(PenNoteFileLayout.lessonKey(fromLessonFileName: ".DS_Store") == nil)
    #expect(PenNoteFileLayout.lessonKey(fromLessonFileName: "2026-11-17_8b_englisch_1-Lehrer-PC.json") == nil)
  }
  @Test("Notiz-PDF: Name, Klasse, Datum; zweite Stunde am Tag mit (2) (Entscheidung 6)")
  func notesPDFNames() {
    #expect(PenNoteFileLayout.notesPDFName(documentFileName: "Arbeitsblatt Vokabeln.pdf", key: tue8b) == "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf")
    let second = LessonKey(date: tue8b.date, schoolClass: tue8b.schoolClass, subject: tue8b.subject, ordinal: 2)
    #expect(PenNoteFileLayout.notesPDFName(documentFileName: "Arbeitsblatt Vokabeln.pdf", key: second) == "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17 (2).pdf")
    #expect(PenNoteFileLayout.notesPDFSuffix("Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf", documentFileName: "Arbeitsblatt Vokabeln.pdf") == "8b 2026-11-17.pdf")
    #expect(PenNoteFileLayout.notesPDFSuffix("Arbeitsblatt Vokabeln.pdf", documentFileName: "Arbeitsblatt Vokabeln.pdf") == nil)
  }
  @Test("Nur Notiz-Pfade sind schreibbar – nie das Original (FR-3.4)")
  func onlyNotesPathsAreWritable() {
    let doc = "Arbeitsblatt Vokabeln.pdf"
    #expect(PenNoteFileLayout.isNotesPath("Arbeitsblatt Vokabeln.frontstage-notizen/2026-11-17_8b_englisch_1.json", documentFileName: doc))
    #expect(PenNoteFileLayout.isNotesPath("Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf", documentFileName: doc))
    #expect(!PenNoteFileLayout.isNotesPath("Arbeitsblatt Vokabeln.pdf", documentFileName: doc))
    #expect(!PenNoteFileLayout.isNotesPath("Arbeitsblatt Vokabeln.frontstage-notizen/../Arbeitsblatt Vokabeln.pdf", documentFileName: doc))
    #expect(!PenNoteFileLayout.isNotesPath("Arbeitsblatt Vokabeln.frontstage-notizen/x.pdf", documentFileName: doc))
  }
}

struct PenNoteFileTests {
  let tue8b = LessonKey(date: CalendarDay(year: 2026, month: 11, day: 17), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
  func t(_ n: TimeInterval) -> Date { Date(timeIntervalSince1970: n) }
  func file(_ pages: [PenNotePage], at time: Date = Date(timeIntervalSince1970: 0)) -> PenNoteFile {
    PenNoteFile(lessonKey: tue8b, document: "Arbeitsblatt Vokabeln.pdf", device: "device-A", updatedAt: time, pages: pages)
  }
  func page(_ i: Int, _ byte: UInt8, at time: TimeInterval = 0) -> PenNotePage {
    PenNotePage(index: i, width: 595, height: 842, drawing: Data([byte]), updatedAt: t(time))
  }

  @Test("JSON-Rundlauf: Base64-Zeichnung, Zeit mit Millisekunden, sortierte Schlüssel")
  func roundTrip() throws {
    // .125 statt .123: binär exakt darstellbar, sonst kann der Rundlauf über Millisekunden-Text um ein ulp abweichen
    let original = file([page(0, 7, at: 1_763_368_500.125)], at: t(1_763_368_500.125))
    let data = try PenNoteFileCoding.encode(original)
    let text = String(decoding: data, as: UTF8.self)
    #expect(text.contains("\"lessonKey\" : \"2026-11-17|8b|englisch|1\""))
    #expect(text.contains(".125Z"))
    #expect(try PenNoteFileCoding.decode(data) == original)
  }
  @Test("Review Focus 4: neueres Format wird erkannt, nicht als leer gelesen")
  func decodeRejectsNewerFormat() throws {
    var newer = file([page(0, 1)]); newer.format = 2
    let data = try PenNoteFileCoding.encode(newer)
    #expect(throws: PenNoteFileDecodeError.newerFormat(2)) { try PenNoteFileCoding.decode(data) }
    #expect(throws: PenNoteFileDecodeError.unreadable) { try PenNoteFileCoding.decode(Data("kein json".utf8)) }
  }
  @Test("Erste Seitengröße bleibt beim Weiterschreiben (Entscheidung 4)")
  func updatingKeepsFirstSize() {
    let updated = file([page(0, 1)]).updating(pageIndex: 0, drawing: Data([2]), currentSize: PageSize(width: 842, height: 595), now: t(5), device: "device-A")
    #expect(updated.pages == [PenNotePage(index: 0, width: 595, height: 842, drawing: Data([2]), updatedAt: t(5))])
    let added = updated.updating(pageIndex: 3, drawing: Data([3]), currentSize: PageSize(width: 595, height: 842), now: t(6), device: "device-A")
    #expect(added.pages.map(\.index) == [0, 3])
  }
  @Test("Review Focus 6: Zusammenführen behält Seiten, die ein anderes Gerät geschrieben hat")
  func mergeKeepsPagesWrittenElsewhere() {
    let disk = file([page(0, 1), page(1, 9, at: 50)])                 // Seite 1 von einem anderen Gerät
    let local = file([page(0, 5, at: 60), page(1, 2)])                // hier nur Seite 0 geändert
    let merged = PenNoteFile.merged(local: local, changedPages: [0], onDisk: disk)
    #expect(merged.pages.map(\.drawing) == [Data([5]), Data([9])])
  }
  @Test("Zusammenführen ohne Datei auf der Platte nimmt den lokalen Stand")
  func mergeWithoutDiskUsesLocal() {
    let local = file([page(0, 5)])
    #expect(PenNoteFile.merged(local: local, changedPages: [0], onDisk: nil).pages == local.pages)
  }
  @Test("Vereinigen beim Schieben: gleiche Seite wird aneinandergehängt, nichts verloren (Entscheidung 8)")
  func unionCombinesSamePage() {
    let thu = LessonKey(date: CalendarDay(year: 2026, month: 11, day: 19), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
    let a = file([page(0, 1), page(2, 3)]); let b = file([page(0, 2)])
    let u = PenNoteFile.union(a, b, into: thu, now: t(9), device: "device-A", combine: { $0 + $1 })
    #expect(u.lessonKey == thu.storageText)
    #expect(u.pages.map(\.index) == [0, 2])
    #expect(u.pages[0].drawing == Data([1, 2]))
  }
  @Test("Dokument erkennen: NFC und Groß-/Kleinschreibung egal (Entscheidung 2)")
  func belongsToDocument() {
    let f = file([])
    #expect(f.belongs(toDocument: "arbeitsblatt vokabeln.PDF"))
    #expect(!f.belongs(toDocument: "Arbeitsblatt Vokabeln.png"))
  }
}
```

- [ ] **Step 2: RED belegen** – `.\scripts\swift-test.ps1 -Filter PenNote` → Kompilierfehler „cannot find 'PenNoteFit' in scope“ (bzw. die übrigen Typen).

- [ ] **Step 3: Implementieren.**
  - `PenNoteFit.evaluate`: `pageIndex >= pageCount` → `.pageMissing`; gespeicherte Größe fehlt oder Breite/Höhe ≤ 0 → `.fits`; sonst Vergleich je Achse mit `tolerance`.
  - `PenNoteFileLayout`: Endung = Teil hinter dem letzten `.` des Dateinamens (kein Punkt oder Punkt an Stelle 0 → keine Endung). Stunden-Datei: `key.storageText` mit `|` → `_`, `%` → `-`, Endung `.json`; Umkehrung ersetzt nur in Klasse und Fach `-` zurück zu `%` (das Datum enthält `-` und bleibt) und prüft über `LessonKey(storageText:)`; Ausweichname `<stamm>.<endung klein>.json`. Notiz-PDF: `"<Name ohne Endung> – Notizen <sanitized(schoolClass.normalized)> <date.storageText>"` + (`ordinal > 1` ? `" (\(ordinal))"` : `""`) + `".pdf"`, Halbgeviertstrich `–` (U+2013) mit Leerzeichen. `isNotesPath`: Pfad NFC, keine Komponente `..` oder leer; entweder genau `<Ordner>/<Datei>.json` mit `lessonKey(fromLessonFileName:) != nil`, genau `<Ordner>` selbst, oder genau ein Notiz-PDF ohne Unterordner.
  - `PenNoteFile`: `pages` nach dem Ändern sortiert, je `index` einmal; `belongs` vergleicht `precomposedStringWithCanonicalMapping.lowercased()`; `merged`: Seiten aus `onDisk` übernehmen, dann jede Seite aus `changedPages` aus `local` setzen, Seiten nur in `local` (nicht in `changedPages`, nicht auf der Platte) behalten; `updatedAt`/`device` von `local`. `union`: alle Seiten beider, gleiche `index` → `drawing = combine(a, b)`, Größe von `a`, `updatedAt = now`.
  - `PenNoteFileCoding`: `JSONEncoder` mit `.sortedKeys, .prettyPrinted`, Datum als Text über `Date.ISO8601FormatStyle(includingFractionalSeconds: true)` (UTC; Vorbild `DataFolderCoding` im Kern – `Sendable`, anders als ein geteilter `ISO8601DateFormatter` unter Swift 6); `Data` als Base64 (Standard des Encoders). `decode`: zuerst nur `format` lesen – fehlt es oder ist das JSON kaputt → `.unreadable`; `format > currentFormat` → `.newerFormat(format)`; dann ganz dekodieren.
  - `///`-Doku deutsch mit Verweis auf ADR-0011 und die Entscheidungen 1–4, 6, 8.

- [ ] **Step 4: GREEN belegen** – `.\scripts\swift-test.ps1 -Filter PenNote` grün; danach die ganze Kern-Suite.
- [ ] **Step 5: Diff durchsehen** – nur `import Foundation`; Einrückung zwei Leerzeichen (wie Teilplan 01).
- [ ] **Step 6: Commit** – `git commit -m "feat(core): pen note file layout, format and page merge"`

---

### Task 3: Schieben und Neu verknüpfen als Dateioperationen im Kern

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/PenNotes/PenNoteRelocation.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/PenNotes/PenNoteRelocationTests.swift`

**Interfaces:**
- Consumes: `PenNoteFileLayout` (Task 2), `LessonKey` (01).
- Produces: `PenNoteTransfer`, `PenNoteRelocationPlan`, `PenNoteRelocation.planMove(...)`, `.planRelink(...)`.

- [ ] **Step 1: Failing Tests schreiben**

```swift
import Testing
@testable import FrontstageCore

struct PenNoteRelocationTests {
  let doc = "Arbeitsblatt Vokabeln.pdf"
  let folder = "Arbeitsblatt Vokabeln.frontstage-notizen"
  let tue = LessonKey(date: CalendarDay(year: 2026, month: 11, day: 17), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
  let thu = LessonKey(date: CalendarDay(year: 2026, month: 11, day: 19), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)

  @Test("AK-22: Schieben benennt Stunden-Datei und Notiz-PDF auf die neue Stunde um")
  func moveRenamesBoth() {
    let plan = PenNoteRelocation.planMove(documentFileName: doc, from: tue, to: thu,
      existing: ["\(folder)/2026-11-17_8b_englisch_1.json", "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf"])
    #expect(plan.transfers == [
      PenNoteTransfer(kind: .move, from: "\(folder)/2026-11-17_8b_englisch_1.json", to: "\(folder)/2026-11-19_8b_englisch_1.json"),
      PenNoteTransfer(kind: .move, from: "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf", to: "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-19.pdf"),
    ])
    #expect(plan.regeneratePDFFor.isEmpty)
  }
  @Test("Ohne Notizen: nichts zu tun")
  func moveWithoutNotesIsEmpty() {
    #expect(PenNoteRelocation.planMove(documentFileName: doc, from: tue, to: thu, existing: []).transfers.isEmpty)
  }
  @Test("Ziel hat schon Notizen: zusammenführen, altes PDF weg, Ziel-PDF neu (Entscheidung 8)")
  func moveIntoLessonWithNotesMerges() {
    let plan = PenNoteRelocation.planMove(documentFileName: doc, from: tue, to: thu, existing: [
      "\(folder)/2026-11-17_8b_englisch_1.json", "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf",
      "\(folder)/2026-11-19_8b_englisch_1.json", "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-19.pdf"])
    #expect(plan.transfers.map(\.kind) == [.mergeNotes, .dropDerived])
    #expect(plan.regeneratePDFFor == [thu.storageText])
  }
  @Test("Ausweichname (gleichnamiges Bild) wandert mit seinem Namen")
  func alternateNameMoves() {
    let plan = PenNoteRelocation.planMove(documentFileName: "Tafelbild.png", from: tue, to: thu,
      existing: ["Tafelbild.frontstage-notizen/2026-11-17_8b_englisch_1.png.json"])
    #expect(plan.transfers == [PenNoteTransfer(kind: .move, from: "Tafelbild.frontstage-notizen/2026-11-17_8b_englisch_1.png.json", to: "Tafelbild.frontstage-notizen/2026-11-19_8b_englisch_1.png.json")])
  }
  @Test("Neu verknüpfen: alle Stunden-Dateien und PDFs neben die neue Datei, PDFs mit neuem Namen")
  func relinkMovesAllNotes() {
    let plan = PenNoteRelocation.planRelink(oldDocumentFileName: doc, existingAtOld: [
        "\(folder)/2026-11-17_8b_englisch_1.json", "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf", "\(folder)/.DS_Store"],
      newDocumentFileName: "Vokabeln neu.pdf", existingAtNew: [])
    #expect(Set(plan.transfers) == [
      PenNoteTransfer(kind: .move, from: "\(folder)/2026-11-17_8b_englisch_1.json", to: "Vokabeln neu.frontstage-notizen/2026-11-17_8b_englisch_1.json"),
      PenNoteTransfer(kind: .move, from: "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf", to: "Vokabeln neu – Notizen 8b 2026-11-17.pdf"),
    ])
    #expect(plan.updatesDocumentName == "Vokabeln neu.pdf")
  }
  @Test("Neu verknüpfen in einen Ordner mit Notizen derselben Stunde: zusammenführen, nie überschreiben")
  func relinkMergesExisting() {
    let plan = PenNoteRelocation.planRelink(oldDocumentFileName: doc, existingAtOld: ["\(folder)/2026-11-17_8b_englisch_1.json"],
      newDocumentFileName: "Vokabeln neu.pdf", existingAtNew: ["Vokabeln neu.frontstage-notizen/2026-11-17_8b_englisch_1.json"])
    #expect(plan.transfers.map(\.kind) == [.mergeNotes])
    #expect(plan.regeneratePDFFor == [tue.storageText])
  }
}
```

- [ ] **Step 2: RED belegen** – `.\scripts\swift-test.ps1 -Filter PenNoteRelocation`.
- [ ] **Step 3: Implementieren.** `planMove`: Kandidaten sind die Stunden-Datei unter Standard- und unter Ausweichname sowie das Notiz-PDF von `from`, jeweils nur wenn in `existing`; Zielname aus `PenNoteFileLayout` für `to`; Stunden-Datei: Ziel vorhanden → `.mergeNotes` und `to.storageText` in `regeneratePDFFor`, sonst `.move`; Notiz-PDF: Ziel vorhanden oder Stunden-Datei wird zusammengeführt → `.dropDerived`, sonst `.move`. Reihenfolge: Stunden-Datei vor PDF. `planRelink`: jede Datei im alten Notiz-Ordner mit `lessonKey(fromLessonFileName:) != nil` (andere – `.DS_Store`, Konfliktkopien der Anbieter – bleiben liegen) und jedes Notiz-PDF (`notesPDFSuffix != nil`) des alten Dokuments; Zielnamen mit dem neuen Dokumentnamen; Ziel vorhanden → wie oben; `updatesDocumentName = newDocumentFileName`.
- [ ] **Step 4: GREEN belegen**, ganze Kern-Suite grün.
- [ ] **Step 5: Diff durchsehen.**
- [ ] **Step 6: Commit** – `git commit -m "feat(core): plan pen note renames for move and relink"`

---

### Task 4: `SecondScreenState` – gemeinsamer Zustand beider Szenen

Design-Takt: keiner

**Files:**
- Create: `Frontstage/SecondScreen/SecondScreenState.swift`
- Test: `FrontstageTests/SecondScreen/SecondScreenStateTests.swift` (nutzt `TestDrawings`, `TestKeys` aus `ViewerTestSupport.swift` – legt Task 5 an; bei Umsetzung vor Task 5 die Datei hier schon mit diesen beiden Hilfen anlegen)

**Interfaces:**
- Consumes: `SecondScreenSelection` (Task 1), `LessonKey` (Teilplan 01).
- Produces: `SecondScreenState`, `MaterialPresentation` (Interfaces-Block).

Swift-Hinweis: `@Observable` (Framework Observation) macht jede gespeicherte Eigenschaft beobachtbar; eine SwiftUI-Ansicht, die sie im `body` liest, wird bei Änderung neu gezeichnet – in **beiden** Szenen, weil beide dasselbe Objekt (`SecondScreenState.shared`) halten. `@MainActor` sorgt unter Swift 6 dafür, dass nur der Haupt-Thread es ändert.

- [ ] **Step 1: Tests schreiben**

```swift
@MainActor struct SecondScreenStateTests {
  let presentation = MaterialPresentation(linkID: UUID(), documentData: Data(), kind: .pdf, pageIndex: 0, visibleRect: nil, drawings: [:])

  @Test("Material öffnen und schließen (AK-23)")
  func openAndClose() {
    let m = SecondScreenState()
    m.openMaterial(presentation); #expect(m.state.mode == .material && m.material != nil)
    m.closeMaterial();            #expect(m.state.mode == .classScreen && m.material == nil)
  }
  @Test("Verbinden lässt den aktuellen Modus stehen (Review Focus 1)")
  func connectingKeepsCurrentMode() {
    let m = SecondScreenState()
    m.openMaterial(presentation); m.displayConnected(aspectRatio: 16.0 / 9.0)
    #expect(m.isConnected && m.state.mode == .material)
  }
  @Test("Trennen behält Zustand und Zeichnungen (Review Focus 2)")
  func disconnectKeepsStateAndDrawings() {
    let m = SecondScreenState()
    m.openMaterial(presentation); m.updateDrawing(TestDrawings.word, pageIndex: 0); m.displayDisconnected()
    #expect(!m.isConnected && m.state.mode == .material)
    #expect(m.material?.drawings[0]?.strokes.count == TestDrawings.word.strokes.count)
  }
  @Test("Seitenwechsel und Zoom werden übertragen")
  func showPageUpdatesPresentation() {
    let m = SecondScreenState()
    m.openMaterial(presentation); m.showPage(1, visibleRect: CGRect(x: 0, y: 0, width: 200, height: 100))
    #expect(m.material?.pageIndex == 1 && m.material?.visibleRect?.width == 200)
  }
  @Test("Bildformat des Bildschirms wird übernommen, Vorgabe 16:9")
  func aspectRatio() {
    let m = SecondScreenState()
    #expect(abs(m.screenAspectRatio - 16.0 / 9.0) < 0.001)
    m.displayConnected(aspectRatio: 4.0 / 3.0)
    #expect(abs(m.screenAspectRatio - 4.0 / 3.0) < 0.001)
  }
  @Test("Tafel wählbar nur mit Unterrichtsstunde")
  func boardRequiresLesson() {
    let m = SecondScreenState()
    m.select(.board);                     #expect(m.state.mode == .classScreen)
    m.setBoardLesson(TestKeys.tue8aEnglish); m.select(.board); #expect(m.state.mode == .board)
    m.setBoardLesson(nil);                #expect(m.state.mode == .classScreen)
  }
  @Test("Zeichnung ohne offenes Material wird ignoriert")
  func drawingWithoutMaterialIsIgnored() {
    let m = SecondScreenState()
    m.updateDrawing(TestDrawings.word, pageIndex: 0)
    #expect(m.material == nil)
  }
}
```

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: `SecondScreenState` implementieren** – dünne Hülle um `SecondScreenSelection`; `static let shared = SecondScreenState()`; `displayConnected` ruft `state.displayConnected()`; `screenAspectRatio` nur übernehmen, wenn Wert > 0. `setBoardLesson(_:)` setzt `boardLessonKey` und ruft `state.setBoardAvailable(key != nil)` (Test `boardRequiresLesson`); `openMaterial`/`closeMaterial` rufen `materialOpened()`/`materialClosed()` und setzen bzw. leeren `material`. `MaterialPresentation` in derselben Datei.
- [ ] **Step 4: Diff durchsehen** – Datei kompiliert auch für macOS (nur `PencilKit`, `Foundation`, `Observation`, `FrontstageCore`).
- [ ] **Step 5: Commit** – `git commit -m "feat(second-screen): observable shared state for both scenes"`

---

### Task 5: Dateien neben dem Dokument – Geometrie, `PenNoteFileStore`, Zugang über die Ablage

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Viewer/DrawingGeometry.swift`, `Frontstage/Viewer/PenNotes/PenNoteFileStore.swift`, `Frontstage/Viewer/PenNotes/PenNoteFileAccess.swift`
- Modify: `Frontstage/Storage/StorageService.swift`, `Frontstage/Storage/MaterialResolver.swift` (Teilplan 03 – nur ergänzen; vorher ganz lesen)
- Create: `FrontstageTests/TestSupport/ViewerTestSupport.swift`
- Test: `FrontstageTests/Viewer/DrawingGeometryTests.swift`, `FrontstageTests/Viewer/PenNoteFileStoreTests.swift`

**Interfaces:**
- Consumes: `PenNoteFileLayout`, `PenNoteFile`, `PenNoteFileCoding`, `PenNoteRelocationPlan` (Task 2, 3); `MaterialResolver.resolve(_:)`, `ResolvedMaterial`, `StorageReadError`, `FileFactsReader.facts(at:)` (03).
- Produces: `DrawingGeometry`, `PenNoteFileStore`, `PenNoteFileRead`, `PenNoteBlockReason`, `PenNoteWriteError`, `PenNoteFileAccessing`, `StoragePenNoteFiles`, `StorageService.withDocumentLocation(for:_:)`, `MaterialResolver.resolveFolder(of:)`; Test-Hilfen `TestDrawings`, `TestDocuments`, `TestKeys`, `TestStore`, `InMemoryPenNoteFiles`.

Swift-Hinweis: `NSFileCoordinator` sorgt dafür, dass der Ablage-Anbieter (iCloud Drive, OneDrive-App …) eine Datei nicht gleichzeitig abgleicht, während die App sie schreibt; bei iCloud lädt ein koordiniertes Lesen eine noch nicht geladene Datei. Er blockiert den aufrufenden Thread – deshalb läuft alle Datei-Arbeit im `body` von `withDocumentLocation` außerhalb des Hauptthreads.

- [ ] **Step 1: Failing Tests schreiben** (temporärer Ordner als Stand-in für den Ordner des Dokuments; `PenNoteFileStore` arbeitet nur mit URLs und ist ohne `StorageService` prüfbar)

```swift
import Foundation
import FrontstageCore
import PDFKit
import PencilKit
import Testing

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
  @Test("Oben links der Seite wird oben links der mediaBox im PDF (y nach oben)")
  func pdfTransformFlipsY() {
    let page = TestDocuments.page(width: 595, height: 842, rotation: 0)
    let p = CGPoint(x: 10, y: 20).applying(DrawingGeometry.pdfTransform(for: page))
    #expect(abs(p.x - 10) < 0.01 && abs(p.y - 822) < 0.01)
  }
  @Test("Gedrehte Seite: Punkt landet in der ungedrehten mediaBox")
  func pdfTransformHandlesRotation() {
    let page = TestDocuments.page(width: 595, height: 842, rotation: 90)
    let p = CGPoint(x: 0, y: 0).applying(DrawingGeometry.pdfTransform(for: page))
    #expect(page.bounds(for: .mediaBox).insetBy(dx: -0.01, dy: -0.01).contains(p))
  }
}

@Suite struct PenNoteFileStoreTests {
  let store = PenNoteFileStore()
  @Test("Schreiben legt Notiz-Ordner und Stunden-Datei neben dem Dokument an; Original unverändert (AK-13)")
  func writeCreatesFolderAndFile() throws {
    let dir = try TestFolders.make(with: ["Arbeitsblatt Vokabeln.pdf": TestDocuments.pdfData(pages: 1, size: .a4)])
    let doc = dir.appending(path: "Arbeitsblatt Vokabeln.pdf"); let before = try Data(contentsOf: doc)
    _ = try store.write(TestFiles.note(TestKeys.tue8bEnglish, pages: [0]), changedPages: [0], documentURL: doc, key: TestKeys.tue8bEnglish)
    #expect(FileManager.default.fileExists(atPath: dir.appending(path: "Arbeitsblatt Vokabeln.frontstage-notizen/2026-11-17_8b_englisch_1.json").path))
    #expect(try Data(contentsOf: doc) == before)
    guard case .notes(let read, _) = store.read(documentURL: doc, key: TestKeys.tue8bEnglish) else { Issue.record(); return }
    #expect(read.pages.map(\.index) == [0])
  }
  @Test("Review Focus 6: Schreiben liest neu und behält fremde Seiten")
  func writeMergesWithDisk() throws {
    let (doc, key) = try TestFolders.documentWithNote(pages: [1])        // Seite 1 „vom anderen Gerät“
    let written = try store.write(TestFiles.note(key, pages: [0]), changedPages: [0], documentURL: doc, key: key)
    #expect(written.pages.map(\.index) == [0, 1])
  }
  @Test("Review Focus 4: kaputte oder neuere Datei wird nie überschrieben")
  func blockedFileIsNotOverwritten() throws {
    let (doc, key) = try TestFolders.documentWithRawNote(Data("{".utf8))
    #expect(store.read(documentURL: doc, key: key) == .blocked(.unreadable))
    #expect(throws: PenNoteWriteError.blocked(.unreadable)) { _ = try store.write(TestFiles.note(key, pages: [0]), changedPages: [0], documentURL: doc, key: key) }
    #expect(try TestFolders.rawNote(beside: doc, key: key) == Data("{".utf8))
  }
  @Test("Nicht beschreibbarer Ordner meldet notWritable (Review Focus 5)")
  func readOnlyFolderIsNotWritable() throws {
    let (doc, key) = try TestFolders.readOnlyDocument()                  // Ordner mit Rechten 0o555
    #expect(throws: PenNoteWriteError.notWritable) { _ = try store.write(TestFiles.note(key, pages: [0]), changedPages: [0], documentURL: doc, key: key) }
  }
  @Test("Gleichnamiges Bild schreibt unter dem Ausweichnamen (Entscheidung 2)")
  func sameStemOtherExtensionUsesAlternateName() throws {
    let (pdf, key) = try TestFolders.documentWithNote(pages: [0], documentName: "Tafelbild.pdf")
    let png = pdf.deletingLastPathComponent().appending(path: "Tafelbild.png")
    #expect(store.read(documentURL: png, key: key) == .none)
    _ = try store.write(TestFiles.note(key, pages: [0], document: "Tafelbild.png"), changedPages: [0], documentURL: png, key: key)
    #expect(store.existingNotesPaths(documentURL: png).contains("Tafelbild.frontstage-notizen/2026-11-17_8b_englisch_1.png.json"))
    guard case .notes(let pdfNotes, _) = store.read(documentURL: pdf, key: key) else { Issue.record(); return }
    #expect(pdfNotes.document == "Tafelbild.pdf")
  }
  @Test("Umbenennen nach Plan; Original und fremde Dateien bleiben (AK-22)")
  func applyMovePlan() throws {
    let (doc, key) = try TestFolders.documentWithNote(pages: [0], withPDF: true)
    let plan = PenNoteRelocation.planMove(documentFileName: doc.lastPathComponent, from: key, to: TestKeys.thu8bEnglish, existing: store.existingNotesPaths(documentURL: doc))
    try store.apply(plan, sourceDocumentURL: doc, targetDocumentURL: doc, combine: { $0 + $1 })
    #expect(store.read(documentURL: doc, key: key) == .none)
    guard case .notes(let moved, _) = store.read(documentURL: doc, key: TestKeys.thu8bEnglish) else { Issue.record(); return }
    #expect(moved.lessonKey == TestKeys.thu8bEnglish.storageText)          // Feld in der Datei mit umgestellt
    #expect(FileManager.default.fileExists(atPath: doc.path))
  }
  @Test("Ein Pfad außerhalb der Notiz-Pfade wird verweigert (FR-3.4)")
  func refusesNonNotesPath() throws {
    let (doc, _) = try TestFolders.documentWithNote(pages: [0])
    let evil = PenNoteRelocationPlan(transfers: [PenNoteTransfer(kind: .move, from: doc.lastPathComponent, to: "x.pdf")], regeneratePDFFor: [], updatesDocumentName: nil)
    #expect(throws: PenNoteWriteError.failed) { try store.apply(evil, sourceDocumentURL: doc, targetDocumentURL: doc, combine: { $0 + $1 }) }
    #expect(FileManager.default.fileExists(atPath: doc.path))
  }
}
```

`ViewerTestSupport.swift` (Create): `TestDrawings` (`line(from:to:)`, `word`, `twoWords` – aus `PKStroke`s gebaut), `TestDocuments` (`page(width:height:rotation:)`, `pdfData(pages:size:)`, `pngData(width:height:)`), `TestKeys` (`tue8aEnglish`, `wed8bEnglish`, `thu8aEnglish`, `tue8bEnglish`, `thu8bEnglish` – nur `8a`/`8b`, „Englisch“, 17.–19.11.2026), `PageSize.a4` (`595 × 842`, Test-Erweiterung), `TestFolders` (`make(with: [String: Data]) -> URL`, `documentWithNote(pages:documentName: = "Arbeitsblatt Vokabeln.pdf", withPDF: = false) -> (URL, LessonKey)` mit Schlüssel `TestKeys.tue8bEnglish`, `documentWithRawNote(_: Data)`, `rawNote(beside:key:) -> Data`, `readOnlyDocument()` – temporäre Ordner), `TestFiles.note(_:pages:document: = "Arbeitsblatt Vokabeln.pdf")`, `TestFiles.reference(_ relativePath:)` (Freigabe-Name fest, `displayName` = letzter Pfadteil, `fileKind` aus der Endung), `TestStore.contextWithLink(key: = TestKeys.tue8aEnglish, kind: = .pdf)` → `(DataStore, MaterialLinkRecord)` über `makeStore()` (02) und `assign(_:to:at:)`, `TestStore.addLink(to:sameFileAs:key:) -> MaterialLinkRecord` (gleicher Verweis, andere Stunde), `TestStore.addFallbackNote(to:link:page:drawing:updatedAt:size:)` über `savePenNote` bzw. direkt im `modelContext` (doppelte Datensätze nachstellen), `InMemoryPenNoteFiles` (`actor`, `PenNoteFileAccessing`; `init(blocked: PenNoteBlockReason? = nil, notWritable: Bool = false, unreachable: Bool = false)`; hält Dateien je `MaterialReference.locationKey` als `PenNoteFileStore` auf einem temporären Ordner; `put(_:for:withPDF: = false)`, `setUnreachable(_:)`, `writeCount`, `pdfWriteCount`, `lessonKeys(for:) -> [LessonKey]`, `pdfNames(for:) -> [String]`, `documentName(for:key:) -> String?`). Die Hilfen ohne `@MainActor` außer `TestStore` (die Suiten `PenNoteFileStoreTests` und `PenNotePDFWriterTests` laufen nicht auf dem Hauptakteur); PDF-Testdaten über CoreGraphics/PDFKit, nicht über UIKit-Renderer. `TestViewer`, `StubReader`, `StubError` ergänzt Task 7, `PendingPenNoteMoves.inTemporaryDirectory()` Task 9.

Kopf jeder neuen App-Testdatei dieses Teilplans (auch Task 4, 6–9) wie oben: `import Foundation`, `import FrontstageCore` (nicht `@testable` – der Kern ist ein eigenes Paket, die Bestandstests importieren ihn ebenso), `PDFKit`/`PencilKit` nach Bedarf, `import Testing`, `@testable import Frontstage`. Mehrere Module in einer `import`-Zeile gibt es in Swift nicht. `DataStore` ist im Testziel über `TestSupport/TypeAliases.swift` eindeutig.

- [ ] **Step 2: Diff durchsehen** (erwartet im CI ohne Step 3: Kompilierfehler).

- [ ] **Step 3: `DrawingGeometry` implementieren.** `pageSize(of:)`: `page.bounds(for: .mediaBox).size`, bei `page.rotation` 90/270 Breite und Höhe tauschen. `toPageSpace`/`toViewSpace`: `drawing.transformed(using: CGAffineTransform(scaleX:y:))` mit dem Verhältnis Seitengröße ÷ Darstellungsgröße bzw. umgekehrt, je Achse getrennt. `pdfTransform(for:)`: gedrehte Seitenkoordinaten (oben links) → y spiegeln (`y' = höhe − y`) → um `−rotation` um die Mitte zurückdrehen → um `mediaBox.origin` verschieben; je Drehung (0/90/180/270) als feste Matrix, im Test für 0 und 90 belegt.

- [ ] **Step 4: Ergänzung Teilplan 03.** `MaterialResolver.resolveFolder(of:)`: wie `resolve`, löst aber nur die Ordnerkomponenten auf (dieselbe Namensnachsicht über `StoragePath.matchName`) und hängt den Dateinamen unverändert an; `nil`, wenn Freigabe oder ein Ordner fehlt. `StorageService.withDocumentLocation(for:_:)`: `resolver.resolveFolder(of:)` → `nil` wirft `StorageReadError.unresolvable`; `grantURL.startAccessingSecurityScopedResource()`, `body(fileURL)` in `Task.detached` (Swift-Hinweis: läuft so nicht auf dem `@MainActor`), danach in jedem Fall `stopAccessing…`. Keine Entscheidung über Wege – nur Zugang.

- [ ] **Step 5: `PenNoteFileStore` implementieren** (`struct`, `Sendable`, nur URLs):
  - Jeder Pfad wird relativ zum Ordner des Dokuments gebildet und vor jedem Schreiben, Verschieben oder Löschen mit `PenNoteFileLayout.isNotesPath` geprüft – sonst `.failed`, ohne Dateizugriff.
  - `read`: Standardname, gehört die Datei einem anderen Dokument (`belongs(toDocument:) == false`) → Ausweichname. Ist die Datei laut `FileFactsReader` nicht geladen, einmal koordiniert lesen (`coordinate(readingItemAt:options: [])`); scheitert das → `.blocked(.notDownloaded)`. `decode` → `.unreadable` bzw. `.newerFormat` → `.blocked(…)`.
  - `write`: zuerst `read`; `.blocked(r)` → `throw .blocked(r)`; `PenNoteFile.merged(local:changedPages:onDisk:)`; Ordner koordiniert anlegen (`coordinate(writingItemAt: ordner, options: .forReplacing)` + `createDirectory(withIntermediateDirectories: false)`, „existiert schon“ ist kein Fehler); Datei koordiniert `.forReplacing` und `write(to:options: .atomic)`. Fehlerabbildung: `CocoaError.fileWriteNoPermission`, `.fileWriteVolumeReadOnly`, POSIX `EACCES`/`EPERM`/`EROFS` → `.notWritable`; alles andere → `.failed` (mit `Logger`, Kategorie `PenNotes`, ohne Inhalte).
  - `writePDF`/`removePDF`: Name aus `notesPDFName`; koordiniert `.forReplacing` bzw. `.forDeleting`; fehlende Datei beim Entfernen ist kein Fehler.
  - `existingNotesPaths`: Inhalt des Notiz-Ordners (`<Ordner>/<Datei>`) plus Dateien im Ordner des Dokuments mit `notesPDFSuffix != nil`.
  - `apply`: je Transfer `.move` → koordiniert `.forMoving`/`.forReplacing` und `moveItem`, bei Stunden-Dateien danach `relabeled(lessonKey:document:)` neu schreiben; `.mergeNotes` → beide lesen (eine `blocked` → abbrechen, nichts ändern), `PenNoteFile.union(..., combine:)` schreiben, Quelle löschen; `.dropDerived` → Quelle löschen. Leeren Notiz-Ordner des alten Orts entfernen. Bricht ein Schritt ab, bleiben schon ausgeführte Schritte bestehen – die Warteliste (Task 9) wiederholt nur den Rest, weil `planMove` aus den **vorhandenen** Pfaden neu geplant wird.
- [ ] **Step 6: `PenNoteFileAccessing` und `StoragePenNoteFiles`** – jede Methode = `storage.withDocumentLocation(for: reference) { url in try PenNoteFileStore().… }`; `StorageReadError` beim Lesen → `.blocked(.notDownloaded)` nur wenn die Datei fehlt, sonst `.none`; beim Schreiben → `.failed`; `existingNotesPaths` → `nil` bei nicht auflösbarem Ort. `apply(from:to:)` öffnet nacheinander beide Orte (verschachtelter Aufruf, zwei Freigaben können verschieden sein).
- [ ] **Step 7: Diff durchsehen** – kein Schreibaufruf ohne `isNotesPath`; jede Datei-Arbeit außerhalb des Hauptthreads; keine Datei-API in Ansichten.
- [ ] **Step 8: Commit** – `git commit -m "feat(viewer): read and write pen note files beside the document"`

---

### Task 6: `PenNoteStore` – Notizen einer Anzeige, verzögertes Speichern, Ersatz im Datenort

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Viewer/PenNotes/PenNoteStore.swift`
- Modify: `Frontstage/Data/DataStore+MaterialLinks.swift` (Teilplan 02; Abschnitt „Stiftnotizen“, dort stehen `penNotes(for:)` und `savePenNote`) – neue Methode `func removePenNotes(for link: MaterialLinkRecord) throws` (löscht die `PenNoteRecord`s der Zuordnung, speichert; der Abgleich aus 08 schreibt dafür Löschmarken)
- Test: `FrontstageTests/Viewer/PenNoteStoreTests.swift`

**Interfaces:**
- Consumes: `PenNoteFileAccessing` (Task 5), `PenNoteFile`, `PageSize` (Task 2), `DataStore.penNotes(for:)`, `.savePenNote(...)` (02), `DeviceIdentity.current()` (08).
- Produces: `PenNoteStore`, `PenNoteLocation`, `StoredPenNote`, `DataStore.removePenNotes(for:)`.

Hinweis Swift/SwiftData: Tests bauen den `DataStore` mit `makeStore()` (In-Memory, Teilplan 02) und die Dateien mit `InMemoryPenNoteFiles`; `PKDrawing` aus `PKStroke`s, Prüfwert `drawing.strokes.count`.

- [ ] **Step 1: Failing Tests schreiben**

```swift
@MainActor struct PenNoteStoreTests {
  @Test("AK-13: Notiz übersteht Schließen und erneutes Öffnen – in der Notiz-Datei")
  func savedNoteIsLoadedAgain() async throws {
    let (ctx, link) = try TestStore.contextWithLink(); let files = InMemoryPenNoteFiles()
    let notes = PenNoteStore(link: link, files: files, fallback: ctx)
    _ = await notes.loadAll()
    notes.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4); await notes.flush()
    let reopened = await PenNoteStore(link: link, files: files, fallback: ctx).loadAll()
    #expect(reopened[0]?.drawing.strokes.count == TestDrawings.word.strokes.count)
    #expect(reopened[0]?.savedSize == .a4)
    #expect(try ctx.penNotes(for: link).isEmpty)                         // nichts im Datenort
  }
  @Test("Review Focus 3: flush schreibt eine ausstehende Notiz sofort")
  func flushWritesPendingDrawingImmediately() async throws {
    let (ctx, link) = try TestStore.contextWithLink(); let files = InMemoryPenNoteFiles()
    let notes = PenNoteStore(link: link, files: files, fallback: ctx, saveDelay: .seconds(60)); _ = await notes.loadAll()
    notes.scheduleSave(TestDrawings.word, pageIndex: 1, pageSize: .a4)
    #expect(await files.writeCount == 0)
    await notes.flush()
    #expect(await files.writeCount == 1)
  }
  @Test("Review Focus 6: vor dem Schreiben wird neu gelesen – fremde Seite bleibt")
  func saveRereadsBeforeWriting() async throws {
    let (ctx, link) = try TestStore.contextWithLink(); let files = InMemoryPenNoteFiles()
    let notes = PenNoteStore(link: link, files: files, fallback: ctx); _ = await notes.loadAll()
    await files.put(TestFiles.note(TestKeys.tue8aEnglish, pages: [2]), for: link.reference)        // anderes Gerät schreibt Seite 2
    notes.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4); await notes.flush()
    #expect(await PenNoteStore(link: link, files: files, fallback: ctx).loadAll().keys.sorted() == [0, 2])
  }
  @Test("Review Focus 4: unlesbare Datei → nicht editierbar, nichts geschrieben")
  func unreadableFileIsNeverOverwritten() async throws {
    let (ctx, link) = try TestStore.contextWithLink(); let files = InMemoryPenNoteFiles(blocked: .notDownloaded)
    let notes = PenNoteStore(link: link, files: files, fallback: ctx); _ = await notes.loadAll()
    #expect(notes.location == .blocked(.notDownloaded) && !notes.isEditable)
    notes.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4); await notes.flush()
    #expect(await files.writeCount == 0)
  }
  @Test("Neueres Format: nur lesen")
  func newerFormatIsReadOnly() async throws   // InMemoryPenNoteFiles(blocked: .newerFormat) → location .blocked(.newerFormat), isEditable false
  @Test("Review Focus 5: Ordner nicht beschreibbar → Ersatz in PenNoteRecord, Hinweis über location")
  func notWritableFallsBackToAppData() async throws {
    let (ctx, link) = try TestStore.contextWithLink(); let files = InMemoryPenNoteFiles(notWritable: true)
    let notes = PenNoteStore(link: link, files: files, fallback: ctx); _ = await notes.loadAll()
    notes.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4); await notes.flush()
    #expect(notes.location == .appDataFallback)
    #expect(try ctx.penNotes(for: link).count == 1)
  }
  @Test("Review Focus 5: Ersatz wandert in die Notiz-Datei, sobald der Ordner beschreibbar ist")
  func fallbackNotesMoveIntoFileOnceWritable() async throws {
    let (ctx, link) = try TestStore.contextWithLink(); let files = InMemoryPenNoteFiles()
    TestStore.addFallbackNote(to: ctx, link: link, page: 0, drawing: TestDrawings.word, updatedAt: .now, size: .a4)
    let loaded = await PenNoteStore(link: link, files: files, fallback: ctx).loadAll()
    #expect(loaded[0] != nil)
    #expect(try ctx.penNotes(for: link).isEmpty)
    #expect(await files.writeCount == 1)
  }
  @Test("FR-6.1: dasselbe Material in einer anderen Stunde beginnt ohne Notizen")
  func otherLessonStartsEmpty() async throws {
    let (ctx, link8a) = try TestStore.contextWithLink(key: TestKeys.tue8aEnglish); let files = InMemoryPenNoteFiles()
    let link8b = TestStore.addLink(to: ctx, sameFileAs: link8a, key: TestKeys.wed8bEnglish)
    let a = PenNoteStore(link: link8a, files: files, fallback: ctx); _ = await a.loadAll()
    a.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4); await a.flush()
    #expect(await PenNoteStore(link: link8b, files: files, fallback: ctx).loadAll().isEmpty)
  }
  @Test("Unlesbare Zeichnungsdaten einer Seite werden übersprungen, die Datei bleibt")
  func corruptDrawingIsSkippedNotDeleted() async throws   // Seite mit drawing = Data([0, 1]) → loadAll()[0] == nil, writeCount == 0
  @Test("Doppelte Ersatz-Datensätze nach Abgleich: der jüngste gilt (Teilplan 02 führt zusammen)")
  func duplicateFallbackRecordsUseNewest() async throws   // notWritable; zwei PenNoteRecord derselben Seite → loadAll zeigt den jüngeren
}
```

- [ ] **Step 2: Diff durchsehen** (erwartet ohne Step 3: Kompilierfehler).
- [ ] **Step 3: Implementieren.**
  - Schlüssel: `LessonKey(storageText: link.lessonKeyText)`; ohne gültigen Schlüssel (Altdaten) → wie `.appDataFallback` (nur `PenNoteRecord`, Hinweis in der Anzeige).
  - `loadAll`: `files.read(link.reference, key:)`. `.notes(f, _)` → `location = .besideDocument`; `.none` → `.besideDocument` mit leerer Datei; `.blocked(r)` → `.blocked(r)` und Seiten aus dem lesbaren Teil gibt es nicht (leer, Hinweis). Danach Ersatz prüfen: `fallback.penNotes(for: link)` nicht leer und `location == .besideDocument` → Seiten, die in der Datei fehlen, übernehmen (jüngster Datensatz je Seite), einmal schreiben; Erfolg → `fallback.removePenNotes(for:)`; `.notWritable` → `location = .appDataFallback` und die Ersatz-Seiten anzeigen. `PKDrawing(data:)` in `do/catch` – Fehler lässt die Seite aus, ändert nichts. `savedSize` = `nil`, wenn Breite oder Höhe 0.
  - `scheduleSave`: Zeichnung je Seite im Speicher, Seite in `changedPages`, `hasChangesThisSession = true`; Verzögerungs-`Task` neu starten (`try await Task.sleep(for: saveDelay)`, dann `await flush()`). Swift-Hinweis: `Task {}` erbt hier den `@MainActor`.
  - `flush`: nichts ausstehend oder `!isEditable` → Ende. `.besideDocument`: `PenNoteFile` aus dem zuletzt gelesenen Stand plus `updating(pageIndex:…)` je ausstehender Seite → `files.write(_, changedPages:, …)`; Ergebnis wird neuer Stand, ausstehende Seiten geleert. `.notWritable` → `location = .appDataFallback` und dieselben Seiten über `fallback.savePenNote(...)`; `.blocked(r)` → `location = .blocked(r)`, Zeichnung bleibt im Speicher (nicht verworfen), Protokoll; `.failed` → Zeichnung bleibt ausstehend, nächster Versuch beim nächsten `flush`. `.appDataFallback`: nur `savePenNote` (Teilplan 02 setzt die Seitengröße nur beim ersten Mal).
  - Keine Zeile löscht einen `PenNoteRecord` außer dem erfolgreichen Umzug in die Datei.
- [ ] **Step 4: Diff durchsehen** – Schreiben in die Ablage nur über `PenNoteFileAccessing`, in den Datenort nur über `DataStore`.
- [ ] **Step 5: Commit** – `git commit -m "feat(viewer): pen note store beside the document with app data fallback"`

---

### Task 7: Material laden und Zustand der Anzeige (`MaterialDocumentLoader`, `ViewerModel`)

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Viewer/MaterialDocumentLoader.swift`, `Frontstage/Viewer/ViewerModel.swift`
- Test: `FrontstageTests/Viewer/ViewerModelTests.swift`

**Interfaces:**
- Consumes: `MaterialFileReading` (Interfaces-Block), `MaterialFileKind`, `MaterialReference` (02); `PenNoteStore`, `DrawingGeometry`, `PenNoteFileAccessing` (Task 5, 6); `PenNoteFit` (Task 2); `SecondScreenState.openMaterial/closeMaterial/showPage/updateDrawing/setBoardLesson` (Task 4); `PenNotePDFWriter` (Task 8 – bis dahin ruft `close()` ihn über eine Funktion, die Task 8 füllt; Task 8 direkt nach Task 7 umsetzen).
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
  @Test("Review Focus 7: unlesbare Daten – Anzeige meldet nicht verfügbar, Notizen unberührt")
  func unreadableDataFailsWithoutTouchingNotes() async throws {
    let (model, files, _) = try await TestViewer.make(kind: .pdf, data: Data("kein PDF".utf8), notePages: [0])
    await model.load()
    #expect(model.phase == .unavailable)
    #expect(await files.writeCount == 0)
  }
  @Test("Verweis löst nicht auf → nicht verfügbar, Zweitbildschirm bleibt beim Klassenbildschirm")
  func loadFailureSetsUnavailable() async throws {
    let (model, _, screen) = try await TestViewer.make(kind: .pdf, readError: StubError.unresolvable)
    await model.load()
    #expect(model.phase == .unavailable)
    #expect(screen.state.mode == .classScreen)
  }
  @Test("AK-23: Öffnen zeigt Seite 1 mit vorhandenen Notizen auf dem Zweitbildschirm")
  func openingPresentsMaterialWithNotes() async throws {
    let (model, _, screen) = try await TestViewer.make(kind: .pdf, data: TestDocuments.pdfData(pages: 2, size: .a4), notePages: [0])
    await model.load()
    #expect(model.phase == .ready && screen.state.mode == .material)
    #expect(screen.material?.pageIndex == 0)
    #expect(screen.material?.drawings[0]?.strokes.count == TestDrawings.word.strokes.count)
  }
  @Test("ADR-0011: geänderte Seitengröße und fehlende Seite werden gemeldet, nicht verworfen")
  func reportsOutdatedAndMissingPages() async throws {
    let (model, files, _) = try await TestViewer.make(kind: .pdf, data: TestDocuments.pdfData(pages: 2, size: .a4),
      notes: [0: PageSize(width: 842, height: 595), 4: .a4])
    await model.load()
    #expect(model.outdatedPages == [0] && model.missingPages == [4])
    #expect(await files.writeCount == 0)
  }
  @Test("AK-13, AK-23: Schließen speichert sofort, schreibt das Notiz-PDF und gibt den Zweitbildschirm frei")
  func closeFlushesWritesPDFAndReturnsToClassScreen() async throws {
    let (model, files, screen) = try await TestViewer.make(kind: .pdf, data: TestDocuments.pdfData(pages: 1, size: .a4), saveDelay: .seconds(60))
    await model.load()
    model.drawingChanged(TestDrawings.word, pageIndex: 0)
    await model.close()
    #expect(await files.writeCount == 1)          // `await` rechts von `&&` kompiliert nicht – je Wert ein #expect
    #expect(await files.pdfWriteCount == 1)
    #expect(screen.state.mode == .classScreen && screen.material == nil)
  }
  @Test("Nur ansehen (z. B. am Mac): kein Notiz-PDF beim Schließen (Entscheidung 5)")
  func viewingOnlyWritesNoPDF() async throws {
    let (model, files, _) = try await TestViewer.make(kind: .pdf, data: TestDocuments.pdfData(pages: 1, size: .a4), notePages: [0], existingPDF: true)
    await model.load(); await model.close()
    #expect(await files.pdfWriteCount == 0)
  }
  @Test("Ersatz im Datenort: kein Notiz-PDF, Hinweis über notesLocation")
  func fallbackWritesNoPDF() async throws {
    let (model, files, _) = try await TestViewer.make(kind: .pdf, data: TestDocuments.pdfData(pages: 1, size: .a4), notWritable: true)
    await model.load(); model.drawingChanged(TestDrawings.word, pageIndex: 0); await model.close()
    #expect(model.notesLocation == .appDataFallback)
    #expect(await files.pdfWriteCount == 0)
  }
}
```

`TestViewer.make(kind:data: = Data(), readError: (any Error)? = nil, notePages: [Int] = [], notes: [Int: PageSize] = [:], existingPDF: Bool = false, notWritable: Bool = false, saveDelay: Duration = .milliseconds(500)) async throws -> (ViewerModel, InMemoryPenNoteFiles, SecondScreenState)` (in `ViewerTestSupport.swift` ergänzen) baut `DataStore` + Zuordnung, `InMemoryPenNoteFiles` (Notizseiten mit `TestDrawings.word`), `StubReader`, `SecondScreenState()` und das `ViewerModel`; `StubReader`/`StubError` (`unresolvable`) ebenda.

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: `MaterialDocumentLoader` implementieren.** `.pdf`: `PDFDocument(data:)`, `nil` oder `pageCount == 0` → `.unreadable`. `.image`: iOS `UIImage(data:)`, macOS `NSImage(data:)`; vor `PDFPage(image:)` die Bildausrichtung einmal in ein aufrecht gezeichnetes Bild überführen (iOS: `UIGraphicsImageRenderer`, weil `PDFPage(image:)` die EXIF-Ausrichtung sonst nicht sicher übernimmt – am Gerät mit einem Hochkant-Foto prüfen); dann ein neues `PDFDocument()` mit `insert(_:at: 0)`. Andere Arten → `.unsupportedKind`. Nicht an den `@MainActor` gebunden (läuft auch im Notiz-PDF außerhalb des Hauptthreads).
- [ ] **Step 4: `ViewerModel` implementieren.**
  - `load()`: `await beforeLoad()` (Warteliste nachholen, Task 9) → Datei über `fileReader.readData(for:)` → `makeDocument` → `await notes.loadAll()` → `fitByPage` je Notizseite über `PenNoteFit.evaluate` (aktuelle Größe aus `DrawingGeometry.pageSize(of:)`) → `secondScreen.openMaterial(MaterialPresentation(linkID:documentData:kind:pageIndex: 0, visibleRect: nil, drawings:))` und `secondScreen.setBoardLesson(LessonKey(storageText: link.lessonKeyText))` (AK-29: Tafel der Unterrichtsstunde wählbar). Fehler beim Lesen oder Laden → `phase = .unavailable`, kein Aufruf am Zweitbildschirm, Notizen werden nicht gelesen.
  - `drawingChanged`: nur bei `canDraw`; `notes.scheduleSave(…, pageSize: aktuelle Seitengröße)` und `secondScreen.updateDrawing(…)`.
  - `pageChanged`: `await notes.flush()`, `pageIndex` setzen, `secondScreen.showPage(…)`.
  - `flushNow()`: `await notes.flush()`.
  - `close()`: `await notes.flush()`; wenn `notes.location == .besideDocument` und (`notes.hasChangesThisSession` oder Notiz-PDF fehlt, obwohl Striche existieren – `files.existingNotesPaths`): `PenNotePDFWriter.makePDF(document:notes: notes.currentNotes())` → Daten → `files.writePDF`, `nil` → `files.removePDF` (Entscheidung 5); Fehler nur protokollieren (die Notiz-Datei ist maßgeblich). Danach `secondScreen.closeMaterial()`, `secondScreen.setBoardLesson(nil)`.
- [ ] **Step 5: Diff durchsehen.**
- [ ] **Step 6: Commit** – `git commit -m "feat(viewer): load pdf and image, viewer model with notes beside the document"`

---

### Task 8: Notiz-PDF mit Ink-Anmerkungen (`PenNotePDFWriter`)

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Viewer/PenNotes/PenNotePDFWriter.swift`
- Test: `FrontstageTests/Viewer/PenNotePDFWriterTests.swift`

**Interfaces:**
- Consumes: `DrawingGeometry.pdfTransform(for:)` (Task 5), `StoredPenNote` (Task 6), `MaterialDocumentLoader` (Task 7).
- Produces: `PenNotePDFWriter.makePDF(document:notes:) -> Data?`.

- [ ] **Step 1: Failing Tests schreiben**

```swift
@Suite struct PenNotePDFWriterTests {
  @Test("ADR-0011: Seiten des Originals plus Striche als Ink-Anmerkungen")
  func writesInkAnnotations() throws {
    let doc = try MaterialDocumentLoader.makeDocument(from: TestDocuments.pdfData(pages: 2, size: .a4), kind: .pdf)
    let data = try #require(PenNotePDFWriter.makePDF(document: doc, notes: [1: StoredPenNote(drawing: TestDrawings.word, savedSize: .a4)]))
    let out = try #require(PDFDocument(data: data))
    #expect(out.pageCount == 2)
    #expect(out.page(at: 0)?.annotations.isEmpty == true)
    let ink = try #require(out.page(at: 1)?.annotations.filter { $0.type == "Ink" })
    #expect(ink.count == TestDrawings.word.strokes.count)
  }
  @Test("Striche liegen innerhalb der Seite (Koordinaten umgerechnet)")
  func annotationsInsidePage() throws   // jede annotation.bounds ⊆ page.bounds(for: .mediaBox)
  @Test("Bild als PDF-Seite mit Anmerkungen")
  func imageBecomesAnnotatedPage() throws   // MaterialDocumentLoader(.image) → makePDF → pageCount == 1, eine Ink-Anmerkung
  @Test("Ohne Striche kein PDF (Entscheidung 5)")
  func noStrokesNoPDF() throws   // notes leer oder nur leere Zeichnungen → nil
  @Test("Das übergebene Dokument bleibt unverändert")
  func sourceDocumentUntouched() throws   // doc.page(at: 1)?.annotations.isEmpty == true nach makePDF
}
```

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: Implementieren.** Kopie des Dokuments über `PDFDocument(data: document.dataRepresentation()!)` (das Original-Objekt nie verändern); je Seite mit Notiz und je `PKStroke`: Punkte über `stroke.path.interpolatedPoints(by: .distance(2))`, jeweils `point.location.applying(stroke.transform)`, dann `DrawingGeometry.pdfTransform(for: page)`; ein Linienzug als `UIBezierPath` (iOS) bzw. `NSBezierPath` (macOS) – Plattformweiche mit `#if os(iOS)`, Rest gemeinsam. `PDFAnnotation(bounds: page.bounds(for: .mediaBox), forType: .ink, withProperties: nil)`; Pfad in Anmerkungskoordinaten (= Seitenkoordinaten minus `bounds.origin`) mit `add(_:)`; `color = stroke.ink.color`; `border = PDFBorder()` mit `lineWidth` = mittlere `point.size.width` (mindestens 1). Seiten, die es im Dokument nicht mehr gibt (`pageMissing`), werden **nicht** ins PDF geschrieben – sie bleiben in der Notiz-Datei (Hinweis in der Anzeige). Ergebnis `dataRepresentation()`; keine Striche → `nil`. Quelle: Context7 `/websites/developer_apple_pdfkit` (`PDFAnnotation.add(_:)`: „annotation-space coordinates“).
- [ ] **Step 4: Diff durchsehen** – läuft auch am Mac (Neuerzeugen nach Zusammenführen, Task 9); kein Zugriff auf UIKit-Ansichten.
- [ ] **Step 5: Commit** – `git commit -m "feat(viewer): readable notes pdf with ink annotations"`

---

### Task 9: Notizen mitnehmen – Schieben, Weiterreichen, Neu verknüpfen (`PenNoteFileService`)

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Viewer/PenNotes/PenNoteFileService.swift`, `Frontstage/Viewer/PenNotes/PendingPenNoteMoves.swift`
- Test: `FrontstageTests/Viewer/PenNoteFileServiceTests.swift`

**Interfaces:**
- Consumes: `PenNoteFileRelocating`, `PenNoteMove` (Teilplan 04, Task 3/4); `PenNoteRelocation` (Task 3); `PenNoteFileAccessing` (Task 5); `PenNotePDFWriter` (Task 8).
- Produces: `PenNoteFileService`, `PendingPenNoteMoves`.

- [ ] **Step 1: Failing Tests schreiben**

```swift
@MainActor struct PenNoteFileServiceTests {
  @Test("AK-22: Schieben benennt Notiz-Datei und Notiz-PDF auf die nächste Stunde um")
  func moveRenamesNotes() async throws {
    let files = InMemoryPenNoteFiles(); let ref = TestFiles.reference("Arbeitsblatt Vokabeln.pdf")
    await files.put(TestFiles.note(TestKeys.tue8aEnglish, pages: [0]), for: ref, withPDF: true)
    let service = PenNoteFileService(files: files, pending: .inTemporaryDirectory(), makePDF: { _, _ in })
    service.linksMoved([PenNoteMove(reference: ref, from: TestKeys.tue8aEnglish, to: TestKeys.thu8aEnglish)])
    await service.retryPending()
    #expect(await files.lessonKeys(for: ref) == [TestKeys.thu8aEnglish])
    #expect(await files.pdfNames(for: ref) == ["Arbeitsblatt Vokabeln – Notizen 8a 2026-11-19.pdf"])
  }
  @Test("Review Focus 8: gescheitertes Umbenennen bleibt in der Warteliste und wird nachgeholt")
  func failedMoveStaysPendingAndRetries() async throws {
    let files = InMemoryPenNoteFiles(unreachable: true); let pending = PendingPenNoteMoves.inTemporaryDirectory()
    let service = PenNoteFileService(files: files, pending: pending, makePDF: { _, _ in })
    service.linksMoved([PenNoteMove(reference: TestFiles.reference("Arbeitsblatt Vokabeln.pdf"), from: TestKeys.tue8aEnglish, to: TestKeys.thu8aEnglish)])
    await service.retryPending()
    #expect(pending.load().count == 1)
    await files.setUnreachable(false); await service.retryPending()
    #expect(pending.load().isEmpty)
  }
  @Test("Review Focus 8: zwei Schiebungen hintereinander laufen in Reihenfolge")
  func chainedMovesRunInOrder() async throws   // Di → Do, dann Do → Di nächste Woche; am Ende eine Datei unter dem letzten Schlüssel
  @Test("Ziel mit Notizen: zusammenführen und Ziel-PDF neu erzeugen (Entscheidung 8)")
  func moveIntoNotesMergesAndRegenerates() async throws   // makePDF-Attrappe zählt einen Aufruf für (ref, thu8a)
  @Test("Übernehmen legt nichts an (FR-6.1, AK-22)")
  func copyCreatesNothing() async throws   // kein linksMoved-Aufruf beim Übernehmen (Teilplan 04) → files unverändert; hier: linksMoved([]) ändert nichts
  @Test("Neu verknüpfen: Notizen am alten Ort werden gezählt und neben die neue Datei verschoben (ADR-0011)")
  func relinkMovesNotesToNewFile() async throws {
    let files = InMemoryPenNoteFiles(); let old = TestFiles.reference("Arbeitsblatt Vokabeln.pdf"); let new = TestFiles.reference("Ordner neu/Vokabeln neu.pdf")
    await files.put(TestFiles.note(TestKeys.tue8aEnglish, pages: [0]), for: old, withPDF: true)
    let service = PenNoteFileService(files: files, pending: .inTemporaryDirectory(), makePDF: { _, _ in })
    #expect(await service.notesCount(beside: old) == 1)
    try await service.moveNotes(from: old, to: new)
    #expect(await files.lessonKeys(for: new) == [TestKeys.tue8aEnglish])
    #expect(await files.documentName(for: new, key: TestKeys.tue8aEnglish) == "Vokabeln neu.pdf")
    #expect(await files.lessonKeys(for: old).isEmpty)
  }
  @Test("Alter Ort nicht erreichbar: nichts anzubieten")
  func unreachableOldLocationOffersNothing() async throws   // existingNotesPaths == nil → notesCount == 0
}
```

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: Implementieren.**
  - `PendingPenNoteMoves`: JSON-Datei `Application Support/PenNotes/pending-moves.json` (`isExcludedFromBackup = true`, nur dieses Gerät, nicht abgeglichen); Eintrag = `folderGrantName`, `relativePath`, `displayName`, `fileKindRaw`, `fromKeyText`, `toKeyText` (keine Inhalte). `inTemporaryDirectory()` nur im Testziel.
  - `linksMoved`: Einträge **zuerst** anhängen und speichern (synchron), dann `Task { await retryPending() }`.
  - `retryPending`: Einträge in Reihenfolge; je Eintrag `files.existingNotesPaths(ref)` → `nil` (Ort nicht erreichbar) → abbrechen, Rest bleibt; sonst `PenNoteRelocation.planMove(...)` aus den vorhandenen Pfaden (ein halb ausgeführter früherer Versuch ergibt so nur noch den Rest) → `files.apply(plan, from: ref, to: ref)`; Erfolg → Eintrag entfernen und für `plan.regeneratePDFFor` `await makePDF(ref, key)`; `.blocked`/`.failed` → abbrechen, Rest bleibt (nächstes Aktivwerden); `.notWritable` → Eintrag entfernen (die Notizen dieser Zuordnung liegen dann ohnehin im Ersatz, der mit der Zuordnung wandert). Nie zwei Läufe gleichzeitig: den laufenden Durchgang als `Task` merken; ein zweiter Aufruf wartet auf dessen Ende (`await running.value`) und startet danach selbst einen Durchgang, statt sofort zurückzukehren – sonst endet `await service.retryPending()` in den Tests nach `linksMoved` (das schon einen Durchgang angestoßen hat), bevor umbenannt ist.
  - `notesCount(beside:)`: `existingNotesPaths(old)` → Zahl der Stunden-Dateien (`lessonKey(fromLessonFileName:) != nil`).
  - `moveNotes(from:to:)`: `planRelink(...)` aus beiden Pfadlisten → `files.apply(plan, from: old, to: new)` → `regeneratePDFFor` neu erzeugen. Fehler werden geworfen (Teilplan 04 zeigt einen Hinweis).
  - `makePDF` (in `ScopedServicesHolder.services(for:)` gesetzt, Task 10): Dokument über `ScopedFileReader` lesen, `MaterialDocumentLoader`, Notizen über `files.read`, `PenNotePDFWriter.makePDF`, `files.writePDF`.
- [ ] **Step 4: Diff durchsehen** – Warteliste vor jeder Dateioperation gespeichert; keine Inhalte in der Warteliste.
- [ ] **Step 5: Commit** – `git commit -m "feat(viewer): carry pen notes along on move and relink"`

---

### Task 10: Anzeige am iPad und am Mac (`ViewerView`) und Einbindung

Design-Takt: voll

**Files:**
- Create: `Frontstage/Viewer/PDFCanvasView.swift`, `Frontstage/Viewer/PDFDisplayView.swift`, `Frontstage/Viewer/ViewerView.swift`, `Frontstage/Viewer/ScopedFileReader.swift`, `Frontstage/Viewer/PenCanvas.swift`
- Modify: `Frontstage/UI/DayView/DayView.swift` (Teilplan 04) – `MaterialOpenAction.viewer(item)` öffnet `ViewerView(linkID: item.id)` als `.fullScreenCover` (iOS) bzw. `.sheet` (macOS)
- Modify: `Frontstage/App/ScopedAppContent.swift` (Teilplan 04; vorher ganz lesen, nichts entfernen) – in `ScopedServicesHolder.services(for:)`, Zweig „neuer Store“, nach dem Anlegen von `environment`: `environment.viewerAvailable = true`; `environment.penNotes = PenNoteFileService(files: StoragePenNoteFiles(storage: storage), makePDF: …)`. **Nicht** in `ScopedAppContent` selbst: der Rahmen entsteht einmal je Tab und je Ziel.
- Modify: `Frontstage/App/RootView.swift` (Teilplan 04) – in `activate(_:)` zusätzlich `Task { await current.environment.penNotes.retryPending() }` (läuft bei `.active` und nach jedem Wechsel des Datenorts)
- Modify: `Frontstage/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `ViewerModel` (Task 7), `PenNoteStore` (Task 6), `StoragePenNoteFiles` (Task 5), `PenNoteFileService` (Task 9), `SecondScreenState` aus der Umgebung (Task 4), `SmartboardBar` (Task 12 – bis dahin `EmptyView()`), `ScopedFileReader(storage:)` mit dem `StorageService` aus der Umgebung (Teilplan 03, `readableFile(for:)`); `DataStore.link(id:)` (02); `AppEnvironment` (04). Alle drei kommen innerhalb von `DataScopedRoot` in die Umgebung (Teilplan 04/08) – die Anzeige erzeugt keinen eigenen `DataStore` oder `StorageService`.
- Produces: `ViewerView(linkID: UUID)`, `PDFDisplayView(documentData: Data, pageIndex: Int, drawing: PKDrawing?, visibleRect: CGRect?)`, `PenCanvas`, `ScopedFileReader`.

- [ ] **Step 1: Skill `apple-design` laden** (projektlokal; Hauptstufe vor dem Editieren).

- [ ] **Step 2: `PDFCanvasView` (nur `#if os(iOS)`) als `UIViewRepresentable`.** Swift-Hinweis: `UIViewRepresentable` bettet eine UIKit-Ansicht in SwiftUI ein; der `Coordinator` ist das Objekt, das UIKit-Delegates entgegennimmt.
  - `PDFView`: `displayMode = .singlePage`, `autoScales = true`, `usePageViewController(true)`, `isInMarkupMode = true` (iOS 16; überlässt Stifteingaben der Überlagerung), `pageOverlayViewProvider = coordinator`.
  - `pdfView(_:overlayViewFor:)`: je Seite eine `PKCanvasView` (`backgroundColor = .clear`, `isOpaque = false`, `drawingPolicy = .default` – folgt der Systemeinstellung „Nur Apple Pencil“, `isUserInteractionEnabled = model.canDraw`), Zeichnung aus `ViewerModel` per `DrawingGeometry.toViewSpace` setzen; Canvas je Seitenindex im Coordinator merken.
  - `canvasViewDrawingDidChange(_:)` → `model.drawingChanged(DrawingGeometry.toPageSpace(…), pageIndex:)`. Beim Setzen der Zeichnung aus dem Speicher ein Flag setzen, damit dieser Rückruf nicht erneut speichert.
  - `pdfView(_:willEndDisplayingOverlayView:for:)` → `Task { await model.pageChanged(…) }` (löst `flush` aus).
  - Seitenwechsel über `NotificationCenter` `.PDFViewPageChanged` → `model.pageChanged(to:visibleRect:)`; `visibleRect` = sichtbarer Ausschnitt in Seitenkoordinaten (`pdfView.convert(pdfView.bounds, to: page)`), `nil`, wenn die ganze Seite sichtbar ist.
  - Werkzeuge: `PKToolPicker()`; `addObserver(canvas)`, `setVisible(model.canDraw, forFirstResponder: canvas)` für die Canvas der aktuellen Seite, `canvas.becomeFirstResponder()` – System-Werkzeugpalette mit Stift, Radierer, Farben, Rückgängig.

- [ ] **Step 3: `PDFDisplayView` (iOS und macOS) – nur anzeigen.** Eigenes `PDFDocument(data:)` je Instanz (ein Dokument nicht zwischen mehreren `PDFView`s teilen), im Coordinator nach `documentData` zwischengespeichert; `isUserInteractionEnabled = false` (iOS); Seite per `go(to:)`, Ausschnitt per `go(to:on:)`, wenn `visibleRect` gesetzt. Überlagerung: iOS eine nicht bedienbare `PKCanvasView` (`isUserInteractionEnabled = false`), macOS ein `NSImageView` mit `drawing.image(from:scale:)` (PencilKit hat am Mac keine Zeichenfläche, `PKDrawing` gibt es dort – Quelle oben). Zeichnung jeweils mit `toViewSpace` auf die Größe der Überlagerung.

- [ ] **Step 4: `ViewerView`.** Holt den `MaterialLinkRecord` über `DataStore.link(id:)` (`DataStore`, `StorageService` und `AppEnvironment` aus der Umgebung), baut `PenNoteStore(link:files: StoragePenNoteFiles(storage:), fallback: dataStore)` und `ViewerModel(…, beforeLoad: { await environment.penNotes.retryPending() })`, ruft `.task { await model.load() }`. `ScopedFileReader.readData`: `storage.readableFile(for:)` → `nil` wirft; sonst koordiniert lesen (`NSFileCoordinator`, `.withoutChanges`) außerhalb des Hauptthreads, danach in jedem Fall `close()`. Genau das tut seit Teilplan 03 schon `StorageService.withFileURL(for:_:)` (öffnet über `resolver.open` = `readableFile`, prüft die Verfügbarkeit, liest koordiniert in `Task.detached`, schließt per `defer`) – also `try await storage.withFileURL(for: reference) { try Data(contentsOf: $0) }`, keine zweite Koordination.
  - Inhalt: iOS `PDFCanvasView`, macOS `PDFDisplayView` + Seiten-Knöpfe; `.loading` → `ProgressView`, `.unavailable` → `ContentUnavailableView` (Systemstandard) mit Text `viewer.unavailable`.
  - Navigationsleiste: Titel = `displayName` des Materials, Zurück/„Fertig“ → `Task { await model.close(); dismiss() }` (Knopf bis dahin deaktiviert, damit nicht doppelt geschlossen wird); Seitenanzeige `viewer.pageOfPages` („Seite %lld von %lld“), vorige/nächste Seite.
  - Hinweis bei `outdatedPages` nicht leer: Banner `viewer.outdatedNotes.title` / `.body` mit Seitenzahlen, Knopf `viewer.outdatedNotes.hide` (blendet für diese Sitzung aus; Notizen bleiben). Bei `missingPages` nicht leer: Banner `viewer.missingPages` mit Knopf `viewer.missingPages.show`, der die Notizen dieser Seiten als Bild (`PKDrawing.image(from: bounds, scale:)`) in einem Blatt zeigt.
  - Hinweis zum Ort der Notizen (ADR-0011): `notesLocation == .appDataFallback` → Banner `viewer.notesInAppData`; `.blocked(.notDownloaded)` → `viewer.notesNotDownloaded`; `.blocked(.unreadable)` → `viewer.notesUnreadable`; `.blocked(.newerFormat)` → `viewer.notesNewerFormat`. Bei `.blocked` ist Schreiben aus (`canDraw == false`), Anzeigen geht.
  - `@Environment(\.scenePhase)`: beim Wechsel auf `.background` → `Task { await model.flushNow() }`, unter iOS eingebettet in `UIApplication.shared.beginBackgroundTask(withName:)`/`endBackgroundTask(_:)`, damit das Schreiben in die Ablage vor dem Anhalten fertig wird.
  - Unten: `SmartboardBar()` nur `#if os(iOS)`.
  - Offene Kategorien (Systemstandard nehmen, im Abschlussbericht nennen): Wortlaut aller Texte, Darstellung der Hinweis-Banner, Seitenübersicht (Mockup zeigt eine; hier **nicht** gebaut – Abschlussbericht).

- [ ] **Step 5: Einbindung** – `DayView`: `MaterialOpenAction.viewer(item)` (Teilplan 04, gilt für `fileKind.opensInViewer`) öffnet `ViewerView(linkID: item.id)`; ebenso `OpenOutcome.showInViewer(file)` aus `StorageService.open` (dann `file.close()` und `ViewerView` liest selbst; die Zuordnungs-ID kommt über das vorhandene `currentRow(for: reference)?.id` in `DayView.handle(_:_:)` – der Fall trägt nur den Verweis). Der Zweig `.viewer(let item)` in `DayView.open(_:anchor:)` ruft heute noch `start(…)` (Platzhalter aus 04) und wird ersetzt. `ScopedServicesHolder.services(for:)`: `viewerAvailable = true`, `penNotes = PenNoteFileService(...)` mit `makePDF` gemäß Task 9 (nutzt dieselben `StorageService`-gebundenen Bausteine); `retryPending()` in `RootView.activate(_:)`. Nach einem Wechsel des Datenorts entsteht der Dienst mit dem neuen Dienste-Satz neu – die Warteliste liegt in einer Datei und geht dabei nicht verloren.

- [ ] **Step 6: Texte** in `Localizable.xcstrings` (Schlüssel englisch, Werte deutsch, Platzhalter-Wortlaut aus dem Mockup): `viewer.unavailable` = „Material nicht verfügbar“, `viewer.pageOfPages` = „Seite %1$lld von %2$lld“, `viewer.outdatedNotes.title` = „Notizen zu einer früheren Fassung“, `viewer.outdatedNotes.body` = „Die Datei wurde in der Ablage geändert. Die Notizen dieser Stunde bleiben erhalten, liegen aber womöglich nicht mehr an der richtigen Stelle.“, `viewer.outdatedNotes.hide` = „Ausblenden“, `viewer.missingPages` = „Notizen zu Seiten, die es nicht mehr gibt“, `viewer.missingPages.show` = „Notizen ansehen“, `viewer.done` = „Fertig“, `viewer.notesInAppData` = „Der Ordner dieses Materials ist nicht beschreibbar. Die Notizen dieser Stunde liegen deshalb in Frontstage statt neben dem Dokument.“, `viewer.notesNotDownloaded` = „Die Notizen dieser Stunde sind noch nicht geladen. Schreiben ist möglich, sobald sie da sind.“, `viewer.notesUnreadable` = „Die Notiz-Datei dieser Stunde ist nicht lesbar. Sie bleibt unverändert; Schreiben ist ausgeschaltet.“, `viewer.notesNewerFormat` = „Die Notizen stammen aus einer neueren Frontstage-Version. Zum Weiterschreiben die App aktualisieren.“

- [ ] **Step 7: Diff durchsehen** – alle `PKCanvasView`/`PKToolPicker`/`UIView*` unter `#if os(iOS)`; macOS-Zweig ohne Zeichenfläche; kein Schreibzugriff auf das Original; Schreiben nur über `PenNoteStore`/`PenNoteFileService`.

- [ ] **Step 8: Prüfung mit `apple-design` als Prüfer** (Design-Takt voll) auf `ViewerView`; Befunde, die eine offene Kategorie entscheiden würden, nicht umsetzen, sondern im Abschlussbericht als Vorschlag für eine Design-Runde nennen.

- [ ] **Step 9: Commit** – `git commit -m "feat(viewer): pdf and image viewer with notes beside the document, read-only on mac"`

---

### Task 11: Szene des Zweitbildschirms – iOS 26 und iOS 27

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/SecondScreen/SecondScreenRootView.swift`, `Frontstage/SecondScreen/SecondScreenEnvironment.swift`, `Frontstage/SecondScreen/ExternalDisplaySceneDelegate.swift`, `Frontstage/SecondScreen/SceneAccessoryRegistrar.swift`, `Frontstage/App/AppDelegate.swift`
- Create (Einhängepunkte, Besitzer Teilplan 07): `Frontstage/ClassScreen/ClassScreenView.swift`, `Frontstage/ClassScreen/ClassScreenOverlay.swift`, `Frontstage/ClassScreen/ClassroomEnvironment.swift`, `Frontstage/Board/BoardView.swift`
- Modify: `Frontstage/App/FrontstageApp.swift` (Inhalt aus 04 und 08; vorher ganz lesen, nichts entfernen), `Frontstage/App/RootView.swift` (nur der Kommentar zum Szenen-Zubehör, Step 8)

**Interfaces:**
- Consumes: `SecondScreenState` (Task 4), `PDFDisplayView` (Task 10), `DataScopedRoot` (08).
- Produces: `SecondScreenRootView(state:)`, `secondScreenEnvironment()`, `registersSecondScreenAccessory()`, Platzhalter für Teilplan 07.

Hintergrund: Eine „Szene“ ist in UIKit eine eigene Instanz der Oberfläche mit eigenem Fenster. SwiftUI hat für die nicht bedienbare Szene des Zweitbildschirms keinen eigenen Baustein; sie wird in UIKit angelegt und zeigt die SwiftUI-Ansicht über `UIHostingController`. Die neue Szene hat **eine eigene SwiftUI-Umgebung** – deshalb `secondScreenEnvironment()` als einzige Stelle, an der beide Szenen ihre Umgebung bekommen.

- [ ] **Step 1: Skill `apple-design` laden.**

- [ ] **Step 2: `SecondScreenRootView(state:)`** – `switch state.content`: `.classScreen` → `ClassScreenView()`, `.material` → `PDFDisplayView(documentData:pageIndex:drawing: material.drawings[pageIndex], visibleRect:)` vollflächig, `.board` → `BoardView()`, `.dark` → `Color.black` (FR-11.4, kostenlos). Über allen Inhalten außer `.dark`: `ClassScreenOverlay()`. Keine Knöpfe, keine Gesten, `.allowsHitTesting(false)`, `.ignoresSafeArea()`. Ist `.material` gewählt, aber `material == nil`, zeigt sie den Klassenbildschirm (nie leer).

- [ ] **Step 3: Einhängepunkte für Teilplan 07** (Übersicht, Abstimmung Punkt 8) – `ClassScreenView()`: neutrale Fläche (Systemhintergrund) mit Kommentar `// Einhängepunkt – Teilplan 07 ersetzt den Inhalt; Name und init bleiben.`; `BoardView()`: neutrale Fläche, gleicher Kommentar; `ClassScreenOverlay()`: `EmptyView()`, Kommentar „Timer-Schicht (FR-11.2), Teilplan 07“; `classroomEnvironment()`: gibt `self` zurück, Kommentar „Teilplan 07 hängt hier seine Modelle an“. Der Platzhalter-Klassenbildschirm zeigt **nichts** außer der Fläche (FR-11; entspricht zugleich dem Ruhezustand ohne Kauf, FR-13).

- [ ] **Step 4: `secondScreenEnvironment()`** in `SecondScreenEnvironment.swift`: `.environment(SecondScreenState.shared).classroomEnvironment()`; `///`-Doku: „Eine Stelle für die Umgebung beider Szenen; Modelle von Teilplan 07 kommen über classroomEnvironment().“

- [ ] **Step 5: `ExternalDisplaySceneDelegate` (nur `#if os(iOS)`)** – `final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate`, `var window: UIWindow?`.
  - `scene(_:willConnectTo:options:)`: `guard let windowScene = scene as? UIWindowScene, session.role == .windowExternalDisplayNonInteractive`; `UIWindow(windowScene:)`, `rootViewController = UIHostingController(rootView: SecondScreenRootView(state: .shared).secondScreenEnvironment())`, `makeKeyAndVisible()`; `SecondScreenState.shared.displayConnected(aspectRatio: windowScene.screen.bounds.width / windowScene.screen.bounds.height)`.
  - `sceneDidDisconnect(_:)`: `window = nil`, `SecondScreenState.shared.displayDisconnected()`.
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

`registration` als `AnyObject?` speichern (der Typ `UISceneAccessoryRegistration` existiert erst ab 27). **SDK-Stand:** Die CI baut heute mit Xcode 26.6 (iOS-SDK 26.5, Swift 6.3.3; Lauf 43567142097). Dort gibt es `UISceneAccessory`, `registerSceneAccessory` und `.externalNonInteractive` nicht – `#available` schützt nur zur Laufzeit, der Compiler meldet trotzdem „cannot find …“. Den iOS-27-Block deshalb zusätzlich in `#if compiler(>=6.4)` (Swift-Stand von Xcode 27) einschließen; vor dem Lauf in der CI-Ausgabe `xcodebuild -version` prüfen. Mit Xcode 26 gebaut fehlt der iOS-27-Weg (siehe Abstimmungsbedarf, Werkzeugstand). `registersSecondScreenAccessory()` = `.background(SceneAccessoryRegistrar().frame(width: 0, height: 0))`. Quelle: Apple, Abschnitt „Register a scene accessory for noninteractive content“ (Code dort mit `UISceneConfiguration()` + `delegateClass`; `init(name:sessionRole:)` ist gleichwertig und setzt die Rolle ausdrücklich).

- [ ] **Step 8: `FrontstageApp` anpassen** – unter `#if os(iOS)`: `@UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate` (Swift-Hinweis: verbindet einen UIKit-App-Delegate mit dem SwiftUI-Lebenszyklus); der `RootView` im `WindowGroup` erhält `.registersSecondScreenAccessory()` (seit Teilplan 04 steht dort `RootView`, `DataScopedRoot` liegt darin je Bereich). Für beide Plattformen: `.secondScreenEnvironment()` am `RootView` – **außen**, nicht in `ScopedAppContent`, damit Zubehör und Umgebung einen Wechsel des Datenorts (`.id(generation)`, Teilplan 08) überstehen. `SecondScreenState.shared` hält keinen `DataStore` und darf deshalb App-weit sein; Modelle mit `DataStore` bringt Teilplan 07 über `classroomEnvironment()` und bindet sie dort an den aktuellen Datenort. Der Kommentar „Szenen-Zubehör für den Zweitbildschirm meldet Teilplan 06 an dieser Stelle an.“ am Ende von `RootView.body` wird auf diese Stelle in `FrontstageApp` umgeschrieben (sonst widersprechen sich Code und Kommentar).

- [ ] **Step 9: Diff durchsehen** – jede Nutzung von `UISceneAccessory`/`registerSceneAccessory` hinter `#available(iOS 27, *)` und innerhalb `#if compiler(>=6.4)`; die iOS-26-Rollenprüfung hinter `#unavailable(iOS 27)`; macOS-Ziel sieht nichts davon; `Info.plist`/`project.yml` unverändert (SwiftUI erzeugt das Szenen-Manifest). Fällt am Gerät die Szene auf 26 nicht an, ist der erste Prüfschritt `UIApplicationSceneManifest` in `project.yml` (Geräte-Checkliste, Punkt 23-d).

- [ ] **Step 10: Commit** – `git commit -m "feat(second-screen): non-interactive external display scene for iOS 26 and 27"`

---

### Task 12: Smartboard-Leiste, Vorschaubild und „So verbinden“

Design-Takt: voll

**Files:**
- Create: `Frontstage/SecondScreen/SmartboardBar.swift`, `Frontstage/SecondScreen/ConnectHowToView.swift`
- Create (Einhängepunkt, Besitzer Teilplan 07): `Frontstage/ClassScreen/ClassroomControls.swift`
- Modify: `Frontstage/Viewer/ViewerView.swift` (Platzhalter durch `SmartboardBar()` ersetzen), `Frontstage/UI/DayView/DayView.swift` (Teilplan 04: `.safeAreaInset(edge: .bottom) { SmartboardBar() }` nur `#if os(iOS)`), `Frontstage/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `SecondScreenState` aus der Umgebung, `SecondScreenRootView` (Task 11).
- Produces: `SmartboardBar()`, `ClassroomControls()` (Platzhalter für Teilplan 07), `ConnectHowToView()`.

- [ ] **Step 1: Skill `apple-design` laden.**

- [ ] **Step 2: `SmartboardBar`** – eine Zeile mit:
  - **Vorschaubild** (FR-11.5): `SecondScreenRootView(state:)` – dieselbe Ansicht, kein Bildschirmfoto – in einem Rahmen mit `state.screenAspectRatio` (`state` = `SecondScreenState` aus der Umgebung), gezeichnet in einer festen virtuellen Größe von 960 Punkten Breite und per `.scaleEffect` auf die Vorschaubreite verkleinert, damit Schriftgrößen des Klassenbildschirms im selben Verhältnis erscheinen; `.allowsHitTesting(false)`; Bedienungshilfe-Text `secondScreen.preview.accessibility` mit dem Modusnamen und, wenn getrennt, `secondScreen.disconnected`. Das Vorschaubild ist auch ohne verbundenen Bildschirm sichtbar.
  - **Umschalter**: `Picker` mit `.segmented` über `[.classScreen, .material, .board, .dark]`, Bindung liest `state.content` und ruft `state.select(_:)`; nicht verfügbare Inhalte `.disabled` (Systemstandard; Darstellung ist offene Kategorie). „Dunkel“ ist immer verfügbar und kostenlos (FR-11.4, FR-13).
  - `ClassroomControls()` (Einhängepunkt: Platzhalter `EmptyView()`, Kommentar „Timer und Arbeitsform, Teilplan 07“).
  - **Verbindungsstand**: verbunden → Symbol + `secondScreen.connected`; getrennt → `secondScreen.disconnected` und Knopf `secondScreen.howTo`, der `ConnectHowToView` als `.sheet` öffnet. Der Name des Apple TV wird nicht gezeigt (keine Schnittstelle dafür; Mockup zeigt ihn nur zur Veranschaulichung).
  - Änderungen erscheinen ohne Zutun, weil die Leiste `state.isConnected` beobachtet (AK-35: „wenige Sekunden nach dem Verbinden“).

- [ ] **Step 3: `ConnectHowToView`** – Titel `secondScreen.howTo.title`, Abschnitt AirPlay mit drei nummerierten Schritten, Abschnitt Kabel, Hinweis `secondScreen.howTo.autoDetect`, Knopf `viewer.done`. Kein Sprung ins Kontrollzentrum (keine Schnittstelle, FR-11.6). Schließt sich von selbst, sobald `state.isConnected` wahr wird.

- [ ] **Step 4: Texte** (Platzhalter-Wortlaut aus `mockup/anzeige.html`, unpersönlich): `secondScreen.mode.classScreen` = „Klassenbildschirm“, `secondScreen.mode.material` = „Material“, `secondScreen.mode.board` = „Tafel“, `secondScreen.mode.dark` = „Dunkel“, `secondScreen.connected` = „Bildschirm verbunden“, `secondScreen.disconnected` = „Kein Bildschirm verbunden“, `secondScreen.howTo` = „So verbinden“, `secondScreen.howTo.title` = „Mit dem Bildschirm verbinden“, `secondScreen.howTo.autoDetect` = „Frontstage erkennt die Verbindung von selbst und zeigt dann den Klassenbildschirm.“, `secondScreen.howTo.airplay` = „Per AirPlay“, `secondScreen.howTo.step1` = „Von der rechten oberen Ecke nach unten wischen: Das Kontrollzentrum öffnet sich.“, `secondScreen.howTo.step2` = „„Bildschirmsynchronisierung“ antippen.“, `secondScreen.howTo.step3` = „Das Apple TV des Raums wählen.“, `secondScreen.howTo.cable` = „Per Kabel“, `secondScreen.howTo.cableText` = „Adapter (USB-C auf HDMI) anstecken – fertig. Das geht ohne Handgriff und auch, wenn das Schulnetz ausfällt.“, `secondScreen.preview.accessibility` = „Vorschaubild des Zweitbildschirms: %@“.

- [ ] **Step 5: Diff durchsehen** – Leiste und Anleitung nur `#if os(iOS)`; Vorschaubild nutzt `SecondScreenRootView`, keine zweite Darstellungslogik.

- [ ] **Step 6: Prüfung mit `apple-design` als Prüfer** (Design-Takt voll) auf Leiste und Anleitung; offene Kategorien (Platz der Leiste, Dichte, Wortlaut, Darstellung von „nicht verbunden“) nicht entscheiden, im Abschlussbericht als Kandidaten für `/design:design-runde` nennen.

- [ ] **Step 7: Commit** – `git commit -m "feat(second-screen): smartboard bar with live preview, switcher and connect guide"`

---

### Task 13: CI-Lauf (workflow_dispatch) und Ergebnis prüfen

Design-Takt: keiner

**Files:** –

**Diese Aufgabe führt der Controller aus, nicht ein Implementierer** (Sparregel der Übersicht und `CLAUDE.md`: CI kostet macOS-Minuten, höchstens ein Lauf). Im Bündel C läuft der CI-Lauf gemeinsam mit Teilplan 07 (dessen Aufgabe 14) einmal am Bündelende; die Implementierer der Aufgaben 4–12 starten keinen Lauf.

- [ ] **Step 1: Gesamtdiff des Teilplans durchsehen** und vorher `.\scripts\swift-parse.ps1` (Syntaxprüfung, Übersicht) – gegen die Global Constraints: Kern ohne Fremdimporte (lokal grün belegt in Task 1–3); `#available`-/`#unavailable`-Weichen; `#if os(iOS)` um UIKit, `PKCanvasView`, `PKToolPicker`, `SmartboardBar`; jeder Schreibpfad über `PenNoteFileStore` mit `isNotesPath`; keine Bezeichner außerhalb der Glossar-Spalte und der Interfaces-Blöcke (`PenNoteFile` = Glossar „Notiz-Datei“; das Notiz-PDF erscheint im Code nur als `PenNotePDFWriter` und `notesPDFName`); Datenhygiene in Tests (nur `8a`/`8b`, erfundene Materialnamen).
- [ ] **Step 2: Branch pushen und Lauf anstoßen**

```bash
git push -u origin "$(git branch --show-current)"
gh workflow run ci.yml --ref "$(git branch --show-current)"
gh run watch "$(gh run list --workflow ci.yml --branch "$(git branch --show-current)" --limit 1 --json databaseId --jq '.[0].databaseId')"
```

Erwartet (`ci.yml` hat einen Job `build-and-test` mit den Schritten „Core tests“, „Build macOS“, „App tests (iPad simulator)“): Schritt „Core tests“ grün mit `SecondScreenSelectionTests` (10), `PenNoteFitTests` (5), `PenNoteFileLayoutTests` (6), `PenNoteFileTests` (7), `PenNoteRelocationTests` (6); Schritt „App tests“ (`xcodebuild test`, iPad-Simulator) grün mit `SecondScreenStateTests` (7), `DrawingGeometryTests` (5), `PenNoteFileStoreTests` (7), `PenNoteStoreTests` (10), `ViewerModelTests` (9), `PenNotePDFWriterTests` (5), `PenNoteFileServiceTests` (7); macOS-Ziel baut. `readOnlyFolderIsNotWritable` setzt Dateirechte im Simulator – scheitert der Test dort nur am Test-Aufbau, wird er mit Begründung auf die Geräte-Checkliste (Zeile 13-e) verlegt, nicht gelöscht.
- [ ] **Step 3: Bei Fehlschlag** `gh run view --log-failed`, Ursache mit superpowers:systematic-debugging klären, alle Korrekturen sammeln, Diff durchsehen, **ein** neuer Lauf.

---

## Geräte-Checkliste (Mensch mit iPad, Apple TV, Mac)

Nach grünem CI über TestFlight auf ein iPad mit **iPadOS 26** und eines mit **iPadOS 27** (beide Wege, ADR-0007). Material liegt in einem freigegebenen Ordner; je Zeile einmal mit iCloud Drive und einmal mit OneDrive (Dateien-App) – das Verhalten der Anbieter beim Schreiben neben Material ist nur so belegbar (ADR-0011, Kosten). Ergebnis je Zeile eintragen.

| # | AK | Schritte | Erwartet | iPadOS 26 | iPadOS 27 |
|---|---|---|---|---|---|
| 13 | AK-13 | PDF zugeordnet; antippen, mit dem Stift auf Seite 1 schreiben, schließen, erneut öffnen | Notiz ist da; neben dem PDF liegen `<Name>.frontstage-notizen/` mit einer `.json` und `<Name> – Notizen <Klasse> <Datum>.pdf` mit der Notiz (in der Dateien-App und am Mac im Finder sichtbar); Original unverändert (Änderungsdatum) | ☐ | ☐ |
| 13-b | AK-13 | wie oben, statt Schließen sofort Home-Geste; App aus dem App-Umschalter beenden; erneut öffnen | Notiz ist da (Notiz-Datei geschrieben; Notiz-PDF erst beim nächsten Schließen) | ☐ | ☐ |
| 13-c | ADR-0011 | Notiz-PDF in einer anderen App (Vorschau am Mac, Browser in OneDrive) öffnen | Striche an derselben Stelle wie in Frontstage, auch auf einer gedrehten Seite | ☐ | ☐ |
| 13-d | Review Focus 6 | iPad und Mac: dieselbe Stunde; iPad schreibt auf Seite 1, schließen; warten, bis der Anbieter abgeglichen hat; zweites iPad (oder Mac-Ansicht) zeigt Seite 1; erstes iPad schreibt Seite 2 | beide Seiten erhalten; keine Konfliktkopie, die Notizen versteckt (falls der Anbieter eine anlegt: Name notieren ___) | ☐ | ☐ |
| 13-e | Review Focus 5 | Material aus einem **nur lesend geteilten** Ordner (OneDrive „Für mich freigegeben“ ohne Bearbeiten) öffnen und beschreiben | Hinweis „nicht beschreibbar … liegen in Frontstage“; Notiz nach erneutem Öffnen da; kein Notiz-PDF | ☐ | ☐ |
| 13-f | Review Focus 4 | Notiz-Datei am Mac schreiben lassen; am iPad die Notiz-Datei in der Dateien-App „Download entfernen“; Material öffnen | Hinweis „noch nicht geladen“, Schreiben aus; nach dem Laden Notiz sichtbar und beschreibbar | ☐ | ☐ |
| 22 | AK-22 | PDF Di 8a zugeordnet, per „Für 8b übernehmen“ auch Mi 8b; nächste 8a-Stunde Do. Di 8a Seite 1 beschreiben, schließen; Mi 8b öffnen; Di 8a „in die nächste Stunde“; Do öffnen; Ordner am Mac prüfen | Mi 8b ohne Notiz; Do 8a mit Notiz vom Di; Stunden-Datei und Notiz-PDF tragen jetzt das Datum vom Do; Original unverändert | ☐ | ☐ |
| 22-b | ADR-0011 | PDF in der Ablage am Mac durch Fassung mit Querformat-Seite 1 ersetzen; am iPad öffnen | Notiz sichtbar, Hinweis „frühere Fassung“; nichts verschwunden | ☐ | ☐ |
| 22-c | ADR-0011 | PDF mit Notizen im Finder in einen anderen Unterordner verschieben; in Frontstage „Neu verknüpfen“ | Angebot „Notizen mitnehmen“; danach liegen Notiz-Ordner und Notiz-PDF (mit neuem Namen) neben der Datei am neuen Ort | ☐ | ☐ |
| 22-d | Review Focus 8 | iPad im Flugmodus mit einer noch nicht geladenen Notiz-Datei: Material „in die nächste Stunde“; danach online, App aktivieren | Notiz-Datei und PDF tragen nach dem Aktivwerden den neuen Schlüssel | ☐ | ☐ |
| 23 | AK-23 | per AirPlay mit Apple TV verbunden; Tagesansicht öffnen; PDF antippen; Seite 1 beschreiben; schließen | Tagesansicht nie am Apple TV; PDF-Seite im Vollbild ohne Bedienelemente; Notiz erscheint dort beim Schreiben; nach dem Schließen Klassenbildschirm(-Platzhalter), Tagesansicht nur am iPad | ☐ | ☐ |
| 23-b | AK-23 | denselben Ablauf ohne Apple TV | geht vollständig am iPad allein | ☐ | ☐ |
| 23-c | Area anzeige | verbunden; Einrichten/ein Blatt über der Tagesansicht öffnen; Anzeige als Vollbild öffnen | Zweitbildschirm bleibt beim eigenen Inhalt, spiegelt nie | ☐ | ☐ |
| 23-d | ADR-0007 | App mit bereits verbundenem Bildschirm starten | Zweitbildschirm zeigt sofort eigenen Inhalt (auf 26: sonst `UIApplicationSceneManifest` prüfen) | ☐ | ☐ |
| 23-e | Area anzeige | verbunden; Seite blättern und zoomen | Zweitbildschirm folgt Seite und Ausschnitt; Verzögerung beim Schreiben im Schulnetz notieren: ___ | ☐ | ☐ |
| 23-f | Teilplan 08 | verbunden, Anzeige offen; in Einrichten den Datenort wechseln (iCloud ↔ OneDrive) | Zweitbildschirm bleibt beim eigenen Inhalt; nach dem Wechsel öffnet die Anzeige weiter mit Notizen (sie liegen neben dem Dokument, nicht im Datenort) | ☐ | ☐ |
| 29 | AK-29 | verbunden, PDF offen; nacheinander Klassenbildschirm, Material, Tafel, Dunkel wählen | Zweitbildschirm wechselt jeweils; Vorschaubild zeigt jedes Mal dasselbe (Klassenbildschirm und Tafel bis Teilplan 07 als Platzhalter-Fläche) | ☐ | ☐ |
| 28 | AK-28 | PDF am Zweitbildschirm; „Dunkel“, erneut „Dunkel“ | schwarz, dann dieselbe PDF-Seite; iPad zeigt durchgehend das PDF | ☐ | ☐ |
| 35 | AK-35 | nicht verbunden, Tagesansicht offen; „So verbinden“; den Schritten folgen und im Kontrollzentrum das Apple TV wählen; später trennen; dann Kabel (USB-C auf HDMI) anstecken | Anleitung nennt Bildschirmsynchronisierung und Kabel; wenige Sekunden nach dem Verbinden zeigt das iPad „verbunden“ und der Zweitbildschirm den Klassenbildschirm ohne Handgriff; nach dem Trennen „nicht verbunden“; Kabel wie AirPlay | ☐ | ☐ |
| 35-b | Review Focus 2 | während des Schreibens AirPlay im Kontrollzentrum beenden, neu verbinden | keine Striche verloren; Zweitbildschirm zeigt danach das PDF | ☐ | ☐ |
| M | Area anzeige | Mac: Unterrichtsstunde mit am iPad beschriebenem PDF öffnen, schließen | Notizen sichtbar, an derselben Stelle; kein Zeichnen möglich; Notiz-PDF nicht neu geschrieben (Änderungsdatum) | ☐ (macOS 26) | ☐ (macOS 27) |
| M-b | Area anzeige | Hochkant-Foto (iPhone) als Material am iPad öffnen, beschreiben, schließen | aufrecht dargestellt; Notiz-PDF ebenfalls aufrecht | ☐ | ☐ |
| M-c | FR-6.1 | Mac, Vorbereiten: Material mit Notizen „in die nächste Stunde“ | Notiz-Datei und PDF am Mac umbenannt; am iPad in der neuen Stunde sichtbar | ☐ (macOS 26) | ☐ (macOS 27) |

---

## Abdeckung

| Anforderung | Task | AK | Beleg |
|---|---|---|---|
| FR-6 | 5, 6, 7, 10 | AK-13 | `savedNoteIsLoadedAgain`, `writeCreatesFolderAndFile`, `closeFlushesWritesPDFAndReturnsToClassScreen`; Gerät 13, 13-b |
| FR-6.1 (je Unterrichtsstunde, neben dem Dokument, Notiz-Datei + Notiz-PDF) | 2, 3, 5, 6, 8, 9 | AK-13, AK-22 | `otherLessonStartsEmpty`, `moveRenamesBoth`, `moveRenamesNotes`, `writesInkAnnotations`; Gerät 13, 13-c, 22, M-c |
| ADR-0011 – Ersatz im Datenort, Neu verknüpfen, Dokument geändert | 3, 6, 7, 9 | – | `notWritableFallsBackToAppData`, `fallbackNotesMoveIntoFileOnceWritable`, `relinkMovesNotesToNewFile`, `reportsOutdatedAndMissingPages`; Gerät 13-e, 22-b, 22-c |
| FR-3.4 (Original unverändert, Notiz-PDF abgeleitet) | 2, 5, 8 | AK-13 | `onlyNotesPathsAreWritable`, `refusesNonNotesPath`, `sourceDocumentUntouched`; Gerät 13, 22 |
| FR-6.2 | 1, 4, 11 | AK-23 | `openAndCloseMaterial`, `openingPresentsMaterialWithNotes`; Gerät 23–23-f |
| FR-11.4 (Dunkel, vollständig, kostenlos) | 1, 11, 12 | AK-28 | `darkRestoresPreviousMode`; Gerät 28 |
| FR-11.5 | 1, 12 | AK-29 | `switchesThroughAllFourModes`; Gerät 29 |
| FR-11.6 | 1, 11, 12 | AK-35 | `connectingClearsDark`; Gerät 35 |

Nicht in diesem Teilplan: FR-11, FR-11.1–11.3, FR-11.7 (Inhalt des Klassenbildschirms, Timer, Arbeitsform) und FR-12 ff. (Tafel) – Teilplan 07 über die Einhängepunkte; FR-13 (neutrale Fläche statt Klassenbildschirm ohne Kauf) – Teilplan 07 in `ClassScreenView`. Material und „Dunkel“ am Zweitbildschirm bleiben hier ohne Kaufprüfung (FR-13, Nutzerentscheidung 2026-11-13). Abgleich der Ersatz-Datensätze `PenNoteRecord` zwischen Geräten: Teilplan 02 (iCloud) und 08 (OneDrive).

## Abstimmungsbedarf

- **Teilplan 03 (umgesetzt, Bündel A):** zwei additive Ergänzungen in Task 5 – `MaterialResolver.resolveFolder(of:)` und `StorageService.withDocumentLocation(for:_:)`; beide fehlen im Code noch. Die schreibende Ordnerfreigabe ist vorhanden (Preflight 2026-11-14: `FolderGrantStore` mit `.withSecurityScope` ohne Nur-lesen-Option, macOS-Entitlement `files.user-selected.read-write` in `project.yml`). Beide Ergänzungen gehören in dieselbe Datei wie die Klasse, weil sie `private` Mitglieder (`resolver`, `lookup`) nutzen.
- **Teilplan 02 (umgesetzt):** eine additive Methode `DataStore.removePenNotes(for:)` (Task 6, in `DataStore+MaterialLinks.swift`). `PenNoteRecord` bleibt unverändert und wird von 08 weiter abgeglichen.
- **Werkzeugstand (Preflight 2026-11-14, Entwurfsebene, offen):** Die CI (`macos-26`) baut mit Xcode 26.6 / iOS-SDK 26.5. Die iOS-27-Schnittstellen aus Task 11 (`UISceneAccessory`) kompilieren dort nicht; Task 11 schließt sie deshalb in `#if compiler(>=6.4)` ein. Folge: Ein mit Xcode 26 gebauter Stand (CI, TestFlight) hat **keinen** iOS-27-Weg – auf iPadOS 27 erschiene dann gar kein Zweitbildschirm (ADR-0007, Geräte-Checkliste Spalte iPadOS 27). Zu entscheiden: Xcode 27 in `ci.yml`/TestFlight-Workflow auswählen (sofern auf dem Runner vorhanden) oder den iOS-27-Weg bis dahin bewusst zurückstellen.
- **Teilplan 07** füllt nur die Einhängepunkte `ClassScreenView`, `BoardView`, `ClassScreenOverlay`, `ClassroomControls`, `classroomEnvironment()` (Namen und `init()` bleiben); ruft `SecondScreenState.setBoardLesson(_:)` und, für die geöffnete Tafel, `select(.board)` sowie `setBoardAvailable(_:)` (Task 4; Regel getestet in `boardUnavailableFallsBack`, Task 1). Modelle mit `DataStore` bindet 07 selbst an den aktuellen Datenort (`ClassroomServices.bind(store:)`, Teilplan 07).
- **Glossar:** `PenNoteFile` (Notiz-Datei) und `PenNotePDF` (Notiz-PDF) stehen im Glossar; im Code heißt die Erzeugung `PenNotePDFWriter`, ein eigener Typ `PenNotePDF` entsteht nicht (es ist nur eine Datei). Technische Namen ohne Glossarzeile: `SecondScreenContent`, `PenNoteFit`, `PageSize`, `MaterialPresentation`, `PenNoteFileLayout`, `PenNoteRelocation`, `PenNoteStore`, `PenNoteFileService`. Falls „Smartboard-Leiste“ als Begriff in Dokumente eingeht, braucht sie eine Glossar-Zeile (Code-Name hier: `SmartboardBar`).

## Annahmen, die ein Mensch bestätigen sollte

1. **Verbinden hebt „Dunkel“ auf** (`displayConnected`), damit FR-11.6 „ohne weiteren Handgriff“ gilt; Öffnen eines Materials während „Dunkel“ lässt den Bildschirm dagegen dunkel.
2. **Schließen der Anzeige → Klassenbildschirm**, auch wenn vorher „Material“ gewählt war.
3. **„Tafel“ ist aus der Anzeige heraus wählbar** und zeigt die Tafel der Unterrichtsstunde des Materials (aus AK-29 und dem Mockup abgeleitet).
4. **Gespeicherte Seitengröße bleibt die erste**, auch wenn auf der geänderten Seite weitergeschrieben wird – der Hinweis „frühere Fassung“ bleibt dann bestehen.
5. **Zeichnen mit dem Finger** folgt der Systemeinstellung („Nur Apple Pencil“), kein eigener Schalter.
6. **Keine Seitenübersicht** in der ersten Fassung der Anzeige (Mockup zeigt eine); Blättern über Wischen und Knöpfe.
7. Anmelden des Szenen-Zubehörs am **Root-View-Controller** des Fensters genügt, damit es auch unter `.sheet`/`.fullScreenCover` gilt (Apple-Doku sagt das nicht ausdrücklich – Geräteprüfung 23-c).
8. Auf iOS 26 liefert das System die Szene im SwiftUI-Lebenszyklus ohne Eintrag `UIApplicationSupportsMultipleScenes` (Geräteprüfung 23-d).
9. **Notiz-PDF nur nach Änderung oder wenn es fehlt** (Entscheidung 5) statt bei jedem Schließen; ohne Striche wird ein vorhandenes Notiz-PDF entfernt. ADR-0011 sagt „bei jedem Schließen neu geschrieben“ – inhaltlich gleich, aber bitte bestätigen.
10. **Dateiname der Stunden-Datei** in dateisicherer Form (`2026-11-17_8b_englisch_1.json`, Entscheidung 1) statt des wörtlichen `storageText` mit `|`, das OneDrive und Windows nicht erlauben.
11. **Gleiches Dokument in zwei Fächern derselben Klasse am selben Tag** teilt sich einen Notiz-PDF-Namen (Entscheidung 6); die Notiz-Dateien bleiben getrennt.
12. **Löschen der letzten Zuordnung** lässt Notiz-Datei und Notiz-PDF neben dem Dokument stehen (Area anzeige); Ersatz-Datensätze im Datenort werden dagegen mit der Zuordnung gelöscht (`.cascade`, Teilplan 02).
