# Frontstage — Teilplan 11: Hilfe und Rückmeldung

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> Rahmen: `docs/superpowers/plans/2026-11-13-00-uebersicht.md` – gilt vollständig und geht diesem Teilplan vor.

**Goal:** Die App erklärt sich selbst und nimmt Rückmeldungen an (FR-17 bis FR-17.5): Hilfeknöpfe an jedem Hauptbildschirm und jedem schwierigen Bereich, ein durchsuchbares Hilfecenter ohne Netz (am Mac im Menü „Hilfe“, ⌘?), Rückmeldung als Idee oder Hinweis per E-Mail über das System mit Bildschirmfotos, auf die man zeichnen und Stellen schwärzen kann, und Kurz-Tipps beim ersten Gebrauch – alles kostenlos, ohne Server (ADR-0014).

**Architecture:** Reine Logik im Kern (`Packages/FrontstageCore/Sources/FrontstageCore/Help/`, `…/Feedback/`): Themen samt Gruppen und verwandten Themen, Zerlegen des Artikeltexts in Blöcke, Katalog mit Prüfung, Suche mit Rangfolge, Entwurf, Geräteangaben, Betreff und Text der Mail, Empfangsadresse, Bildgrenzen und Weg (Mail oder Teilen) – lokal mit `scripts\swift-test.ps1` belegt. Die Artikeltexte stehen in `Localizable.xcstrings`; ein Kern-Test liest diese Datei aus dem Repo und prüft Vollständigkeit und Datenhygiene. Die App lädt den Katalog aus dem Bundle, zeigt Artikel als Blatt am Ort des Hilfeknopfs, speichert den Entwurf nur lokal, nimmt das Fenster der Hauptszene auf, zeichnet mit PencilKit (Mac: eigene Zeichenfläche, die `PKStroke` erzeugt), schwärzt mit deckenden Rechtecken und übergibt an `MFMailComposeViewController` bzw. `NSSharingService`; Rückfall `ShareLink` und Kopieren. Kurz-Tipps über TipKit.

**Tech Stack:** Swift 6 strikt, SwiftUI (`.sheet`, `NavigationStack`, `.searchable`, `PhotosPicker`, `ShareLink`, `CommandGroup(replacing: .help)`, `TipView`/`.popoverTip`), PencilKit (`PKDrawing`, `PKCanvasView`/`PKToolPicker` nur iPad, `PKStroke`/`PKStrokePath`/`PKStrokePoint` auch Mac), MessageUI (iPad), AppKit `NSSharingService` (Mac), ImageIO/CoreGraphics, TipKit, Swift Testing, XcodeGen. Keine neue Abhängigkeit.

**Spec:** `docs/PRD.md` (FR-17 bis FR-17.5, FR-13 „Geändert 2026-11-16“, AK-55 bis AK-60, RISK-11, Q-42, Glossar „Hilfethema“ `HelpTopic`, „Hilfeartikel“ `HelpArticle`, „Hilfeknopf“ `HelpButton`, „Hilfecenter“ `HelpCenter`, „Rückmeldung“ `Feedback` mit `kind` `idea`/`issue`, „Bildschirmfoto“ `FeedbackAttachment` mit `markup`/`redactions`, „Kurz-Tipp“ `HelpTips`); `docs/adr/0014-rueckmeldung-per-e-mail-ohne-eigenen-server.md`; `docs/ARCHITECTURE.md` (Area plattform, Abschnitt „Hilfe und Rückmeldung“); `docs/adr/0009-quellcode-englisch-kommentare-deutsch.md` (Texte in `Localizable.xcstrings`); `DESIGN.md` UI-2 bis UI-15 (anwenden, nichts neu beschließen).

**Baut auf (Code auf `main`):** Teilpläne 01–10 vollständig gemergt. Genutzt werden u. a.: `RootView` (Tabs, `.appTheme(store:unlock:)`, `.environment(\.showSetup, …)`), `FrontstageApp` (`WindowGroup`, `scenePhase`), `SetupView` (Sections, `scoped { … }`), `DataLocationController.location`/`.store`, `DataStore.theme()` (10), `ClassroomServices.shared.unlock.isUnlocked` (07), `Theme`/`BaseTone`/`AppearanceMode` (10, Kern), `DataLocation` (08, Kern), `DrawingGeometry.toPageSpace(_:viewSize:pageSize:)`/`toViewSpace(_:viewSize:pageSize:)` (06, `Frontstage/Viewer/DrawingGeometry.swift`, ohne `#if`, also auch am Mac) und `PageSize` (Kern, `Packages/FrontstageCore/Sources/FrontstageCore/PenNotes/PenNoteFit.swift`), `PenCanvas`-Muster mit `PKToolPicker` (06), `TypeScale`/`scaledFont(_:)`, `CapsuleActionButtonStyle`, `themedBackground()` (10), `PurchaseOfferView`, `PaidGate` (07), `ConnectHowToView`, `SmartboardBar` (06), `BoardScreen` (07), `ViewerView` (06), `makeStore()` (`FrontstageTests/Data/Fixtures.swift`).

## Global Constraints

Alle Zeilen der Übersicht gelten (Abschnitt „Global Constraints“, Abstimmung Punkte 1–18). Zusätzlich für diesen Teilplan:

- **Kern zuerst und lokal belegt:** Tasks 1–4 berühren nur `Packages/FrontstageCore` (nur `import Foundation`) bzw. in Task 4 zusätzlich `Frontstage/Resources/Localizable.xcstrings` und laufen TDD mit `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\swift-test.ps1 -Filter <Struct>`. Gefiltert wird nach dem **Namen der Suite-Struktur** (`HelpBodyParserTests`), nie nach dem Anzeigenamen aus `@Suite("…")` – sonst läuft nichts bei Exit-Code 0. Jede Suite-Struktur heißt wie ihre Datei. Tasks 5–11 sind App-Code: auf Windows nicht baubar; „Test ausführen“ heißt dort Task 12 (ein CI-Lauf, führt der Controller aus). Vor jedem Commit eines App-Tasks `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\swift-parse.ps1` (keine Zeile mit `error:`) und Diff-Durchsicht.
- **Begriffe (Glossar):** `HelpTopic`, `HelpArticle`, `HelpButton`, `HelpCenter` (Ansicht `HelpCenterView`), `Feedback…` mit `FeedbackKind` (`idea`, `issue`), `FeedbackAttachment` (`markup`, `redactions`), `HelpTips`. Rein technische Namen dieses Plans (`HelpGroup`, `HelpBlock`, `HelpBodyParser`, `HelpCatalog`, `HelpSearch`, `HelpText`, `NormalizedRect`, `DeviceInfo`, `FeedbackDraft`, `FeedbackMessage`, `FeedbackComposer`, `FeedbackRecipient`, `FeedbackAttachmentPolicy`, `FeedbackRoute`, `HelpLibrary`, `FeedbackDraftStore`, `FeedbackImageEncoder`, `WindowCapture`, `MarkupEditorModel`, `FeedbackModel`, `FeedbackSession`, `FeedbackContext`, `SupportCoordinator`) brauchen keine Glossarzeile (Übersicht, Abstimmung Punkt 10).
- **Neue App-Ordner:** `Frontstage/Help/` und `Frontstage/Feedback/` (Unterordner `Feedback/Markup/`); Tests unter `FrontstageTests/Help/` und `FrontstageTests/Feedback/`. Plattformcode mit `#if os(iOS)` / `#if os(macOS)`, keine eigenen Ordner je Plattform.
- **Empfangsadresse (ADR-0014, Q-42):** Build-Einstellung `FEEDBACK_EMAIL`, im Repo nur `feedback@example.com`; Info.plist-Schlüssel `FrontstageFeedbackEmail` in **beiden** Zielen; CI übergibt `FEEDBACK_EMAIL="${{ secrets.FEEDBACK_EMAIL }}"` wie `MSAL_CLIENT_ID`. Nie eine echte Adresse in Code, Tests oder Doku.
- **Kostenlos (FR-13 geändert 2026-11-16):** Kein Hilfe- oder Rückmeldungs-Code steht hinter `PaidGate` oder fragt `Unlock` ab – außer zum Auslesen des Kaufstands für die Geräteangaben.
- **Geräteangaben nur aus diesen Quellen:** `CFBundleShortVersionString`, `CFBundleVersion`, Systemname und -version, Modellkennung (`sysctlbyname("hw.machine")` am iPad, `"hw.model"` am Mac), `DataLocationController.location`, `DataStore.theme()`, `Unlock.isUnlocked`, `Locale.current.language.languageCode`. **Nie** `UIDevice.current.name`, `Host.current().localizedName`, Benutzername, Klassen, Fächer, Dateinamen.
- **Bilder:** höchstens **5** je Rückmeldung; beim Hinzufügen auf längste Kante **2048 px** verkleinert, JPEG Qualität **0,85**; Dateinamen in der Mail `Bildschirmfoto-1.jpg` … `Bildschirmfoto-5.jpg`. Schwärzen = deckend schwarzes Rechteck (`#000000`, Deckkraft 1) **über** der Zeichnung.
- **Texte:** alles über `Frontstage/Resources/Localizable.xcstrings` (Schlüssel englisch, Wert deutsch, `"state": "translated"`); Hilfeartikel als Schlüssel `help.<topic>.title`, `help.<topic>.summary`, `help.<topic>.keywords`, `help.<topic>.body` mit `"extractionState" : "manual"` (sie werden nur dynamisch gelesen; ohne die Markierung hält Xcode sie für veraltet). Wortlaut nach UI-15: „du“, Verb zuerst, Aussagen als Zustand. **Ausnahme:** Betreff und Text der Mail stellt der Kern mit festen deutschen Bezeichnungen zusammen (ein Datenformat für die Empfänger, keine Oberfläche; Entscheidung 6).
- **Design-Takt:** Jeder UI-Task trägt `Design-Takt: Hauptstufe` – vor dem Editieren den projektlokalen Skill `apple-design` laden (fehlt er: `npx skills add dickwu/apple-design-skill --skill apple-design -y`); nie `impeccable` oder `web-design-guidelines`. Beschlüsse stehen in DESIGN.md (UI-2 bis UI-15): Inhalt in SF Rounded (`.fontDesign(.rounded)` kommt über die Tabs bzw. ist an jedem neuen Blatt zu setzen), Hierarchie nur über Größe (`scaledFont`), Aktionen als Kapseln (`CapsuleActionButtonStyle`), Hintergründe über `themedBackground()`, Akzent nur für Bedienbares. **Kein Task erfindet einen Gestaltungsbeschluss;** eine Lücke folgt der nächstliegenden Regel und steht in einer Zeile im Abschlussbericht. DESIGN.md wird in diesem Teilplan nicht geändert.
- **Barrierefreiheit:** Jeder Hilfeknopf hat `accessibilityLabel` „Hilfe zu <Titel>“ und am Mac `.help(…)`; jedes Bildschirmfoto ein Label („Bildschirmfoto 1, mit Zeichnung“); alle Texte skalieren mit Dynamic Type; Zeichnen und Schwärzen haben eine Alternative ohne Ziehen nicht – das ist eine benannte Lücke (Bild ohne Zeichnung senden geht immer).
- **Testdaten:** Klassen `8b`, `9c`, `7a`; Material „Arbeitsblatt Vokabeln.pdf“. Adressen: Negativfälle mit Platzhaltern (`feedback@example.com`, `a@b.local`, `a@b.test`); Positivfälle mit der erfundenen Adresse `hilfe@frontstage-rueckmeldung.de` – reservierte Test-Domains (`.invalid`, `.test`) lehnt `FeedbackRecipient` ja gerade ab. Keine echte Adresse.

## Entscheidungen dieses Teilplans (mit Begründung)

1. **Artikeltexte in `Localizable.xcstrings`, Aufbau im Kern.** *Grund:* ADR-0009 bleibt unberührt, eine Übersetzungstabelle für alles (Q-10), Xcode zeigt mehrzeilige Werte lesbar. *Verworfen:* Markdown-Dateien im Bundle – angenehmer zu schreiben, aber eine zweite Textquelle neben der Tabelle (Abweichung von ADR-0009) und eine eigene Übersetzungslogik; strukturierter Swift-Katalog mit deutschen Literalen – Texte im Code, widerspricht ADR-0009.
2. **Eigener kleiner Block-Parser statt `AttributedString(markdown:)` für den ganzen Text.** SwiftUI-`Text` stellt Blockstruktur (Zwischentitel, Listen) nicht dar; der Kern zerlegt den Text in Blöcke (`##`, `- `, `1. `, `> `, Absatz), die App setzt jeden Block und rendert nur **innerhalb** eines Blocks `AttributedString(markdown:options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))` für fett und Links. *Grund:* testbar unter Windows, volle Kontrolle über Schriftgrößen (UI-6).
3. **Suche im Kern mit eigener Faltung** (klein; ä→a, ö→o, ü→u, ß→ss, é/è/ê→e, à/á/â→a), Treffer = alle Suchwörter (≥ 2 Zeichen) kommen als Wortanfang vor; Punkte je Wort: Titelwort gleich 12, Titelwort-Anfang 10, Stichwort 6, Kurzfassung 3, Text 1; Summe absteigend, bei Gleichstand Reihenfolge von `HelpTopic.allCases`. *Grund:* gleiches Ergebnis auf Windows, im Simulator und am Gerät; `String.folding(options:locale:)` verhält sich unter Foundation für Windows nicht garantiert gleich. *Verworfen:* Volltextindex – 21 Artikel brauchen keinen.
4. **Hilfeknopf zeigt sein Blatt selbst** (`.sheet` am Knopf), nicht über ein zentrales Blatt in `RootView`. *Grund:* Knöpfe stehen auch in Blättern (Koppeln, Tafel, Anzeige, „So verbinden“); ein Blatt aus `RootView` erscheint dort nicht. Das Hilfecenter aus dem Menü „Hilfe“ und „Rückmeldung geben …“ aus dem Menü kommen dagegen über `SupportCoordinator` als Blatt über `RootView` (Entscheidung 9).
5. **Aufnahme nach dem Schließen des Hilfeblatts.** „Rückmeldung geben“ im Artikel schließt das Blatt; erst im `onDismiss` nimmt `WindowCapture` das Fenster auf und öffnet die Rückmeldung am selben Ort. *Grund:* FR-17.4 „ohne das Hilfe- oder Rückmeldungsfenster“. Aufgenommen wird nur die Hauptszene (`session.role == .windowApplication`, `activationState == .foregroundActive`), nie die Szene des Zweitbildschirms.
6. **Mailtext fest deutsch aus dem Kern.** Bezeichnungen „Art“, „Hilfethema“, „Bildschirmfotos“, „Geräteangaben“ usw. stehen als Literale in `FeedbackComposer`/`DeviceInfo`. *Grund:* Empfänger sind die Entwickler; einheitlich lesbar und im Kern testbar. Das Hilfethema steht als Kennung (`dataLocation`), nicht als Titel.
7. **Schwärzen als deckende Rechtecke**, nicht als schwarzer Marker. *Grund:* Der PencilKit-Marker ist durchscheinend, Text darunter bliebe lesbar (RISK-11). Rechtecke werden normiert (0…1, Ursprung oben links) gespeichert, zuletzt gezeichnet und überdecken damit auch Striche. *Verworfen:* schwarzer Marker (Vorschlag aus der Aufgabe) – unsicher; Weichzeichnen – umkehrbar bei kleiner Schrift.
8. **Zeichnen:** iPad `PKCanvasView` + `PKToolPicker` (Stift, Marker, Radierer – wie Tafel und Anzeige), `drawingPolicy = .anyInput` (Finger erlaubt; Bildschirmfotos markiert man auch ohne Stift). **Mac:** `PKCanvasView` gibt es dort nicht (Apple-Doku: iOS, iPadOS, Mac Catalyst, visionOS); eigene Zeichenfläche mit `DragGesture`, die beim Loslassen einen `PKStroke` (`PKInk(.pen, color: .systemRed)` bzw. `PKInk(.marker, color: .systemYellow)`) an die `PKDrawing` hängt; statt Radierer „Rückgängig“ und „Alles löschen“. Beide speichern `PKDrawing.dataRepresentation()` im **Bildpixel-Raum** (`DrawingGeometry` mit `PageSize` = Pixelgröße), damit das Zusammensetzen auf beiden Plattformen gleich rechnet.
9. **Menü „Hilfe“ öffnet Blätter, keine eigenen Fenster.** `CommandGroup(replacing: .help)` mit „Frontstage-Hilfe“ (⌘?) und „Rückmeldung geben …“ ruft `SupportCoordinator.shared`; `RootView` zeigt Hilfecenter bzw. Rückmeldung als Blatt. *Grund:* ein Weg für Mac und iPad mit Tastatur. *Verworfen:* eigene `Window`-Szenen am Mac – zweiter Aufnahmeweg, zweite Umgebung. *Kosten:* Ist schon ein anderes Blatt offen, öffnet der Menüpunkt nichts (Offene Risiken 3).
10. **Entwurf** liegt in `Application Support/Feedback/` (`draft.json`, `<uuid>.jpg`, `<uuid>.drawing`), Ordner mit `isExcludedFromBackup`; ein unlesbarer Entwurf gilt als „kein Entwurf“ und wird beim nächsten Speichern überschrieben. Startet die Lehrkraft eine Rückmeldung, während ein Entwurf besteht, öffnet sich dieser; die neue Aufnahme wird **hinten** angehängt, wenn Platz ist, sonst verworfen. Art und Hilfethema eines bestehenden Entwurfs bleiben.
11. **Voreinstellungen:** Art `issue` beim Start aus einem Hilfeartikel oder dem Menü, sonst die gewählte Taste im Hilfecenter („Idee senden“ / „Hinweis senden“); Geräteangaben **aus** (FR-17.3); Text Pflicht (mindestens ein Zeichen außer Leerraum), Bilder nicht.
12. **Nach dem Senden:** iPad leert den Entwurf nur bei `MFMailComposeResult.sent`; `.saved` und `.cancelled` behalten ihn; `.failed` zeigt einen Hinweis. Mac leert ihn bei `sharingService(_:didShareItems:)` (Übergabe an Mail; ADR-0014 Kosten). Teilen und Kopieren leeren nie – dafür gibt es „Entwurf verwerfen“.
13. **Kurz-Tipps:** vier Tipps (`DaySelectionTip`, `MaterialTileTip`, `SmartboardBarTip` nur iPad, `HelpButtonTip`), `Tips.configure([.displayFrequency(.daily)])`; gemeinsamer Schalter `HelpTips.$isEnabled` (`@Parameter static var isEnabled: Bool = true` in `struct HelpTips`, laut Apple-Doku als statischer Parameter außerhalb eines Tips zulässig) in jeder Regel. Zurücksetzen setzt `UserDefaults`-Schlüssel `help.tips.resetOnNextLaunch`; beim Start ruft `HelpTipsConfiguration` dann `Tips.resetDatastore()` **vor** `Tips.configure` (Apple: muss davor stehen). Im Testlauf (`XCTestConfigurationFilePath` gesetzt) wird TipKit nicht konfiguriert – Tests hängen nie am Tip-Zustand.
14. **Verworfene Wege für die Rückmeldung** (ADR-0014): eigener Endpunkt/Web-Formular (Server, NFR-2), GitHub-Issues (Schlüssel in der App), nur TestFlight-Feedback (fehlt im App Store), App-Store-Bewertungen (öffentlich, ohne Bilder). Kein Task baut einen davon nach.
15. **Platzierung der Hilfeknöpfe** (FR-17.1): eigenes `ToolbarItem(placement: .automatic)` bzw. im Section-Header; Thema je Ort siehe Task 10. Einrichten bekommt unten die Section „Hilfe und Rückmeldung“ (iPad-Einstellungen-Muster: Hilfe zuletzt).

## Review Focus

1. **Rückmeldung aus einem offenen Hilfeblatt** → das erste Bildschirmfoto zeigt den Bildschirm darunter, nicht das Hilfeblatt; aus einem Blatt heraus (Koppeln, Tafel) erscheint die Rückmeldung trotzdem. Tests: Task 8 `FeedbackStarterTests.captureRunsBeforeSessionExists` (Reihenfolge Aufnahme → Sitzung), Task 10 `SupportCoordinatorTests.menuFeedbackCapturesFirst`; Geräte-Checkliste 4.
2. **Geschwärzte Stelle mit Strich darüber, Bild verkleinert** → im gesendeten JPEG vollständig schwarz. Tests: Task 6 `FeedbackImageEncoderTests.redactionCoversAreaCompletely`, `redactionDrawnAboveMarkup`, `downscaleKeepsRedactionPosition`.
3. **Keine echte Adresse konfiguriert** (leer, `$(FEEDBACK_EMAIL)` unaufgelöst, `feedback@example.com`) → kein Mail-Fenster an eine Platzhalteradresse, sondern Teilen/Kopieren mit Hinweis. Tests: Task 3 `FeedbackRecipientTests.rejectsPlaceholders`, `rejectsUnresolvedBuildSetting`; `FeedbackRouteTests.noRecipientWinsOverMailAccount`; Task 8 `FeedbackModelTests.routeWithoutRecipientIsShare`.
4. **Entwurf mit Bildern, App beendet; Entwurfsdatei kaputt** → nach Neustart ist alles da; kaputte Datei startet leer ohne Absturz; nach „verwerfen“ oder Senden liegen keine Bilddateien mehr im Ordner. Tests: Task 6 `FeedbackDraftStoreTests.roundTripsDraftWithAttachments`, `corruptDraftLoadsAsNil`, `discardRemovesAllFiles`; Task 8 `FeedbackModelTests.didSendClearsDraftAndFiles`.
5. **Text mit leerer erster Zeile, sehr langer Zeile, nur Leerraum** → Betreff aus der ersten nicht leeren Zeile, auf 60 Zeichen mit „…“; nur Leerraum lässt sich nicht senden. Tests: Task 3 `FeedbackComposerTests.subjectUsesFirstNonEmptyLine`, `subjectIsCutAt60WithEllipsis`; `FeedbackDraftTests.whitespaceOnlyCannotSend`.

---

## Dateistruktur

| Datei | Verantwortung | Task |
|---|---|---|
| `Packages/FrontstageCore/Sources/FrontstageCore/Help/HelpTopic.swift`, `HelpBody.swift` | Themen, Gruppen, verwandte Themen; Blöcke und Parser | 1 |
| `…/Help/HelpText.swift`, `HelpArticle.swift`, `HelpCatalog.swift`, `HelpSearch.swift` | Faltung, Artikel, Katalog mit Prüfung, Suche | 2 |
| `…/Feedback/FeedbackKind.swift`, `FeedbackDraft.swift`, `NormalizedRect.swift`, `DeviceInfo.swift`, `FeedbackComposer.swift`, `FeedbackRecipient.swift`, `FeedbackAttachmentPolicy.swift`, `FeedbackRoute.swift` | Rückmeldung als Werte und Regeln | 3 |
| `Frontstage/Resources/Localizable.xcstrings` (ändern); `Packages/FrontstageCore/Tests/FrontstageCoreTests/Help/HelpContentTests.swift` | 21 Hilfeartikel; Prüfung gegen die echte Tabelle | 4 |
| `Packages/FrontstageCore/Tests/FrontstageCoreTests/Help/*Tests.swift`, `…/Feedback/*Tests.swift` | Kern-Tests | 1–4 |
| `project.yml`, `.github/workflows/ci.yml` (ändern); `Frontstage/Help/HelpLibrary.swift`, `Frontstage/Feedback/FeedbackConfiguration.swift` | Build-Einstellung, Katalog aus dem Bundle, Adresse | 5 |
| `Frontstage/Feedback/FeedbackDraftStore.swift`, `FeedbackImageEncoder.swift`, `WindowCapture.swift`, `DeviceInfoCollector.swift` | Entwurf auf dem Gerät, Bilder, Aufnahme, Geräteangaben | 6 |
| `Frontstage/Feedback/Markup/MarkupEditorModel.swift`, `MarkupEditorView.swift`, `MarkupCanvas.swift` (iPad), `MacMarkupCanvas.swift` (Mac), `RedactionOverlay.swift` | Zeichnen und Schwärzen | 7 |
| `Frontstage/Feedback/FeedbackModel.swift`, `FeedbackView.swift`, `FeedbackSession.swift`, `MailComposeView.swift` (iPad), `MacMailComposer.swift` (Mac), `AttachmentStrip.swift` | Rückmeldung schreiben und senden | 8 |
| `Frontstage/Help/HelpButton.swift`, `HelpSheet.swift`, `HelpArticleView.swift`, `HelpBlockView.swift`, `HelpCenterView.swift`, `HelpCenterModel.swift` | Hilfe-Oberfläche | 9 |
| `Frontstage/Help/SupportCoordinator.swift`, `HelpCommands.swift`; `App/FrontstageApp.swift`, `App/RootView.swift`, `UI/Setup/SetupView.swift` und die Bildschirme aus Task 10 (ändern) | Knöpfe einsetzen, Menü, Einrichten | 10 |
| `Frontstage/Help/HelpTips.swift`, `HelpTipsConfiguration.swift`; `FrontstageApp.swift`, `HelpCenterView.swift`, `DayView.swift`, `DayLessonDetail.swift`, `SmartboardBar.swift` (ändern) | Kurz-Tipps | 11 |
| `FrontstageTests/Help/HelpLibraryTests.swift`, `HelpCenterModelTests.swift`, `SupportCoordinatorTests.swift`, `HelpTipsConfigurationTests.swift`; `FrontstageTests/Feedback/FeedbackDraftStoreTests.swift`, `FeedbackImageEncoderTests.swift`, `DeviceInfoCollectorTests.swift`, `MarkupEditorModelTests.swift`, `FeedbackModelTests.swift`, `FeedbackStarterTests.swift` | App-Tests (Simulator) | 5–11 |

---

### Task 1: Hilfethemen und Artikeltext in Blöcken (FR-17, FR-17.1)

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Help/HelpTopic.swift`, `Packages/FrontstageCore/Sources/FrontstageCore/Help/HelpBody.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/Help/HelpTopicTests.swift`, `Packages/FrontstageCore/Tests/FrontstageCoreTests/Help/HelpBodyParserTests.swift`

**Interfaces:**
- Consumes: –
- Produces:

```swift
/// Hilfethema (Glossar). Reihenfolge = Reihenfolge im Hilfecenter und bei Gleichstand in der Suche.
public enum HelpTopic: String, CaseIterable, Codable, Sendable, Hashable {
  case gettingStarted, dayView, openingMaterial, penNotes, secondScreen, classScreen, board,
       preparation, coursePlan, timetable, bellSchedule, nonTeachingDays, schoolYears, schulmanager,
       storage, dataLocation, pairing, appearance, purchase, privacy, feedback
  public var group: HelpGroup { get }
  public var related: [HelpTopic] { get }          // feste Tabelle unten, nie self
  public var textKeyPrefix: String { get }         // "help.\(rawValue)"
}
public enum HelpGroup: String, CaseIterable, Sendable { case start, teaching, classroom, planning, setup, about }
extension HelpGroup { public var topics: [HelpTopic] { get } }   // in allCases-Reihenfolge
public enum HelpBlock: Hashable, Sendable {
  case heading(String), paragraph(String), bullets([String]), steps([String]), note(String)
}
public enum HelpBodyError: Error, Equatable, Sendable { case empty, unsupportedHeading(line: Int) }
public enum HelpBodyParser { public static func parse(_ text: String) throws -> [HelpBlock] }
```

Gruppen: `start` = gettingStarted · `teaching` = dayView, openingMaterial, penNotes · `classroom` = secondScreen, classScreen, board · `planning` = preparation, coursePlan · `setup` = timetable, bellSchedule, nonTeachingDays, schoolYears, schulmanager, storage, dataLocation, pairing, appearance · `about` = purchase, privacy, feedback.

Verwandte Themen (`related`): gettingStarted → timetable, storage, dataLocation · dayView → openingMaterial, secondScreen, preparation · openingMaterial → storage, penNotes, dayView · penNotes → openingMaterial, secondScreen · secondScreen → classScreen, board, dayView · classScreen → secondScreen, purchase · board → secondScreen, purchase · preparation → dayView, coursePlan, storage · coursePlan → schoolYears, preparation · timetable → bellSchedule, schulmanager, nonTeachingDays · bellSchedule → timetable · nonTeachingDays → schoolYears, timetable · schoolYears → coursePlan, nonTeachingDays · schulmanager → timetable, privacy · storage → openingMaterial, dataLocation · dataLocation → pairing, privacy · pairing → dataLocation · appearance → purchase · purchase → classScreen, board, appearance · privacy → dataLocation, feedback · feedback → privacy.

Parser-Regeln (zeilenweise, `\n` oder `\r\n`): `## Text` → `heading`; `- Text` → Punkt in `bullets` (aufeinanderfolgende zusammen); `<Ziffern>. Text` → Schritt in `steps`; `> Text` → `note` (aufeinanderfolgende mit Leerzeichen verbunden); Leerzeile beendet jeden Block; andere Zeilen bilden Absätze (Zeilen mit einem Leerzeichen verbunden, getrimmt). `#` oder `###`… am Zeilenanfang → `unsupportedHeading(line:)` (1-basiert). Nur Leerraum → `empty`. Inline-Markdown (`**fett**`, `[Text](url)`) bleibt unverändert im String.

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("Help Topics") struct HelpTopicTests`, `@Suite("Help Body") struct HelpBodyParserTests`)

```swift
@Test("21 Themen, Rohwerte englisch") func allTopics() { #expect(HelpTopic.allCases.count == 21); #expect(HelpTopic.dataLocation.rawValue == "dataLocation") }
@Test("Jedes Thema in genau einer Gruppe, Gruppen decken alles ab") func groupsPartitionTopics() {
  #expect(HelpGroup.allCases.flatMap(\.topics).sorted { $0.rawValue < $1.rawValue } == HelpTopic.allCases.sorted { $0.rawValue < $1.rawValue })
}
@Test("Verwandte Themen: 1–3, nie das Thema selbst, ohne Doppelte") func relatedIsSane()
@Test("Textschlüssel") func textKeyPrefix() { #expect(HelpTopic.board.textKeyPrefix == "help.board") }
// HelpBodyParserTests
@Test("Absatz, Zwischentitel, Liste, Schritte, Hinweis") func parsesAllBlocks() throws {
  let text = "Erste Zeile\nzweite Zeile\n\n## So geht es\n1. Öffne Einrichten.\n2. Tippe auf **Datenort**.\n\n- iCloud\n- OneDrive\n\n> Wechseln nimmt alle Daten mit."
  #expect(try HelpBodyParser.parse(text) == [.paragraph("Erste Zeile zweite Zeile"), .heading("So geht es"),
    .steps(["Öffne Einrichten.", "Tippe auf **Datenort**."]), .bullets(["iCloud", "OneDrive"]), .note("Wechseln nimmt alle Daten mit.")])
}
@Test("CRLF wie LF") func handlesCRLF() throws
@Test("Leerer Text ist ein Fehler") func emptyThrows() { #expect(throws: HelpBodyError.empty) { try HelpBodyParser.parse(" \n ") } }
@Test("# und ### sind nicht erlaubt, mit Zeilennummer") func rejectsOtherHeadings() { #expect(throws: HelpBodyError.unsupportedHeading(line: 3)) { try HelpBodyParser.parse("A\n\n### B") } }
@Test("Liste endet an Absatz ohne Leerzeile") func bulletThenParagraph() throws   // "- a\nText" → [.bullets(["a"]), .paragraph("Text")]
```

- [ ] **Step 2: Rot belegen** – `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\swift-test.ps1 -Filter HelpTopicTests` → „cannot find 'HelpTopic' in scope“; dasselbe mit `-Filter HelpBodyParserTests`.
- [ ] **Step 3: Implementieren** (Signaturen und Regeln oben).
- [ ] **Step 4: Grün belegen** – beide Filter, danach `scripts\swift-test.ps1` ohne Filter.
- [ ] **Step 5: Commit** – `git commit -m "core: add help topics and help body parser"`

---

### Task 2: Katalog, Prüfung und Suche (FR-17.2)

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Help/HelpText.swift`, `HelpArticle.swift`, `HelpCatalog.swift`, `HelpSearch.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/Help/HelpTextTests.swift`, `HelpCatalogTests.swift`, `HelpSearchTests.swift`

**Interfaces:**
- Consumes: `HelpTopic`, `HelpGroup`, `HelpBlock`, `HelpBodyParser`, `HelpBodyError` (1)
- Produces:

```swift
public enum HelpText {
  public static func fold(_ text: String) -> String      // klein + Faltung (Entscheidung 3)
  public static func words(_ text: String) -> [String]   // gefaltet, an allem außer Buchstaben/Ziffern getrennt, ohne leere
}
public struct HelpArticle: Hashable, Sendable, Identifiable {
  public let topic: HelpTopic; public let title: String; public let summary: String
  public let keywords: [String]; public let blocks: [HelpBlock]
  public var id: HelpTopic { topic }
  public init(topic: HelpTopic, title: String, summary: String, keywords: [String], blocks: [HelpBlock])
}
public enum HelpCatalogIssue: Hashable, Sendable { case missingText(key: String), invalidBody(HelpTopic, HelpBodyError) }
public struct HelpCatalog: Sendable {
  public init(articles: [HelpArticle])
  public func article(for topic: HelpTopic) -> HelpArticle?
  public var articles: [HelpArticle] { get }             // in allCases-Reihenfolge
  /// Baut den Katalog aus einer Textquelle (`nil` = fehlt). Stichwörter: an "," getrennt, getrimmt, ohne leere.
  public static func build(text: (String) -> String?) -> (catalog: HelpCatalog, issues: [HelpCatalogIssue])
}
public enum HelpSearch {
  public static let minimumTermLength = 2
  public static func results(for query: String, in catalog: HelpCatalog) -> [HelpTopic]   // leer bei leerer Anfrage
}
```

`build` fragt je Thema `<prefix>.title`, `.summary`, `.keywords`, `.body`; fehlt einer, Eintrag `missingText(key:)` und das Thema fehlt im Katalog; ein Parser-Fehler gibt `invalidBody`. Suche nach Entscheidung 3 (Körpertext = alle Block-Strings zusammen).

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("Help Text") struct HelpTextTests`, `@Suite("Help Catalog") struct HelpCatalogTests`, `@Suite("Help Search") struct HelpSearchTests`; Hilfsfunktion je Datei privat `article(_ topic:, title:, keywords:, body:)`)

```swift
@Test("Faltung: Umlaute, ß, Akzente, Groß") func folds() { #expect(HelpText.fold("Übernehmen ÄÖÜ ß Café") == "ubernehmen aou ss cafe") }
@Test("Wörter: Satzzeichen trennen") func splitsWords() { #expect(HelpText.words("Ferien/Feiertage, 8b!") == ["ferien", "feiertage", "8b"]) }
// HelpCatalogTests
@Test("Vollständige Texte ergeben 21 Artikel ohne Befund") func buildsFromCompleteTexts()
@Test("Fehlender Text wird gemeldet, Thema fehlt") func reportsMissingText()   // ohne "help.board.body" → issues == [.missingText(key: "help.board.body")], article(for: .board) == nil
@Test("Ungültiger Text wird gemeldet") func reportsInvalidBody()                // body "# X" → .invalidBody(.board, .unsupportedHeading(line: 1))
@Test("Stichwörter getrimmt, leere fallen weg") func splitsKeywords()           // " AirPlay, Kabel ,, " → ["AirPlay", "Kabel"]
// HelpSearchTests – Katalog: secondScreen (Titel „Smartboard verbinden“, Stichwörter „AirPlay, Apple TV, Kabel“),
// classScreen (Text erwähnt AirPlay), nonTeachingDays (Titel „Ferien und Feiertage“), schoolYears (Text „Ferien“),
// preparation (Text „Für 8b übernehmen“), coursePlan (Text „Vorjahresplan übernehmen“)
@Test("AK-57: Stichwort schlägt Text") func keywordBeatsBody() { #expect(HelpSearch.results(for: "AirPlay", in: c).first == .secondScreen) }
@Test("AK-57: Titel schlägt Text, klein geschrieben") func titleBeatsBody() { #expect(HelpSearch.results(for: "ferien", in: c).first == .nonTeachingDays) }
@Test("AK-57: ohne Umlaut") func foldsQuery() { #expect(Set(HelpSearch.results(for: "ubernehmen", in: c)) == [.preparation, .coursePlan]) }
@Test("Alle Wörter müssen passen") func allTermsRequired()          // "ferien airplay" → []
@Test("Wortanfang, nicht Wortmitte") func prefixOnly()               // "play" findet „AirPlay“ nicht
@Test("Leer, nur 1 Zeichen, unbekannt → keine Treffer") func emptyResults()   // "", "a", "xyz" → []
@Test("Gleichstand: Reihenfolge der Themen") func tieUsesTopicOrder()
```

- [ ] **Step 2: Rot belegen** – je Filter `HelpTextTests`, `HelpCatalogTests`, `HelpSearchTests`.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Grün belegen** – drei Filter, danach ohne Filter.
- [ ] **Step 5: Commit** – `git commit -m "core: add help catalog, validation and search"`

---

### Task 3: Rückmeldung als Werte – Entwurf, Geräteangaben, Mail, Adresse, Grenzen (FR-17.3, FR-17.4)

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Feedback/FeedbackKind.swift`, `FeedbackDraft.swift`, `NormalizedRect.swift`, `DeviceInfo.swift`, `FeedbackComposer.swift`, `FeedbackRecipient.swift`, `FeedbackAttachmentPolicy.swift`, `FeedbackRoute.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/Feedback/FeedbackDraftTests.swift`, `NormalizedRectTests.swift`, `DeviceInfoTests.swift`, `FeedbackComposerTests.swift`, `FeedbackRecipientTests.swift`, `FeedbackAttachmentPolicyTests.swift`, `FeedbackRouteTests.swift`

**Interfaces:**
- Consumes: `HelpTopic` (1); `DataLocation` (08); `Theme`, `BaseTone`, `AppearanceMode`, `ThemeAccent` (10)
- Produces:

```swift
public enum FeedbackKind: String, CaseIterable, Codable, Sendable { case idea, issue }
/// Rechteck in Bildanteilen, Ursprung oben links; Werte auf 0...1 begrenzt.
public struct NormalizedRect: Hashable, Codable, Sendable {
  public let x: Double, y: Double, width: Double, height: Double
  public init(x: Double, y: Double, width: Double, height: Double)          // begrenzt (clamp), Breite/Höhe ≥ 0
  /// Aus zwei Punkten in einer Ansicht der Größe `size`; nil, wenn schmaler/niedriger als 1 % der Ansicht.
  public static func spanning(from a: (x: Double, y: Double), to b: (x: Double, y: Double),
                              in size: (width: Double, height: Double)) -> NormalizedRect?
}
public enum FeedbackAttachmentOrigin: String, Codable, Sendable { case windowCapture, photoLibrary }
public struct FeedbackAttachment: Hashable, Codable, Sendable, Identifiable {
  public let id: UUID; public let origin: FeedbackAttachmentOrigin
  public let pixelWidth: Int; public let pixelHeight: Int
  public var redactions: [NormalizedRect]; public var hasMarkup: Bool
  public init(id: UUID, origin: FeedbackAttachmentOrigin, pixelWidth: Int, pixelHeight: Int,
              redactions: [NormalizedRect] = [], hasMarkup: Bool = false)
}
public struct FeedbackDraft: Hashable, Codable, Sendable {
  public var kind: FeedbackKind; public var text: String; public var topic: HelpTopic?
  public var includesDeviceInfo: Bool; public var attachments: [FeedbackAttachment]
  public init(kind: FeedbackKind, topic: HelpTopic?)    // text "", includesDeviceInfo false, attachments []
  public var canSend: Bool { get }                       // Text mit mindestens einem Nicht-Leerraum-Zeichen
}
public struct DeviceInfo: Hashable, Codable, Sendable {
  public var appVersion: String, build: String, systemName: String, systemVersion: String, modelIdentifier: String
  public var dataLocation: DataLocation; public var theme: Theme; public var isUnlocked: Bool; public var languageCode: String
  public init(…alle…)
  public var reportLines: [String] { get }
}
public struct FeedbackMessage: Hashable, Sendable { public let subject: String; public let body: String; public let attachmentFileNames: [String] }
public enum FeedbackComposer {
  public static let subjectLimit = 60
  public static func compose(_ draft: FeedbackDraft, deviceInfo: DeviceInfo?) -> FeedbackMessage
}
public enum FeedbackRecipient { public static func resolve(_ raw: String?) -> String? }
public enum FeedbackAttachmentPolicy {
  public static let maxCount = 5, maxPixelLength = 2048
  public static let jpegQuality = 0.85
  public static func remaining(currentCount: Int) -> Int                         // max(0, 5 − n)
  public static func scaledSize(width: Int, height: Int) -> (width: Int, height: Int)   // nie größer, Seitenverhältnis, gerundet, ≥ 1
  public static func fileName(index: Int) -> String                              // 0 → "Bildschirmfoto-1.jpg"
}
public enum FeedbackShareReason: Hashable, Sendable { case noRecipient, noMailAccount }
public enum FeedbackRoute: Hashable, Sendable {
  case mail(recipient: String), share(FeedbackShareReason)
  public static func choose(recipient: String?, canSendMail: Bool) -> FeedbackRoute   // fehlende Adresse zuerst
}
```

Wortlaut (Entscheidung 6, wörtlich):
- Betreff: `"Frontstage – Idee"` / `"Frontstage – Hinweis"`; mit Text `"Frontstage – Idee: <Kurz>"` – `<Kurz>` = erste nicht leere Zeile, getrimmt, Leerraum zu einem Leerzeichen; länger als 60 Zeichen → die ersten 60 Zeichen (getrimmt) + `"…"`.
- Text: getrimmter Text, Leerzeile, `"—"`, dann `"Art: Idee"`|`"Art: Hinweis"`, `"Hilfethema: <rawValue>"` (nur mit Thema), `"Bildschirmfotos: <n>"` (nur bei n > 0); mit Geräteangaben (nur wenn `includesDeviceInfo` und `deviceInfo != nil`) Leerzeile, `"Geräteangaben:"` und `reportLines`. Zeilen mit `\n`.
- `reportLines`: `"App: Frontstage <appVersion> (<build>)"`, `"System: <systemName> <systemVersion>"`, `"Gerät: <modelIdentifier>"`, `"Datenort: iCloud"`|`"Datenort: OneDrive"`, `"Erscheinungsbild: <Grundton>, <Akzent>, <Modus>"` mit Grundton `warm`|`System`|`kühl`|`Petrol`, Akzent `Standardakzent` oder `Akzent #RRGGBB`, Modus `wie das System`|`hell`|`dunkel`, `"Kauf: ja"`|`"Kauf: nein"`, `"Sprache: <languageCode>"`.
- `resolve`: getrimmt; `nil`, wenn leer, Leerraum enthält, `"$("` enthält, nicht genau ein `@`, Teil vor/nach `@` leer, Domain ohne Punkt, Domain (klein) gleich `example.com`/`example.org`/`example.net`/`localhost` oder endet auf `.example`/`.invalid`/`.local`/`.test`.

- [ ] **Step 1: Failing Tests schreiben** (Suite-Strukturen wie Dateinamen; Geräteangaben-Beispiel `DeviceInfo(appVersion: "0.1.0", build: "1", systemName: "iPadOS", systemVersion: "26.1", modelIdentifier: "iPad14,5", dataLocation: .iCloud, theme: .standard, isUnlocked: false, languageCode: "de")`)

```swift
// FeedbackDraftTests
@Test("Neu: Text leer, Geräteangaben aus, keine Bilder") func newDraftDefaults()
@Test("Review 5: nur Leerraum lässt sich nicht senden") func whitespaceOnlyCannotSend()   // " \n\t" → false, "x" → true
@Test("Entwurf übersteht JSON") func draftRoundTripsJSON() throws
// NormalizedRectTests
@Test("Zwei Punkte in beliebiger Richtung") func spansEitherDirection()   // (80,60)→(20,20) in 100×100 → x .2 y .2 w .6 h .4
@Test("Über den Rand begrenzt") func clampsToBounds()                    // (−10,−10)→(50,150) → x 0 y 0 w .5 h 1
@Test("Winzig → nil") func tinyIsNil()                                    // (10,10)→(10.5,40) in 100×100 → nil
// DeviceInfoTests
@Test("Zeilen wörtlich, ohne Namen") func reportLines() {
  #expect(info.reportLines == ["App: Frontstage 0.1.0 (1)", "System: iPadOS 26.1", "Gerät: iPad14,5", "Datenort: iCloud",
    "Erscheinungsbild: warm, Standardakzent, wie das System", "Kauf: nein", "Sprache: de"])
}
@Test("Eigener Akzent und dunkel") func customAccentLine()               // cool, #FFF3A0, dark → "Erscheinungsbild: kühl, Akzent #FFF3A0, dunkel"
// FeedbackComposerTests
@Test("AK-58: Betreff und Text") func composesIssue() {
  var d = FeedbackDraft(kind: .issue, topic: .board); d.text = "Tafel speichert nicht"
  let m = FeedbackComposer.compose(d, deviceInfo: info)
  #expect(m.subject == "Frontstage – Hinweis: Tafel speichert nicht")
  #expect(m.body == "Tafel speichert nicht\n\n—\nArt: Hinweis\nHilfethema: board")
}
@Test("Geräteangaben nur, wenn eingeschaltet") func deviceInfoOnlyWhenIncluded()
@Test("Review 5: erste nicht leere Zeile") func subjectUsesFirstNonEmptyLine()   // "\n\n  Idee   mit  Lücken \nmehr" → "Frontstage – Idee: Idee mit Lücken"
@Test("Review 5: nach 60 Zeichen gekürzt mit …") func subjectIsCutAt60WithEllipsis()
@Test("Anhänge: Namen und Zahl") func attachmentNames()   // 2 Anhänge → ["Bildschirmfoto-1.jpg","Bildschirmfoto-2.jpg"], Zeile "Bildschirmfotos: 2"
// FeedbackRecipientTests
@Test("Gültige Adresse getrimmt") func acceptsValid() { #expect(FeedbackRecipient.resolve("  hilfe@frontstage-rueckmeldung.de ") == "hilfe@frontstage-rueckmeldung.de") }
@Test("Review 3: Platzhalter abgelehnt") func rejectsPlaceholders()   // feedback@example.com, a@b.local, a@b.test, a@x.invalid, a@localhost → nil
@Test("Review 3: unaufgelöste Build-Einstellung abgelehnt") func rejectsUnresolvedBuildSetting()   // "$(FEEDBACK_EMAIL)", "", nil → nil
@Test("Formfehler abgelehnt") func rejectsMalformed()   // "a@@b.de", "@b.de", "a@", "a b@c.de", "a@bde" → nil
// FeedbackAttachmentPolicyTests
@Test("Höchstens fünf") func remaining() { #expect(FeedbackAttachmentPolicy.remaining(currentCount: 3) == 2); #expect(FeedbackAttachmentPolicy.remaining(currentCount: 7) == 0) }
@Test("Längste Kante 2048, nie vergrößern") func scales() {
  #expect(FeedbackAttachmentPolicy.scaledSize(width: 2732, height: 2048) == (2048, 1535))
  #expect(FeedbackAttachmentPolicy.scaledSize(width: 800, height: 600) == (800, 600))
}
// FeedbackRouteTests
@Test("Mit Adresse und Konto: Mail") func mailWhenPossible()
@Test("Review 3: fehlende Adresse vor fehlendem Konto") func noRecipientWinsOverMailAccount()   // (nil, false) → .share(.noRecipient)
@Test("Ohne Konto: Teilen") func shareWithoutMailAccount()
```

- [ ] **Step 2: Rot belegen** – je Filter (sieben Suites).
- [ ] **Step 3: Implementieren** (`FeedbackDraft`, `FeedbackAttachment` mit synthetisiertem `Codable`; `scaledSize` rundet mit `.rounded()`).
- [ ] **Step 4: Grün belegen** – alle Filter, danach ohne Filter.
- [ ] **Step 5: Commit** – `git commit -m "core: add feedback draft, device info, mail composition and limits"`

---

### Task 4: Hilfeartikel schreiben und gegen die echte Tabelle prüfen (FR-17, FR-17.2)

Design-Takt: keiner (Text; Wortlaut nach UI-15)

**Files:**
- Modify: `Frontstage/Resources/Localizable.xcstrings` – je Thema vier Schlüssel (`help.<topic>.title|summary|keywords|body`), alle mit `"extractionState" : "manual"`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/Help/HelpContentTests.swift`

**Interfaces:**
- Consumes: `HelpTopic`, `HelpCatalog.build(text:)`, `HelpSearch` (1, 2)
- Produces: 84 Textschlüssel; `HelpContentTests` liest `Frontstage/Resources/Localizable.xcstrings` relativ zu `#filePath` (fünfmal `deletingLastPathComponent()` → Repo-Wurzel) mit `JSONSerialization`, Wert unter `strings[key].localizations.de.stringUnit.value`.

Schreibregeln: du-Form, kurze Sätze, je Artikel 80–250 Wörter; Kurzfassung ein Satz; 3–8 Stichwörter (auch Wörter, die Lehrkräfte sagen: „AirPlay“, „Beamer“, „Sync“); Text in der Markdown-Teilmenge aus Task 1, Bedienwege mit den echten Bezeichnungen der Oberfläche (Werte aus `Localizable.xcstrings` nachschlagen, z. B. „Einrichten“, „Ordner freigeben“, „So verbinden“); kein `%` (Formatierung), kein `@`, keine echten Namen; Beispiele nur `7a`, `8a`, `8b`, `9c`, `6c`, Material „Arbeitsblatt Vokabeln“, „Unit 3 Präsentation“. Bezahlte Funktionen nennen den Kauf sachlich, ohne Werbung.

| Thema (`HelpTopic`) | Titel | Kernpunkte des Texts | Stichwörter (Auswahl) |
|---|---|---|---|
| `gettingStarted` | Erste Schritte | Stundenplan anlegen oder importieren; Datenort wählen; Ordner der Ablage freigeben; Material in Vorbereiten zuordnen; im Unterricht Heute öffnen; Fragezeichen überall | Start, Einstieg, Anfang |
| `dayView` | Heute | laufende Stunde ist gewählt, „Jetzt“; Material antippen öffnet; Tafel; Ausfall markieren, Material weiterreichen; Stand des Stundenplans; Leistungsnachweise als Hinweis | Tagesansicht, Stunde, Ausfall |
| `openingMaterial` | Material öffnen | ein Tipp öffnet in der zuständigen App; OneDrive mit Microsoft 365 = AutoSpeichern; „ohne AutoSpeichern öffnen“; Zustand „nicht verfügbar“, Bereithalten, Neu verknüpfen | PowerPoint, AutoSpeichern, Öffnen |
| `penNotes` | PDFs und Bilder mit Stift | Frontstage zeigt PDF und Bild selbst; Stiftnotizen gelten je Stunde; liegen neben dem Dokument (Ordner `.frontstage-notizen`, Notiz-PDF); Original bleibt unverändert | Stift, Notiz, PDF, Apple Pencil |
| `secondScreen` | Smartboard verbinden | Kontrollzentrum › Bildschirmsynchronisierung › Apple TV; Kabel ohne Handgriff; Smartboard zeigt nie die Tagesansicht; Leiste unten zeigt, was die Klasse sieht; Dunkel | AirPlay, Apple TV, Beamer, Kabel, Spiegeln |
| `classScreen` | Klassenbildschirm | zeigt Klasse, Fach, Uhrzeit, Thema, Bereitlegen, Hausaufgabe in den letzten fünf Minuten; Timer, Arbeitsform; Teil des Einmalkaufs | Timer, Arbeitsform, Hausaufgabe |
| `board` | Tafel | Seiten, Hintergründe; Kamera und Standbild; Vorlage aus Material oder Ablage; Abdecken; Tafelbild bleibt bei der Stunde, letztes Tafelbild; als PDF sichern; Teil des Einmalkaufs | Tafelbild, Kamera, Abdecken |
| `preparation` | Vorbereiten | Woche wählen; Material einer Stunde zuordnen (am Mac auch ziehen); Reihenfolge; Für 8b übernehmen; in die nächste Stunde; Vertretungsstunde; Thema aus dem Jahresplan übernehmen | Zuordnen, übernehmen, Woche |
| `coursePlan` | Jahresplan | je Fach, Jahrgang, Schuljahr; Wochen mit Thema, Tests, Klassenarbeiten, Notizen; „nicht zugeordnet“; frühere Jahre; Vorjahresplan übernehmen | Jahresplanung, Klassenarbeit, Vorjahr |
| `timetable` | Stundenplan | Einträge Tag, Stunde, Klasse, Fach; A/B-Wochen; von Hand oder importiert; Änderungen gelten ab sofort | A-Woche, B-Woche, Eintrag |
| `bellSchedule` | Zeitraster | Beginn und Ende je Stunde; nötig für „Jetzt“ und Klassenbildschirm; aus Schulmanager übernommen | Uhrzeit, Stundenzeiten, Pause |
| `nonTeachingDays` | Ferien und Feiertage | Zeiträume eintragen; Material bleibt erhalten und lässt sich verschieben; Wirkung auf den Jahresplan | Ferien, Feiertag, frei |
| `schoolYears` | Schuljahr | erster Schultag, Beginn 2. Halbjahr, letzter Schultag; Unterrichtswochen; Jahrgang bei Klassen ohne Ziffern (z. B. „EF“) | Halbjahr, Jahrgang, Schuljahr |
| `schulmanager` | Schulmanager | inoffizielle Anbindung ohne Gewähr; Abruf morgens und auf Knopfdruck; Vorschau vor dem Übernehmen; Zugangsdaten nur im Schlüsselbund; kostenlos | Import, Vertretung, Anmeldung |
| `storage` | Ablage und Ordner freigeben | Material bleibt in der Ablage, Zuordnen kopiert nie; Ordner freigeben je Gerät; Microsoft-Anmeldung für AutoSpeichern | OneDrive, iCloud Drive, Google Drive, Ordner |
| `dataLocation` | Datenort | iCloud oder OneDrive; was dort liegt; Wechsel nimmt alle Daten mit; OneDrive: Anmeldung, Ordner `Apps/Frontstage`; Schulkonto braucht evtl. Freigabe der Schul-IT | iCloud, OneDrive, Sync, Abgleich |
| `pairing` | Geräte koppeln | erstes Gerät zeigt QR-Code, zweites scannt; bei OneDrive dasselbe Konto; ohne Kamera andersherum; von Hand wählen geht immer | QR-Code, zweites Gerät, Mac |
| `appearance` | Erscheinungsbild | Grundton, Akzentfarbe mit Kontrastschutz, Hell/Dunkel; Standard kostenlos, Rest im Kauf; gilt auf allen Geräten | Farbe, Dunkelmodus, Theme |
| `purchase` | Kauf | kostenlos: Kern, Schulmanager, Hilfe, Rückmeldung; Einmalkauf: Klassenbildschirm, Timer, Arbeitsform, Tafel, Erscheinungsbild; kein Abo; gleiche Apple-ID; Käufe wiederherstellen | Preis, Einmalkauf, Abo |
| `privacy` | Wo deine Daten liegen | keine Server von Frontstage; Daten im Datenort, Material in der Ablage; Zugangsdaten nur im Schlüsselbund; Rückmeldung verschickst du selbst | Datenschutz, DSGVO, Server |
| `feedback` | Rückmeldung geben | Idee oder Hinweis; Bildschirmfoto, Zeichnen, Schwärzen; höchstens fünf Bilder; Geräteangaben freiwillig; ohne Mail-Konto Teilen oder Kopieren; Entwurf bleibt auf dem Gerät | Feedback, Fehler, Idee, Screenshot |

- [ ] **Step 1: Failing Test schreiben** (`@Suite("Help Content") struct HelpContentTests`)

```swift
@Test("Jedes Thema hat alle vier Texte, ohne Befund") func catalogIsComplete() throws {
  let (catalog, issues) = HelpCatalog.build(text: { try? xcstringValue($0) })
  #expect(issues.isEmpty); #expect(catalog.articles.count == HelpTopic.allCases.count)
}
@Test("Datenhygiene: nur Beispielklassen, kein @, kein %") func onlyNeutralExamples() throws
// alle help.*-Werte: jede Fundstelle von Regex \b\d{1,2}[a-z]\b (nach Kleinschreibung) ∈ {"7a","8a","8b","9c","6c"}; kein "@", kein "%"
@Test("AK-57 mit echten Texten") func searchMatchesAcceptance() throws {
  #expect(HelpSearch.results(for: "AirPlay", in: catalog).first == .secondScreen)
  #expect(HelpSearch.results(for: "ferien", in: catalog).first == .nonTeachingDays)
  #expect(Set(HelpSearch.results(for: "ubernehmen", in: catalog)).isSuperset(of: [.preparation, .coursePlan]))
  #expect(HelpSearch.results(for: "xyz", in: catalog).isEmpty)
}
@Test("Jeder Titel höchstens 30 Zeichen, Kurzfassung ein Satz") func titleAndSummaryShape() throws
```

- [ ] **Step 2: Rot belegen** – `scripts\swift-test.ps1 -Filter HelpContentTests` → `catalogIsComplete` scheitert mit `missingText`.
- [ ] **Step 3: Artikel schreiben** – 21 × 4 Werte in `Localizable.xcstrings` (Tabelle oben; Zeilenumbrüche als `\n` im JSON). Danach die Datei mit `python -c "import json,sys; json.load(open('Frontstage/Resources/Localizable.xcstrings', encoding='utf-8'))"` auf gültiges JSON prüfen.
- [ ] **Step 4: Grün belegen** – Filter, danach ohne Filter.
- [ ] **Step 5: Commit** – `git commit -m "content: write German help articles for all help topics"`

---

### Task 5: Build-Einstellung, Katalog aus dem Bundle, Empfangsadresse (ADR-0014)

Design-Takt: keiner

**Files:**
- Modify: `project.yml` – unter `settings.base`: `FEEDBACK_EMAIL: "feedback@example.com"  # Platzhalter; echte Adresse per CI-Secret (Q-42), nie im Repo`; in **beiden** `info.properties`: `FrontstageFeedbackEmail: $(FEEDBACK_EMAIL)`
- Modify: `.github/workflows/ci.yml` – an beide `xcodebuild`-Zeilen (Build macOS, App tests) ` FEEDBACK_EMAIL="${{ secrets.FEEDBACK_EMAIL }}"` anhängen
- Create: `Frontstage/Help/HelpLibrary.swift`, `Frontstage/Feedback/FeedbackConfiguration.swift`
- Test: `FrontstageTests/Help/HelpLibraryTests.swift`

**Interfaces:**
- Consumes: `HelpCatalog.build(text:)`, `HelpCatalogIssue` (2); `FeedbackRecipient.resolve` (3)
- Produces:

```swift
enum HelpLibrary {
  /// Einmal geladen; in der App ohne Befund (Test), Befunde gehen in den Log (`Logger`, Kategorie "Help").
  @MainActor static let shared: HelpCatalog
  static func load(bundle: Bundle) -> (catalog: HelpCatalog, issues: [HelpCatalogIssue])   // fehlender Schlüssel: Wert == Schlüssel → nil
}
enum FeedbackConfiguration {
  static func recipient(bundle: Bundle = .main) -> String?   // Info.plist "FrontstageFeedbackEmail" → FeedbackRecipient.resolve
}
```

Text aus dem Bundle über `bundle.localizedString(forKey: key, value: nil, table: nil)` (die kompilierte String-Tabelle), nicht `String(localized:)` mit dynamischem Schlüssel.

- [ ] **Step 1: Failing Tests schreiben**

```swift
@MainActor @Suite struct HelpLibraryTests {
  @Test("Alle 21 Artikel laden aus dem App-Bundle, ohne Befund") func everyTopicLoadsFromBundle() {
    let (catalog, issues) = HelpLibrary.load(bundle: .main)
    #expect(issues.isEmpty); #expect(catalog.articles.count == 21)
  }
  @Test("Adresse ist nil oder gültig – nie ein Platzhalter") func recipientIsNilOrResolved() {
    if let r = FeedbackConfiguration.recipient() { #expect(FeedbackRecipient.resolve(r) == r) }
  }
}
```

- [ ] **Step 2: Implementieren.**
- [ ] **Step 3: Syntax prüfen** (`scripts\swift-parse.ps1`), Diff: keine echte Adresse; `project.yml` gültiges YAML (`python -c "import yaml…"` falls vorhanden, sonst Sichtprüfung der Einrückung).
- [ ] **Step 4: Commit** – `git commit -m "app: load help catalog from bundle and feedback address from build settings"`

---

### Task 6: Entwurf auf dem Gerät, Bilder, Aufnahme, Geräteangaben (FR-17.3, FR-17.4)

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Feedback/FeedbackDraftStore.swift`, `Frontstage/Feedback/FeedbackImageEncoder.swift`, `Frontstage/Feedback/WindowCapture.swift`, `Frontstage/Feedback/DeviceInfoCollector.swift`
- Test: `FrontstageTests/Feedback/FeedbackDraftStoreTests.swift`, `FeedbackImageEncoderTests.swift`, `DeviceInfoCollectorTests.swift`

**Interfaces:**
- Consumes: `FeedbackDraft`, `FeedbackAttachment`, `NormalizedRect`, `FeedbackAttachmentPolicy`, `DeviceInfo` (3); `DrawingGeometry`, `PageSize` (06); `DataLocation`, `Theme`
- Produces:

```swift
@MainActor final class FeedbackDraftStore {
  init(directory: URL)                         // legt den Ordner an, setzt isExcludedFromBackup
  static let shared: FeedbackDraftStore        // Application Support/Feedback
  func load() -> FeedbackDraft?                // fehlt oder unlesbar → nil (Entscheidung 10)
  func save(_ draft: FeedbackDraft) throws     // atomar schreiben
  func storeImage(_ jpeg: Data, for id: UUID) throws
  func imageData(for id: UUID) -> Data?
  func storeMarkup(_ data: Data?, for id: UUID) throws   // nil löscht
  func markupData(for id: UUID) -> Data?
  func removeAttachment(_ id: UUID) throws
  func discard() throws                        // draft.json und alle Bilder/Zeichnungen
}
enum FeedbackImageEncoder {
  /// Verkleinert nach `FeedbackAttachmentPolicy.scaledSize` und kodiert JPEG (0,85). nil bei unlesbarem Bild.
  static func preparedJPEG(from image: CGImage) -> Data?
  static func preparedJPEG(fromImageData data: Data) -> Data?        // Mediathek (HEIC/PNG/JPEG über ImageIO, Ausrichtung angewendet)
  /// Bild, darauf die Zeichnung (Bildpixel-Raum), darüber deckend schwarze Schwärzungen → JPEG.
  static func flattened(imageData: Data, markup: PKDrawing?, redactions: [NormalizedRect]) -> Data?
}
@MainActor enum WindowCapture { static func captureMainWindow() -> CGImage? }   // Entscheidung 5; nil, wenn kein Fenster
@MainActor enum DeviceInfoCollector {
  static func collect(dataLocation: DataLocation, theme: Theme, isUnlocked: Bool) -> DeviceInfo
  static func modelIdentifier() -> String      // sysctlbyname "hw.machine" (iOS) / "hw.model" (macOS); Simulator: "SIMULATOR_MODEL_IDENTIFIER" aus der Umgebung
}
```

Aufnahme: iPad `UIApplication.shared.connectedScenes` → `UIWindowScene` mit `session.role == .windowApplication` und `activationState == .foregroundActive` → `keyWindow` → `UIGraphicsImageRenderer(bounds: window.bounds)` mit `drawHierarchy(in: window.bounds, afterScreenUpdates: true)` → `.cgImage`. Mac: `NSApp.mainWindow ?? NSApp.keyWindow` (ohne Blätter: `window.sheetParent == nil`), `contentView.bitmapImageRepForCachingDisplay(in: bounds)` + `cacheDisplay(in:to:)` → `cgImage`. Zusammensetzen mit `CGContext` (RGB, 8 Bit) in Pixelgröße; Zeichnung: iPad `markup.image(from: CGRect(origin: .zero, size: pixelSize), scale: 1)`, Mac dasselbe als `NSImage` → `cgImage(forProposedRect:context:hints:)`; Schwärzung `y_cg = height − (y + h) · height`.

- [ ] **Step 1: Failing Tests schreiben** (Bilder in Tests synthetisch aus `CGContext`, siehe `FrontstageTests/TestImages.swift`; Ordner je Test `FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)`)

```swift
@MainActor @Suite struct FeedbackDraftStoreTests {
  @Test("Review 4: Entwurf samt Bild und Zeichnung übersteht Neuladen") func roundTripsDraftWithAttachments() throws   // zweites Store-Objekt auf gleichem Ordner
  @Test("Review 4: kaputte draft.json → kein Entwurf, kein Absturz") func corruptDraftLoadsAsNil() throws
  @Test("Review 4: Verwerfen löscht alle Dateien") func discardRemovesAllFiles() throws   // Ordner danach ohne .jpg/.drawing/.json
  @Test("Anhang entfernen löscht Bild und Zeichnung") func removeAttachmentDeletesFiles() throws
  @Test("Nicht gesichert") func directoryExcludedFromBackup() throws   // resourceValues.isExcludedFromBackup == true
}
@MainActor @Suite struct FeedbackImageEncoderTests {
  @Test("Längste Kante 2048") func downscalesTo2048()   // 2732×2048 weiß → JPEG 2048×1535 (CGImageSource lesen)
  @Test("Review 2: Schwärzung deckt vollständig") func redactionCoversAreaCompletely()
  // 200×200 weiß, Schwärzung (0.25, 0.25, 0.5, 0.5) → Pixel (100,100) alle Kanäle ≤ 8; Pixel (20,20) alle ≥ 247
  @Test("Review 2: Schwärzung liegt über der Zeichnung") func redactionDrawnAboveMarkup()   // roter Strich quer durch, Pixel in der Schwärzung ≤ 8
  @Test("Review 2: Lage stimmt nach Verkleinern") func downscaleKeepsRedactionPosition()   // 4096×2048 → 2048×1024, Mitte schwarz, Ecke weiß
  @Test("Unlesbare Daten → nil") func invalidDataIsNil()
}
@MainActor @Suite struct DeviceInfoCollectorTests {
  @Test("Version und Build aus dem Bundle, Modellkennung nicht leer") func collectsFromBundle()
  @Test("Keine Gerätenamen in den Zeilen") func neverContainsDeviceName() {
    // reportLines enthalten weder UIDevice.current.name (iOS) noch Host.current().localizedName (Mac), außer der Name ist leer
  }
}
```

- [ ] **Step 2: Implementieren.**
- [ ] **Step 3: Syntax prüfen**, Diff: kein Zugriff auf Gerätenamen; Aufnahme nur Hauptszene; PencilKit-Import plattformübergreifend nur für `PKDrawing`.
- [ ] **Step 4: Commit** – `git commit -m "app: feedback draft storage, image encoding, window capture and device info"`

---

### Task 7: Zeichnen und Schwärzen (FR-17.4)

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/Feedback/Markup/MarkupEditorModel.swift`, `MarkupEditorView.swift`, `MarkupCanvas.swift` (`#if os(iOS)`), `MacMarkupCanvas.swift` (`#if os(macOS)`), `RedactionOverlay.swift`
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/Feedback/MarkupEditorModelTests.swift`

**Interfaces:**
- Consumes: `NormalizedRect` (3); `FeedbackImageEncoder` (6); `DrawingGeometry`, `PageSize` (06)
- Produces:

```swift
enum MarkupMode: Hashable { case draw, redact }
@MainActor @Observable final class MarkupEditorModel {
  init(pixelSize: CGSize, drawing: PKDrawing, redactions: [NormalizedRect])
  let pixelSize: CGSize
  private(set) var drawing: PKDrawing          // Bildpixel-Raum
  private(set) var redactions: [NormalizedRect]
  var mode: MarkupMode                          // Vorgabe .draw
  var canUndo: Bool { get }
  func replaceDrawing(_ drawing: PKDrawing)     // Rückmeldung der Zeichenfläche; legt Rückgängig-Schritt an
  func addStroke(_ stroke: PKStroke)            // Mac
  func addRedaction(_ rect: NormalizedRect)
  func undo()                                   // letzter Schritt, gleich ob Strich oder Schwärzung
  func clear()                                  // alles weg, als ein Schritt rückgängig machbar
}
struct MarkupEditorView: View {
  init(imageData: Data, model: MarkupEditorModel, onDone: @escaping (MarkupEditorModel) -> Void)
}
```

Ansicht: Bild `aspectRatio(.fit)` mit Zeichenfläche und `RedactionOverlay` genau darüber (gleiche Größe); Leiste: `Picker` (`.segmented`) „Zeichnen“ / „Schwärzen“, „Rückgängig“ (`arrow.uturn.backward`), „Alles löschen“ (mit Rückfrage), „Fertig“. Im Modus Schwärzen nimmt nur `RedactionOverlay` Gesten an (Ziehen zeigt ein Rechteck mit gestricheltem Rand, Loslassen → `NormalizedRect.spanning` → `addRedaction`); im Modus Zeichnen ist das Overlay `allowsHitTesting(false)`. iPad: `MarkupCanvas` (`UIViewRepresentable`, `PKCanvasView`, transparent, `drawingPolicy = .anyInput`, `PKToolPicker` sichtbar nur im Zeichnen-Modus, Umrechnung mit `DrawingGeometry` wie `PageCanvasView`). Mac: `MacMarkupCanvas` – `Canvas` zeigt `drawing`, `DragGesture(minimumDistance: 0)` sammelt Punkte; Loslassen → `PKStroke(ink: PKInk(.pen, color: .systemRed), path: PKStrokePath(controlPoints: …, creationDate: .now))` mit `PKStrokePoint(location:timeOffset:size: CGSize(width: 6, height: 6), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)` in Bildpixeln; Werkzeugwahl „Stift“ (rot) / „Marker“ (`.marker`, gelb). Hinweiszeile unter dem Bild: `feedback.markup.redactHint`. VoiceOver: Bild mit Label „Bildschirmfoto“, Leiste vollständig beschriftet.

Texte: `feedback.markup.title` Bild bearbeiten · `feedback.markup.draw` Zeichnen · `feedback.markup.redact` Schwärzen · `feedback.markup.undo` Rückgängig · `feedback.markup.clear` Alles löschen · `feedback.markup.clear.confirm` Zeichnung und Schwärzungen löschen? · `feedback.markup.done` Fertig · `feedback.markup.pen` Stift · `feedback.markup.marker` Marker · `feedback.markup.redactHint` Zieh ein Rechteck über Namen und Dateinamen. Geschwärztes ist im gesendeten Bild ganz verdeckt.

- [ ] **Step 1: Failing Tests schreiben**

```swift
@MainActor @Suite struct MarkupEditorModelTests {
  @Test("Schwärzung hinzufügen und rückgängig") func undoRemovesRedaction()
  @Test("Strich rückgängig stellt die vorige Zeichnung her") func undoRestoresDrawing()   // addStroke, undo → drawing.strokes.isEmpty
  @Test("Gemischte Reihenfolge: Rückgängig nimmt das Letzte") func undoIsChronological()
  @Test("Alles löschen ist ein Schritt") func clearIsUndoable()
  @Test("Ohne Schritte nichts rückgängig") func cannotUndoInitially()
}
```

- [ ] **Step 2: Skill laden** – `apple-design`; prüfen gegen HIG „Drawing“, „Toolbars“, „Segmented controls“, „Undo and redo“.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Syntax prüfen**, Diff: `PKCanvasView`/`PKToolPicker` nur in `#if os(iOS)`; Schwärzungen nie über PencilKit.
- [ ] **Step 5: Commit** – `git commit -m "ui: markup editor with drawing and redaction"`

---

### Task 8: Rückmeldung schreiben und senden (FR-17.3, FR-17.4, AK-58, AK-59)

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/Feedback/FeedbackModel.swift`, `FeedbackSession.swift`, `FeedbackView.swift`, `AttachmentStrip.swift`, `MailComposeView.swift` (`#if os(iOS)`), `MacMailComposer.swift` (`#if os(macOS)`)
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/Feedback/FeedbackModelTests.swift`, `FrontstageTests/Feedback/FeedbackStarterTests.swift`

**Interfaces:**
- Consumes: Task 3 (alle Feedback-Werte), Task 5 (`FeedbackConfiguration`), Task 6 (`FeedbackDraftStore`, `FeedbackImageEncoder`, `WindowCapture`, `DeviceInfoCollector`), Task 7 (`MarkupEditorView`, `MarkupEditorModel`)
- Produces:

```swift
/// Was eine Rückmeldung von außen braucht; `RootView` setzt es (Task 10), die Vorgabe taugt für Vorschauen.
struct FeedbackContext {
  var store: FeedbackDraftStore
  var recipient: String?
  var canSendMail: @MainActor () -> Bool        // iPad MFMailComposeViewController.canSendMail(); Mac NSSharingService(named: .composeEmail)?.canPerform(withItems: ["x"]) == true
  var deviceInfo: @MainActor () -> DeviceInfo
  var capture: @MainActor () -> CGImage?        // WindowCapture.captureMainWindow
  @MainActor static var standard: FeedbackContext { get }
}
extension EnvironmentValues { @Entry var feedbackContext: FeedbackContext = .standard }   // @MainActor-Vorgabe wie showSetup

@MainActor @Observable final class FeedbackModel {
  init(draft: FeedbackDraft, context: FeedbackContext)
  private(set) var draft: FeedbackDraft
  var route: FeedbackRoute { get }                   // FeedbackRoute.choose(recipient:canSendMail:)
  var message: FeedbackMessage { get }               // FeedbackComposer.compose(draft, deviceInfo: draft.includesDeviceInfo ? context.deviceInfo() : nil)
  var deviceInfoPreview: [String] { get }            // reportLines, auch wenn aus (zum Zeigen)
  var remainingSlots: Int { get }
  private(set) var saveFailed: Bool
  func setKind(_ kind: FeedbackKind); func setText(_ text: String); func setIncludesDeviceInfo(_ on: Bool)
  func addCapturedWindow(_ image: CGImage)           // vorn, wenn Entwurf leer an Bildern, sonst hinten; über der Grenze verworfen
  func addPhotos(_ datas: [Data])                    // bis remainingSlots, Rest verworfen
  func removeAttachment(_ id: UUID)
  func imageData(for id: UUID) -> Data?; func markup(for id: UUID) -> PKDrawing?
  func updateMarkup(for id: UUID, drawing: PKDrawing, redactions: [NormalizedRect])
  func flattenedAttachments() -> [(fileName: String, data: Data)]   // Reihenfolge = draft.attachments
  func copyText() -> String                          // "Betreff: …\n\n" + body
  func shareFiles() throws -> [URL]                  // flattenedAttachments in tmp/Feedback-<uuid>/Bildschirmfoto-n.jpg
  func didSend()                                     // store.discard(), Entwurf neu (gleiche Art/Thema leer)
  func discard()
  func persist()                                     // store.save(draft); Fehler → saveFailed = true
}
struct FeedbackSession: Identifiable { let id: UUID; let model: FeedbackModel }
@MainActor enum FeedbackStarter {
  /// Reihenfolge fest: zuerst `context.capture()`, dann Entwurf laden oder anlegen, dann Modell (Review 1).
  static func start(kind: FeedbackKind, topic: HelpTopic?, context: FeedbackContext) -> FeedbackSession
}
extension View { func feedbackSheet(_ session: Binding<FeedbackSession?>) -> some View }   // .sheet(item:) mit FeedbackView, .fontDesign(.rounded)
```

Ansicht `FeedbackView` (`NavigationStack` + `Form`, `themedBackground()`):
- Section: `Picker` (`.segmented`) „Idee“ / „Hinweis“.
- Section: `TextEditor` (Mindesthöhe 160 pt, skaliert), Platzhalter je Art; Fußtext bei `topic`: `feedback.aboutTopic` mit Titel aus `HelpLibrary.shared`.
- Section „Bildschirmfotos (n von 5)“: `AttachmentStrip` – Vorschaubilder (Höhe 120 pt, Ecken nach UI-10 „Kacheln 16“), Tipp öffnet `MarkupEditorView` (iPad `fullScreenCover`, Mac `sheet`), Kontextmenü und VoiceOver-Aktion „Entfernen“; `PhotosPicker(selection:maxSelectionCount: remainingSlots, matching: .images)` „Foto hinzufügen“, ausgeblendet bei 0; Fußtext `feedback.attachments.privacyHint`.
- Section: `Toggle` „Geräteangaben anhängen“ (aus), darunter `DisclosureGroup` „Was wird angehängt?“ mit `deviceInfoPreview` in `.monospaced()`-freier Systemschrift, Größe `detailMeta`.
- Leiste: `cancellationAction` „Schließen“ (Entwurf bleibt); `confirmationAction` je `route`: `.mail` → „Senden“ (deaktiviert ohne `draft.canSend`) öffnet `MailComposeView`/`MacMailComposer`; `.share` → `ShareLink(items: shareFiles(), subject: Text(message.subject), message: Text(message.body))` „Teilen“ (ohne Bilder `ShareLink(item: copyText())`); Menü „Mehr“ mit „Text kopieren“ (`UIPasteboard`/`NSPasteboard`) und „Entwurf verwerfen“ (`role: .destructive`, Rückfrage).
- Bei `.share(.noRecipient)` Fußzeile `feedback.share.noRecipient`, bei `.share(.noMailAccount)` `feedback.share.noMailAccount`.
- Nach `.sent` bzw. Mac-Übergabe: `didSend()`, Blatt schließen, Hinweis `feedback.sent` als `AccessibilityNotification.Announcement` und kurzer Alert. `.failed` → Alert `feedback.sendFailed`.
- Speichern: `.task(id: model.draft) { try? await Task.sleep(for: .milliseconds(400)); model.persist() }`; Bild-Änderungen (`add…`, `remove…`, `updateMarkup`) speichern sofort.

`MailComposeView`: `UIViewControllerRepresentable` um `MFMailComposeViewController` (`setToRecipients`, `setSubject`, `setMessageBody(isHTML: false)`, `addAttachmentData(_:mimeType: "image/jpeg", fileName:)`), Delegate meldet `MFMailComposeResult`. `MacMailComposer`: `NSSharingService(named: .composeEmail)` mit `recipients`, `subject`, `perform(withItems: [body] + fileURLs)`, Delegate `didShareItems` / `didFailToShareItems`.

Texte: `feedback.title` Rückmeldung · `feedback.kind.idea` Idee · `feedback.kind.issue` Hinweis · `feedback.text.placeholder.idea` Was wünschst du dir? · `feedback.text.placeholder.issue` Was ist passiert, und was hast du erwartet? · `feedback.aboutTopic %@` Zu: %@ · `feedback.attachments.title %lld` Bildschirmfotos (%lld von 5) · `feedback.attachments.add` Foto hinzufügen · `feedback.attachments.remove` Entfernen · `feedback.attachments.label %lld` Bildschirmfoto %lld · `feedback.attachments.labelMarked %lld` Bildschirmfoto %lld, bearbeitet · `feedback.attachments.privacyHint` Bildschirmfotos können Klassen-, Datei- und Personennamen zeigen. Schwärze sie vor dem Senden. · `feedback.deviceInfo` Geräteangaben anhängen · `feedback.deviceInfo.what` Was wird angehängt? · `feedback.deviceInfo.note` Ohne Gerätenamen und ohne Inhalte. · `feedback.close` Schließen · `feedback.send` Senden · `feedback.share` Teilen · `feedback.more` Mehr · `feedback.copy` Text kopieren · `feedback.copied` Text kopiert · `feedback.discard` Entwurf verwerfen · `feedback.discard.confirm` Entwurf und Bilder löschen? · `feedback.share.noRecipient` In dieser Fassung ist keine Empfangsadresse hinterlegt. Teile die Rückmeldung oder kopiere den Text. · `feedback.share.noMailAccount` Auf diesem Gerät ist kein Mail-Konto eingerichtet. Teile die Rückmeldung über eine andere App oder kopiere den Text. · `feedback.sent` Danke! Deine Rückmeldung ist unterwegs. · `feedback.sendFailed` Nicht gesendet. Dein Entwurf bleibt erhalten. · `feedback.saveFailed` Entwurf nicht gespeichert.

- [ ] **Step 1: Failing Tests schreiben** (Kontext mit Temp-Ordner, `recipient: "hilfe@frontstage-rueckmeldung.de"`, `canSendMail: { true }`, `capture:` liefert ein 400×300-Testbild)

```swift
@MainActor @Suite struct FeedbackModelTests {
  @Test("AK-59: Aufnahme ist erstes Bild, entfernbar") func startsWithCapturedWindowFirst()
  @Test("AK-59: höchstens fünf Bilder") func limitsToFiveAttachments()   // Aufnahme + addPhotos(6) → 5, remainingSlots 0
  @Test("AK-58: Entwurf übersteht neues Modell") func draftSurvivesReload() async throws
  @Test("Review 4: Senden leert Entwurf und Dateien") func didSendClearsDraftAndFiles()
  @Test("Review 3: ohne Adresse Teilen") func routeWithoutRecipientIsShare()   // recipient nil → .share(.noRecipient)
  @Test("Geräteangaben voreingestellt aus und nicht im Text") func deviceInfoOffByDefault()
  @Test("Text kopieren enthält Betreff und Text") func copyTextHasSubjectAndBody()
  @Test("Zusammengesetzte Anhänge in Reihenfolge mit Dateinamen") func flattenedAttachmentsAreOrdered()
}
@MainActor @Suite struct FeedbackStarterTests {
  @Test("Review 1: Aufnahme vor der Sitzung") func captureRunsBeforeSessionExists()
  // capture-Closure protokolliert; Session-Modell hat danach genau ein .windowCapture-Bild
  @Test("Bestehender Entwurf: neue Aufnahme hinten, Art bleibt") func existingDraftKeepsKindAndAppends()
  @Test("Aufnahme scheitert → Rückmeldung ohne Bild") func nilCaptureStartsWithoutImage()
}
```

- [ ] **Step 2: Skill laden** – `apple-design`; HIG „Sheets“, „Text views“, „Photo editing“ (Auswahl), „Activity views“, „Privacy“.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Syntax prüfen**, Diff: MessageUI nur `#if os(iOS)`; keine Adresse im Code; `FeedbackView` kennt keine Plattformdetails außer über `MailComposeView`/`MacMailComposer`.
- [ ] **Step 5: Commit** – `git commit -m "ui: feedback sheet with mail, share, copy and attachments"`

---

### Task 9: Hilfe-Oberfläche – Knopf, Artikel, Hilfecenter (FR-17.1, FR-17.2, AK-55–AK-57)

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/Help/HelpButton.swift`, `HelpSheet.swift`, `HelpArticleView.swift`, `HelpBlockView.swift`, `HelpCenterView.swift`, `HelpCenterModel.swift`
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/Help/HelpCenterModelTests.swift`

**Interfaces:**
- Consumes: `HelpLibrary.shared` (5); `HelpTopic`, `HelpGroup`, `HelpSearch`, `HelpArticle`, `HelpBlock` (1, 2); `FeedbackStarter`, `feedbackSheet(_:)`, `EnvironmentValues.feedbackContext` (8)
- Produces:

```swift
/// Hilfeknopf (Glossar): Fragezeichen; zeigt sein Blatt selbst (Entscheidung 4) und startet von dort eine Rückmeldung (Entscheidung 5).
struct HelpButton: View { init(topic: HelpTopic) }
enum HelpSheetRoot: Hashable { case center, article(HelpTopic) }
/// `NavigationStack` mit `navigationDestination(for: HelpTopic.self)`, „Fertig“; `onFeedback`: Artikel → (`.issue`, gezeigtes Thema), Center → (gewählte Art, nil).
struct HelpSheet: View { init(root: HelpSheetRoot, onFeedback: @escaping (FeedbackKind, HelpTopic?) -> Void) }
struct HelpArticleView: View { init(article: HelpArticle, onFeedback: @escaping (HelpTopic) -> Void) }   // HelpSheet reicht (.issue, topic) weiter
struct HelpBlockView: View { let block: HelpBlock }
/// Hilfecenter (Glossar). Ohne eigenen `NavigationStack` – steht in Einrichten (push) und in `HelpSheet`.
struct HelpCenterView: View { init(onFeedback: @escaping (FeedbackKind) -> Void) }
@MainActor @Observable final class HelpCenterModel {
  init(catalog: HelpCatalog)
  var query: String
  var isSearching: Bool { get }                    // getrimmte Anfrage nicht leer
  var results: [HelpArticle] { get }               // HelpSearch, in Rangfolge
  var sections: [(group: HelpGroup, articles: [HelpArticle])] { get }   // alle Gruppen in allCases-Reihenfolge
}
```

`HelpButton`: `Button { showsArticle = true } label: { Label("help.button", systemImage: "questionmark.circle") }`, `.labelStyle(.iconOnly)`, `.accessibilityLabel(Text("help.button.label \(title)"))`, `.help(Text("help.button.label \(title)"))`. `.sheet(isPresented: $showsArticle, onDismiss: startPendingFeedback) { HelpSheet(root: .article(topic)) { kind, shown in pending = (kind, shown ?? topic); showsArticle = false } }`; die Rückmeldung hängt an einem `Color.clear`-Hintergrund des Knopfs (`.background { Color.clear.feedbackSheet($session) }`), damit nicht zwei Blätter am selben View hängen. `startPendingFeedback` ruft `FeedbackStarter.start(kind: pending.kind, topic: pending.topic, context: feedbackContext)` und leert `pending`.

`HelpArticleView` (`ScrollView`, `themedBackground()`, `.fontDesign(.rounded)`): Titel als `navigationTitle`, Kurzfassung in `scaledFont(.topic)`, Blöcke über `HelpBlockView` (UI-6 „nur über die Größe“, kein Fettdruck als Hierarchie: Zwischentitel `scaledFont(.topic)`, Absatz/Liste/Schritte in `.body`-Systemgröße, Hinweis als Zeile mit Symbol `info.circle` in Textfarbe), Abschnitt „Verwandte Themen“ (`NavigationLink(value: HelpTopic)`), unten Kapselknopf „Rückmeldung geben“ (`CapsuleActionButtonStyle`) und Link „Alle Hilfethemen“ (`NavigationLink(value: HelpSheetRoot.center)` – nur in `HelpSheet`, nicht wenn der Artikel aus dem Center kam). Inline-Markdown je Block über `AttributedString(markdown:options:)` mit `.inlineOnlyPreservingWhitespace`; schlägt das fehl, Rohtext.

`HelpCenterView` (`List`, `.searchable(text:prompt: "help.center.search")`): ohne Suche Sections je `HelpGroup` (Titel `help.group.<rawValue>`) mit Zeilen (Titel, darunter Kurzfassung in `scaledFont(.detailMeta)`); mit Suche flache Trefferliste, leer → `ContentUnavailableView.search(text:)`. Letzte Section „Rückmeldung“: Kapselknöpfe „Idee senden“ / „Hinweis senden“ → `onFeedback(.idea / .issue)`. (Kurz-Tipps-Zeilen ergänzt Task 11.)

Texte: `help.button` Hilfe · `help.button.label %@` Hilfe zu %@ · `help.done` Fertig · `help.related` Verwandte Themen · `help.giveFeedback` Rückmeldung geben · `help.allTopics` Alle Hilfethemen · `help.center.title` Hilfe und Rückmeldung · `help.center.search` Hilfe durchsuchen · `help.group.start` Erste Schritte · `help.group.teaching` Im Unterricht · `help.group.classroom` Smartboard und Tafel · `help.group.planning` Vorbereiten und Planen · `help.group.setup` Einrichten · `help.group.about` Kauf, Datenschutz, Rückmeldung · `help.center.feedback` Rückmeldung · `help.center.sendIdea` Idee senden · `help.center.sendIssue` Hinweis senden · `help.center.feedbackNote` Deine Rückmeldung geht als E-Mail aus deinem Mail-Programm an die Entwickler.

- [ ] **Step 1: Failing Tests schreiben**

```swift
@MainActor @Suite struct HelpCenterModelTests {
  @Test("Ohne Suche alle Gruppen in Reihenfolge, 21 Artikel") func sectionsCoverAllTopics()
  @Test("AK-57: AirPlay → Smartboard verbinden zuerst") func searchRanksRealContent() {
    let m = HelpCenterModel(catalog: HelpLibrary.shared); m.query = "AirPlay"
    #expect(m.results.first?.topic == .secondScreen)
  }
  @Test("Nur Leerraum gilt nicht als Suche") func whitespaceIsNotSearching()
}
```

- [ ] **Step 2: Skill laden** – `apple-design`; HIG „Help“, „Searching“, „Sheets“, „Lists and tables“, „Accessibility“ (VoiceOver, Dynamic Type).
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Syntax prüfen**, Diff: kein `PaidGate`; keine Schriftgewichte als Hierarchie (UI-6); Texte nur aus der Tabelle.
- [ ] **Step 5: Commit** – `git commit -m "ui: help button, article sheet and searchable help center"`

---

### Task 10: Hilfeknöpfe einsetzen, Menü „Hilfe“, Einrichten (FR-17.1, FR-17.2, AK-56, AK-57)

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/Help/SupportCoordinator.swift`, `Frontstage/Help/HelpCommands.swift`
- Modify: `Frontstage/App/FrontstageApp.swift` – an `WindowGroup` `.commands { HelpCommands(support: .shared) }`
- Modify: `Frontstage/App/RootView.swift` – `.environment(\.feedbackContext, …)` (Store `.shared`, `recipient: FeedbackConfiguration.recipient()`, Geräteangaben aus `dataLocation.location`, `(try? dataLocation.store.theme()) ?? .standard`, `ClassroomServices.shared.unlock.isUnlocked`), `.onAppear { SupportCoordinator.shared.context = <derselbe Kontext> }`, `.sheet(isPresented: $support.showsHelpCenter) { HelpSheet(root: .center) { … } }`, `.feedbackSheet($support.feedbackSession)` an einem eigenen Hintergrund-View
- Modify (Hilfeknopf, Thema):
  - `Frontstage/UI/DayView/DayView.swift` – in `toolbar` eigenes `ToolbarItem { HelpButton(topic: .dayView) }` → `dayView`
  - `Frontstage/UI/Preparation/PreparationView.swift` – `toolbar` → `preparation`
  - `Frontstage/UI/CoursePlan/CoursePlanView.swift` – Toolbar der Seitenleiste in `split` → `coursePlan`
  - `Frontstage/UI/Setup/SetupView.swift` – `.toolbar { ToolbarItem { HelpButton(topic: .gettingStarted) } }` am `Form`; neue letzte Section mit `NavigationLink("help.center.title") { HelpCenterView { kind in … } }` (startet `FeedbackStarter` und zeigt `feedbackSheet` an der Setup-Ansicht); Kauf-Section-Header mit `HStack { Text("setup.purchase.title"); Spacer(); HelpButton(topic: .purchase) }`
  - `Frontstage/UI/Setup/DataLocationSettingsView.swift` – Section-Header → `dataLocation`
  - `Frontstage/UI/Setup/Pairing/PairingSheet.swift` – Toolbar → `pairing`
  - `Frontstage/UI/Setup/StorageSettingsView.swift` – `.toolbar` neu an der Hauptansicht (die vorhandene `.toolbar` gehört zum Blatt „Ordner hinzufügen“) → `storage`
  - `Frontstage/UI/Setup/TimetableSourceSettingsView.swift` – `.toolbar` neu → `schulmanager`
  - `Frontstage/UI/Setup/TimetableEditorView.swift` (vorhandene `.toolbar`) → `timetable`; `BellScheduleEditorView.swift` (`.toolbar` neu) → `bellSchedule`; `NonTeachingPeriodsView.swift` (vorhandene `.toolbar`) → `nonTeachingDays`; `SchoolYearSettingsView.swift` (vorhandene `.toolbar`) → `schoolYears`; `AppearanceSettingsView.swift` (`.toolbar` neu) → `appearance`
  - `Frontstage/Board/BoardScreen.swift` – vorhandene `.toolbar` im `NavigationStack` → `board` (Datei teils `#if os(iOS)`)
  - `Frontstage/Viewer/ViewerView.swift` – `toolbar` → `penNotes`
  - `Frontstage/SecondScreen/ConnectHowToView.swift` – vorhandene `.toolbar` → `secondScreen` (Datei nur iOS)
  - `Frontstage/ClassScreen/ClassroomControls.swift` – neben den Bedienelementen → `classScreen` (Datei nur iOS; am Mac sind beide Themen über das Hilfecenter erreichbar)
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/Help/SupportCoordinatorTests.swift`

**Interfaces:**
- Consumes: Task 8 (`FeedbackContext`, `FeedbackStarter`, `FeedbackSession`, `feedbackSheet`), Task 9 (`HelpButton`, `HelpSheet`, `HelpCenterView`)
- Produces:

```swift
@MainActor @Observable final class SupportCoordinator {
  static let shared: SupportCoordinator
  init()
  var context: FeedbackContext                 // Vorgabe .standard; RootView setzt den echten
  var showsHelpCenter: Bool
  var feedbackSession: FeedbackSession?
  func showHelpCenter()                         // setzt showsHelpCenter, wenn keine Rückmeldung offen
  func startFeedback(kind: FeedbackKind = .issue)   // FeedbackStarter.start(…, topic: nil, context:) → feedbackSession
}
struct HelpCommands: Commands {
  let support: SupportCoordinator
  // CommandGroup(replacing: .help): "help.menu.helpCenter" ⌘? (.keyboardShortcut("?", modifiers: .command)), "help.menu.feedback"
}
```

Texte: `help.menu.helpCenter` Frontstage-Hilfe · `help.menu.feedback` Rückmeldung geben …

- [ ] **Step 1: Failing Tests schreiben**

```swift
@MainActor @Suite struct SupportCoordinatorTests {
  @Test("Hilfecenter aus dem Menü") func showHelpCenterSetsFlag()
  @Test("Review 1: Rückmeldung aus dem Menü nimmt zuerst auf") func menuFeedbackCapturesFirst()   // Kontext-capture liefert Testbild; Sitzung hat 1 Bild .windowCapture, kind .issue
  @Test("Hilfecenter nicht über offener Rückmeldung") func helpCenterWaitsForFeedback()
}
```

- [ ] **Step 2: Skill laden** – `apple-design`; HIG „The menu bar“ (Hilfe-Menü), „Toolbars“ (Platz und Reihenfolge der Symbole), „Settings“.
- [ ] **Step 3: Implementieren** – jeder Knopf eigenes `ToolbarItem` hinter den vorhandenen; nichts Vorhandenes entfernen oder umsortieren (Übersicht, Abstimmung 13).
- [ ] **Step 4: Syntax prüfen**, Diff: 18 Stellen mit `HelpButton(topic:` (Liste oben, `grep -rn "HelpButton(topic:" Frontstage | wc -l`), jedes Thema außer `openingMaterial`, `privacy`, `feedback` mindestens einmal; `RootView` behält alles aus 04–10.
- [ ] **Step 5: Commit** – `git commit -m "ui: place help buttons, help menu commands and help center in setup"`

---

### Task 11: Kurz-Tipps (FR-17.5, AK-60)

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/Help/HelpTips.swift`, `Frontstage/Help/HelpTipsConfiguration.swift`
- Modify: `Frontstage/App/FrontstageApp.swift` – in `init` als Erstes `HelpTipsConfiguration.configureAtLaunch()`
- Modify: `Frontstage/Help/HelpCenterView.swift` – Section „Kurz-Tipps“: `Toggle` „Kurz-Tipps zeigen“ (bindet `HelpTips.isEnabled`), Taste „Kurz-Tipps erneut zeigen“ → `HelpTipsConfiguration.requestReset()`, danach Fußtext `tips.reset.note`
- Modify: `Frontstage/UI/DayView/DayView.swift` (`TipView(DaySelectionTip())` über der Liste, `.popoverTip(HelpButtonTip())` am Hilfeknopf), `Frontstage/UI/DayView/DayLessonDetail.swift` (`.popoverTip(MaterialTileTip())` an der ersten Material-Kachel), `Frontstage/SecondScreen/SmartboardBar.swift` (`.popoverTip(SmartboardBarTip())`, nur iOS)
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/Help/HelpTipsConfigurationTests.swift`

**Interfaces:**
- Consumes: `HelpCenterView` (9), `HelpButton` (9, 10)
- Produces:

```swift
struct HelpTips { @Parameter static var isEnabled: Bool = true }      // Entscheidung 13
struct DaySelectionTip: Tip { … }; struct MaterialTileTip: Tip { … }; struct SmartboardBarTip: Tip { … }; struct HelpButtonTip: Tip { … }
// jede: title, message, image (SF Symbol), rules: [#Rule(HelpTips.$isEnabled) { $0 == true }]
enum HelpTipsConfiguration {
  static let resetKey = "help.tips.resetOnNextLaunch"
  static func requestReset(defaults: UserDefaults = .standard)
  /// Im Testlauf nichts; sonst ggf. `reset()` und Schlüssel löschen, dann `configure()`. Reihenfolge fest (Apple: reset vor configure).
  static func configureAtLaunch(defaults: UserDefaults = .standard, isUnderTest: Bool = <XCTestConfigurationFilePath gesetzt>,
                                reset: () throws -> Void = { try Tips.resetDatastore() },
                                configure: () throws -> Void = { try Tips.configure([.displayFrequency(.daily)]) })
}
```

Texte: `tips.daySelection.title` Die laufende Stunde ist schon gewählt · `tips.daySelection.message` Tipp eine andere Stunde an, um sie anzusehen. „Heute“ bringt dich zurück. · `tips.materialTile.title` Mehr mit Gedrückthalten · `tips.materialTile.message` Halt eine Kachel gedrückt, um Material in die nächste Stunde zu schieben oder neu zu verknüpfen. · `tips.smartboardBar.title` Das sieht die Klasse · `tips.smartboardBar.message` Hier wählst du, was das Smartboard zeigt. · `tips.helpButton.title` Hilfe zu jedem Bildschirm · `tips.helpButton.message` Das Fragezeichen erklärt, was du hier tun kannst – auch ohne Netz. · `tips.section` Kurz-Tipps · `tips.enabled` Kurz-Tipps zeigen · `tips.reset` Kurz-Tipps erneut zeigen · `tips.reset.note` Gilt ab dem nächsten Start der App.

- [ ] **Step 1: Failing Tests schreiben** (eigene `UserDefaults(suiteName: UUID().uuidString)`; `reset`/`configure` als protokollierende Closures)

```swift
@Suite struct HelpTipsConfigurationTests {
  @Test("Im Testlauf weder reset noch configure") func skipsUnderTest()
  @Test("Ohne Anforderung nur configure") func configuresWithoutReset()
  @Test("AK-60: Anforderung → reset vor configure, Schlüssel gelöscht") func resetsBeforeConfigure()
  @Test("Schlägt reset fehl, wird trotzdem konfiguriert") func configuresEvenIfResetFails()
}
```

- [ ] **Step 2: Skill laden** – `apple-design`; HIG „Offering help“ / TipKit („Tips“): kurz, einmalig, nicht mehrere zugleich.
- [ ] **Step 3: Implementieren** – `@Parameter`-Syntax gegen die TipKit-Doku prüfen (Context7 oder developer.apple.com, `Tips.Parameter`); fällt der gemeinsame Parameter aus, je Tip ein eigener `@Parameter static var isEnabled`, gemeinsam gesetzt – im Abschlussbericht nennen.
- [ ] **Step 4: Syntax prüfen**, Diff: `Tips.configure` genau einmal (in `configureAtLaunch`); kein Tip im Zweitbildschirm-Code.
- [ ] **Step 5: Commit** – `git commit -m "ui: first-use tips with toggle and reset"`

---

### Task 12: CI-Lauf (workflow_dispatch) und Ergebnis prüfen – führt der Controller aus

Design-Takt: keiner

- [ ] **Step 1: Gesamtdiff durchsehen** – `git diff main...HEAD -- Packages Frontstage FrontstageTests project.yml .github docs`: `FrontstageCore` importiert nur `Foundation`; Swift 6 strikt (Closures in `FeedbackContext` `@MainActor`, Delegates von MessageUI/AppKit mit `@preconcurrency` wie bei `PKCanvasViewDelegate`); MessageUI und `PKCanvasView` nur iOS; keine echte Adresse (`grep -rn "@" Frontstage/Feedback project.yml` zeigt nur `feedback@example.com`); `Localizable.xcstrings` gültiges JSON, 84 `help.*`-Schlüssel mit `extractionState manual`; kein Hilfe-/Rückmeldungs-Code hinter `PaidGate`; `RootView` und `FrontstageApp` behalten alles aus 04–10.
- [ ] **Step 2: Kern lokal** – `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\swift-test.ps1` → alle Suites grün; `scripts\swift-parse.ps1` → keine Syntaxfehler.
- [ ] **Step 3: Secret anlegen** (einmalig, wenn Q-42 beantwortet ist): `gh secret set FEEDBACK_EMAIL` – fehlt es, baut CI mit leerer Adresse (Rückmeldung nur per Teilen), das ist zulässig.
- [ ] **Step 4: Lauf starten**

```bash
git push -u origin "$(git branch --show-current)"
gh workflow run ci.yml --ref "$(git branch --show-current)"
gh run list --workflow ci.yml --limit 1
gh run watch <run-id> --exit-status
```

Erwartet: „Core tests“ grün inkl. `Help Topics`, `Help Body`, `Help Text`, `Help Catalog`, `Help Search`, `Help Content` und der sieben Feedback-Suites; „App tests (iPad simulator)“ grün mit `HelpLibraryTests`, `FeedbackDraftStoreTests`, `FeedbackImageEncoderTests`, `DeviceInfoCollectorTests`, `MarkupEditorModelTests`, `FeedbackModelTests`, `FeedbackStarterTests`, `HelpCenterModelTests`, `SupportCoordinatorTests`, `HelpTipsConfigurationTests` sowie allen vorhandenen; „Build macOS“ grün (prüft `MacMarkupCanvas`, `MacMailComposer`, `HelpCommands`). Implementierer pushen nicht und starten keinen Lauf.

- [ ] **Step 5: Bei Rot** – erst `TestResults.xcresult` und `gh run view <run-id> --log-failed` lesen, Ursache mit superpowers:systematic-debugging klären, alle Korrekturen sammeln, Diff prüfen, **ein** neuer Lauf.
- [ ] **Step 6: Rückfluss** – Abweichungen vom Plan (z. B. Tip-Parameter, Aufnahme am Mac) in `docs/ARCHITECTURE.md` (Abschnitt „Hilfe und Rückmeldung“, Changes-Zeile) und als Nachtrag in `docs/sessions/2026-11-16.md`.

---

## Geräte-Checkliste (Mensch mit iPad und Mac, nach Task 12)

| # | Aufbau | Handlung | Erwartet | Ergebnis |
|---|---|---|---|---|
| 1 | **AK-55:** kein Kauf, iPad im Flugmodus | Fragezeichen in Heute; Hilfecenter › Tafel; „Rückmeldung geben“ | Artikel ohne Netz und ohne Kaufangebot; Rückmeldung schreibbar | ☐ |
| 2 | **AK-56:** VoiceOver an | Fragezeichen auf Heute, Vorbereiten, Jahresplan, Einrichten, Datenort, Ablage, Stundenplan-Quelle | Ansage „Hilfe zu <Thema>“; passender Artikel; verwandte Themen; Text skaliert bei „Größerer Text“ | ☐ |
| 3 | **AK-57:** Mac | Hilfe › Frontstage-Hilfe (⌘?); „AirPlay“, „ferien“, „ubernehmen“, „xyz“ | Center öffnet; Treffer wie AK-57; „Keine Treffer“ | ☐ Mac ☐ iPad mit Tastatur |
| 4 | **AK-59 / Review 1:** Heute mit „8b Englisch“, Apple TV verbunden | Fragezeichen › Rückmeldung geben; Bild öffnen, „8b“ schwärzen, Pfeil zeichnen; Fotos bis zur Grenze; eines entfernen | erstes Bild = Tagesansicht ohne Hilfeblatt und nicht das Smartboard-Bild; „8b“ im gesendeten Bild schwarz; höchstens 5 | ☐ iPad ☐ Mac |
| 5 | **AK-58:** Mail-Konto, Adresse aus Secret | Hinweis „Tafel speichert nicht“; App beenden; erneut öffnen; Geräteangaben an; Senden | Entwurf nach Neustart da; Mail mit Adresse, Betreff wie AK-58, Geräteangaben ohne Gerätenamen; danach Entwurf leer | ☐ iPad ☐ Mac |
| 6 | **AK-58:** ohne Mail-Konto | Rückmeldung öffnen | „Teilen“ und „Text kopieren“ statt „Senden“, Hinweiszeile | ☐ |
| 7 | **AK-60:** frische Installation | Tipp schließen, Neustart; „Kurz-Tipps erneut zeigen“, Neustart; ausschalten | einmal; nach Zurücksetzen wieder; aus = keiner | ☐ |
| 8 | Mac-Aufnahme | Rückmeldung aus dem Menü bei offener Vorbereiten-Ansicht | Bild zeigt den Fensterinhalt vollständig (keine leeren Flächen) | ☐ |
| 9 | Zeichnen am iPad mit Finger und Stift | Stift, Marker, Radierer aus der Werkzeugleiste | alle drei wirken; Zeichnung bleibt nach „Fertig“ und Neustart | ☐ |
| 10 | Hilfeknopf in Blättern | Koppeln, Tafel, Anzeige, „So verbinden“: Fragezeichen › Rückmeldung geben | Artikel erscheint; Rückmeldung öffnet im selben Blatt | ☐ |

---

## Abdeckung

| Anforderung | Task |
|---|---|
| FR-17 – Hilfe in der App, ohne Netz, kostenlos, ohne Server | 1, 2, 4, 5, 9; Checkliste 1 |
| FR-17.1 – Hilfeknöpfe, VoiceOver, Textgröße | 1, 9, 10; Checkliste 2, 10 |
| FR-17.2 – Hilfecenter, Suche ohne Umlaute, Menü ⌘? | 2, 4, 9, 10; Checkliste 3 |
| FR-17.3 – Idee/Hinweis per E-Mail, Geräteangaben aus, Entwurf lokal, Teilen/Kopieren | 3, 5, 6, 8; Checkliste 5, 6 |
| FR-17.4 – Aufnahme ohne Hilfeblatt und ohne Zweitbildschirm, Mediathek bis 5, Zeichnen, Schwärzen, Hinweis | 3, 6, 7, 8, 10; Checkliste 4, 8, 9 |
| FR-17.5 – Kurz-Tipps, abschaltbar, zurücksetzbar ab Neustart | 11; Checkliste 7 |
| FR-13 (geändert 2026-11-16) – Hilfe und Rückmeldung kostenlos | 9, 10 (kein `PaidGate`); Checkliste 1 |
| AK-55 … AK-60 | 4, 8, 9, 10, 11 (Logik); Checkliste 1–7 |
| RISK-11 – Schwärzen deckend, Hinweis, Geräteangaben ohne Namen | 3, 6, 7, 8 |
| ADR-0014 – Mail über das System, Adresse aus Build-Einstellung, Rückfall | 3, 5, 8, 12 |

## Produziert für spätere Teilpläne (Zusammenfassung)

- **Kern:** `HelpTopic`, `HelpGroup`, `HelpBlock`, `HelpBodyParser`, `HelpBodyError`, `HelpText`, `HelpArticle`, `HelpCatalog`, `HelpCatalogIssue`, `HelpSearch`, `FeedbackKind`, `NormalizedRect`, `FeedbackAttachmentOrigin`, `FeedbackAttachment`, `FeedbackDraft`, `DeviceInfo`, `FeedbackMessage`, `FeedbackComposer`, `FeedbackRecipient`, `FeedbackAttachmentPolicy`, `FeedbackShareReason`, `FeedbackRoute`.
- **App:** `HelpLibrary`, `FeedbackConfiguration`, `FeedbackDraftStore`, `FeedbackImageEncoder`, `WindowCapture`, `DeviceInfoCollector`, `MarkupEditorModel`, `MarkupEditorView`, `FeedbackContext`/`EnvironmentValues.feedbackContext`, `FeedbackModel`, `FeedbackSession`, `FeedbackStarter`, `feedbackSheet(_:)`, `HelpButton`, `HelpSheet`, `HelpArticleView`, `HelpCenterView`, `HelpCenterModel`, `SupportCoordinator`, `HelpCommands`, `HelpTips` und vier Tips, `HelpTipsConfiguration`.
- **Regel für spätere Bildschirme:** Jeder neue Hauptbildschirm und jeder schwierige Bereich bekommt einen `HelpButton` mit eigenem `HelpTopic` (Fall **hinten** anhängen, Gruppe und `related` setzen, vier Texte schreiben; `HelpContentTests` erzwingt die Texte).

## Abstimmungsbedarf

- **Q-42 (PRD):** Empfangsadresse und Datenschutzerklärung; bis dahin Platzhalter, Rückmeldung nur per Teilen/Kopieren in Builds ohne Secret.
- **Gestaltungslücken (keine neuen Beschlüsse, nächstliegende Regel):** Aussehen des Hilfeartikels (Zwischentitel über Größe nach UI-6, Hinweis-Block mit Symbol in Textfarbe nach UI-11), Vorschaubilder der Rückmeldung (Ecken nach UI-10 „Kacheln 16“), Schwärzungs-Rechteck beim Ziehen (gestrichelter Rand in Textfarbe), Kurz-Tipps (Systemdarstellung von TipKit). Jede wird im Abschlussbericht genannt; eine Design-Runde ist nicht nötig, solange Andreas nichts anderes wünscht.
- **Barrierefreiheit:** Zeichnen und Schwärzen gehen nur mit Ziehen; ein Bild ohne Zeichnung oder das Entfernen des Bildes ist immer möglich.

## Offene Risiken

1. **Mac-Aufnahme über `cacheDisplay`:** Einige Ebenen (Material-Effekte, Videoflächen) können leer erscheinen. Rückfall: Bild entfernen, Foto selbst über Mediathek anhängen. Checkliste 8.
2. **`drawHierarchy` am iPad** zeigt geschützte Inhalte (z. B. sichere Textfelder) nicht – erwünscht.
3. **Menü „Hilfe“ bei offenem Blatt:** öffnet nichts (Entscheidung 9). Rückfall: Blatt schließen, erneut wählen.
4. **`NSSharingService.composeEmail`** meldet nur die Übergabe; schlägt das Senden in Mail später fehl, ist der Entwurf schon leer (ADR-0014).
5. **TipKit-Parameter außerhalb eines Tips** ist laut Doku zulässig, aber nur für einen Tip belegt; Rückfall in Task 11 beschrieben.
6. **Lange Werte in `Localizable.xcstrings`:** Xcode kann beim Öffnen der Tabelle nicht referenzierte Schlüssel als „stale“ markieren, wenn `extractionState` fehlt; Task 4 setzt ihn, Task 12 prüft ihn.
