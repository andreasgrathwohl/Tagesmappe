# Frontstage — Teilplan 03: Ablage und Öffnen

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for
> tracking. Vorher die Übersicht `2026-11-13-00-uebersicht.md` lesen – sie gilt für jede Aufgabe hier.

**Goal:** Der Baustein „Ablage“ – Ordnerfreigaben je Gerät, Materialverweise auflösen mit Zustand,
Neu verknüpfen, Öffnen je Dateiart, Bereithalten für heute und den nächsten Unterrichtstag – und der
Baustein „OneDrive-Zusatz“, der Office-Dateien aus OneDrive nach Microsoft-Anmeldung als Cloud-Dokument
mit AutoSpeichern öffnet und sonst auf die Übergabe der Datei zurückfällt.

**Architecture:** Alle Entscheidungen (welcher Öffnen-Weg, wann Rückfall, welche Dateien bereithalten,
welcher Zustand, welcher Pfad in welcher Freigabe, welche Office-Adresse) sind reine Funktionen in
`FrontstageCore/Storage` mit Kern-Tests. Die App-Seite in `Frontstage/Storage` ist eine dünne Hülle um
Systemschnittstellen (Security-Scoped Bookmarks, Ressourcenwerte der Dateien-Schnittstelle,
`NSFileCoordinator`, `UIDocumentInteractionController`/`NSWorkspace`, MSAL, Microsoft Graph) und wird über
eine Fassade `StorageService` von Teilplan 04, 06 und 07 benutzt. Keine Oberfläche spricht einen Anbieter
direkt an (Area ablage).

**Tech Stack:** Swift 6 strikt, Foundation, Network (`NWPathMonitor`), UIKit/AppKit nur für die Übergabe,
MSAL 2.x (Swift Package, binär), Microsoft Graph v1.0 über `URLSession`, Swift Testing.

**Spec:** `docs/adr/0003-material-ueber-dateien-app-onedrive-als-zusatz.md`, `docs/ARCHITECTURE.md`
(Area ablage, Area daten: Materialverweis und Ordnerfreigabe), `docs/PRD.md` (FR-3.4, FR-5, FR-5.1,
NFR-1, NFR-2, NFR-3, AK-9, AK-11, AK-12, AK-17, AK-18, AK-19, Q-18), ADR-0002 (Ordnerfreigabe nicht
gespiegelt), ADR-0006 (App schreibt nie in die Ablage), ADR-0009.

**Quellen für Schnittstellen (gelesen 2026-11-13):**
- Apple, „Providing access to directories“ (`developer.apple.com/documentation/uikit/providing-access-to-directories`):
  Ordnerwahl mit `UIDocumentPickerViewController(forOpeningContentTypes: [.folder])`, Bookmark mit
  `.minimalBookmark`, Auflösen mit `URL(resolvingBookmarkData:bookmarkDataIsStale:)`,
  `startAccessingSecurityScopedResource()` vor jedem Zugriff, Lesen über `NSFileCoordinator`; die Freigabe
  kann in den Einstellungen jederzeit entzogen werden.
- Microsoft, „Office URI Schemes“ (`learn.microsoft.com/office/client-developer/office-uri-schemes`):
  `<scheme>:ofe|u|<https-URL>`, Schemes `ms-powerpoint`, `ms-word`, `ms-excel`, unterstützt in Office für
  iPad; Längengrenze des Arguments 256 Zeichen, bei Excel 216.
- OneDrive Opener (eigenes Repo `C:\Dev\OneDriveMac`, `Sources/FileOpener.swift`, `Sources/PathResolver.swift`):
  rückentwickelte Office-Adresse (`ofe%7Cor%7C…%7Cct%7C…%7Ccid%7C…%7Cu%7C<URL>`, weil Word für Mac die
  Kurzform ignoriert), privates OneDrive als `https://d.docs.live.net/<CID in Großbuchstaben>/<Pfad>`,
  `%2C` → `,`, Fristen 15 s/60 s. Für iPadOS ungeprüft (Q-18).
- MSAL für iOS/macOS (Context7 `/azuread/microsoft-authentication-library-for-objc`, README und
  `docs/MSAL_2x_Migration_Guide.md`): `MSALPublicClientApplicationConfig(clientId:redirectUri:authority:)`,
  Redirect-URI `msauth.<Bundle-ID>://auth`, `MSALWebviewParameters(authPresentationViewController:)`,
  `acquireToken(with:)`, `acquireTokenSilent(with:)`, `account(forIdentifier:)`, `accountsFromDevice`,
  `MSALCacheConfig.keychainSharingGroup` (= Bundle-ID für privaten Schlüsselbund), Info.plist
  `LSApplicationQueriesSchemes` `msauthv2`, `msauthv3`, SPM-URL
  `https://github.com/AzureAD/microsoft-authentication-library-for-objc`.
- Apple Developer Forums 740544 (2023): `UIDocumentInteractionController` übergab Word-Dateien ab iOS 17
  teils nur lesend – ob „Öffnen am Ort“ auf iPadOS 26 greift, ist nur am Gerät zu belegen (Geräte-Checkliste).

## Global Constraints

Es gelten alle Zeilen aus `2026-11-13-00-uebersicht.md`, Abschnitt „Global Constraints“. Zusätzlich für
diesen Teilplan:

- **Die App schreibt nie in die Ablage** (ADR-0003, ADR-0006). Bookmarks am Mac nur mit
  `[.withSecurityScope, .securityScopeAllowOnlyReadAccess]`; Entitlement `files.user-selected.read-only`.
  Kein `FileManager`-Schreibaufruf auf eine URL unter einer Ordnerfreigabe.
- **Ordnerfreigaben verlassen das Gerät nie:** Sie liegen in einer Datei in Application Support mit
  `isExcludedFromBackup = true`, nicht in SwiftData (ADR-0002, Area daten). Gespiegelt wird nur der
  **Name** der Freigabe im Materialverweis.
- **Pfade im Materialverweis:** relativ zur Freigabe, Trenner `/`, Unicode **NFC**
  (`precomposedStringWithCanonicalMapping`), nie mit führendem `/`.
- **Nie stillschweigend einen alten Stand zeigen** (Area ablage): Ein lokal vorhandener, aber nicht
  aktueller Stand trägt `isCurrent: false`; die Oberfläche sagt das.
- **OneDrive-Zusatz nur nach Anmeldung und nur online.** Ohne Netz geht jede Office-Datei sofort den Weg
  „Übergabe“ (AK-17: unter 3 s offline).
- **Netzverbindungen dieses Teilplans:** nur `login.microsoftonline.com` (MSAL) und `graph.microsoft.com`;
  Office-Adressen werden nur an die Office-App übergeben, nie selbst abgerufen (NFR-2, AK-18).
- MSAL-Client-ID nie ins Repo: Build-Einstellung `MSAL_CLIENT_ID` aus dem CI-Secret `MSAL_CLIENT_ID`; ist
  sie leer, ist der OneDrive-Zusatz ausgeblendet (`MicrosoftAccount.isConfigured == false`).
- In Tests nur erfundene Pfade und Namen: Freigabe „Unterricht“, Dateien „Vokabeln Unit 4.pptx“,
  „Arbeitsblatt Vokabeln.pdf“, „Übung.docx“; Domains `example.com`, `example-my.sharepoint.com`.

## Entscheidungen dieses Teilplans

- **MSAL statt eigener Anmeldung über `ASWebAuthenticationSession`.** Begründung: Schulträger setzen bei
  Entra-ID-Konten oft bedingten Zugriff und Gerätevorgaben durch; MSAL deckt das samt Vermittler-App
  (Microsoft Authenticator) ab, verwaltet Token, Erneuerung und Schlüsselbund-Ablage. Mit
  `ASWebAuthenticationSession` müssten PKCE, Token-Erneuerung, Token-Ablage und die Fehlerfälle für
  private und Schulkonten selbst gebaut und sicherheitsgeprüft werden – eigener Sicherheitscode an der
  Stelle, an der ein Fehler Zugangsdaten betrifft (NFR-4). Kosten: binäre Fremdabhängigkeit, Objective-C-API
  mit Rückruf-Blöcken (Hülle mit `withCheckedThrowingContinuation`, `@preconcurrency import MSAL`),
  Redirect-URI je Bundle-ID in der App-Registrierung, MSAL-Updates nachziehen. Netzverkehr nur zu
  Microsoft-Anmeldeservern – mit NFR-2 vereinbar (AK-18 prüft es).
- **Berechtigung `Files.Read`, Authority `https://login.microsoftonline.com/common`** (private und
  Schul-/Arbeitskonten). Die App schreibt nie über Graph.
- **Welcher Ordner in OneDrive liegt, erkennt die App selbst** (statt Anbieter-Erkennung über Pfade, die
  auf iPadOS nicht belegt sind): Nach der Anmeldung und nach jeder neuen Freigabe probiert sie die
  Pfad-Endungen des freigegebenen Ordners in OneDrive aus und vergleicht die Dateinamen darin. Nur
  Freigaben mit erkanntem OneDrive-Pfad bekommen Graph-Abfragen; eine iCloud-Datei mit gleichem Pfad wird
  so nie versehentlich als OneDrive-Dokument geöffnet.
- **Office-Adresse in der Form von „In Desktop-App öffnen“** (`%7C`-Trenner mit `or`, `ct`, `cid`) als
  Vorgabe, die dokumentierte Kurzform `ofe|u|` als umschaltbare Alternative. Grund: am Mac belegt
  (OneDrive Opener), und `URL(string:)` lässt die Form mit `%7C` unverändert. Welche Form auf iPadOS
  wirkt, klärt die Geräte-Checkliste (Q-18).
- **Fristen:** Vorbereitung der Office-Adresse (Token + Graph) höchstens **5 s**, Annahme durch die
  Office-App höchstens **10 s** (wie `open` in OneDrive Opener); danach Übergabe der Datei. Kehrt die
  Lehrkraft binnen **60 s** nach einer Cloud-Übergabe zur App zurück, bietet die App „ohne AutoSpeichern
  öffnen“ an (Gegenstück zu „Lokal öffnen“ in OneDrive Opener; die App kann auf dem Tablet nicht
  nachsehen, ob PowerPoint das Dokument geöffnet hat). Werte als Konstanten in `CloudOpenPolicy`.
- **Neu verknüpfen ersetzt den Verweis an allen Zuordnungen mit demselben alten Ort** – eine Datei, eine
  Korrektur. Die Zuordnungen selbst bleiben, Stiftnotizen hängen weiter daran (Area anzeige).
- **Übergabe auf dem Tablet über `UIDocumentInteractionController.presentOpenInMenu`** (dokumentiert, ein
  Auswahlschritt); am Mac `NSWorkspace.open`. Ob die Ziel-App am Ort bearbeitet (AK-11), ist nur am Gerät
  belegbar.

## Review Focus

1. **Umlaute aus Mac und iPad** („Übung.docx“ als NFD vom Mac, NFC vom iPad) – Verweis löst auf beiden
   Geräten auf. Test: `StoragePathTests.nfdFileMatchesNfcGrant`, `matchNamePrefersExactThenNfc`
   (Aufgabe 1), `MaterialResolverTests.resolvesNfdNameOnDisk` (Aufgabe 7).
2. **Freigabe in den Einstellungen entzogen oder Bookmark veraltet** – Zustand „nicht verfügbar“ mit Grund
   `grantMissing`, nie Absturz; veraltetes Bookmark wird erneuert. Test:
   `MaterialResolverTests.unknownGrantNameIsGrantMissing`, `FolderGrantStoreTests.unresolvableBookmarkIsReportedNotThrown`
   (Aufgaben 6, 7).
3. **Verschachtelte Freigaben** („Unterricht“ und darin „Englisch“ freigegeben) – die engste Freigabe
   gewinnt, sonst entstehen zwei Verweise auf dieselbe Datei. Test: `StoragePathTests.longestGrantPrefixWins`
   (Aufgabe 1).
4. **Office-Datei mit OneDrive-Anmeldung, aber offline oder mit zu langer Adresse** – sofort Übergabe, kein
   Warten. Test: `OpenRouterTests.offlineOfficeGoesStraightToHandOff`,
   `OpenRouterTests.excelAddressOver216CharactersFallsBack` (Aufgabe 3).
5. **Gleicher Ordnername auf zwei Anbietern** („Unterricht“ in iCloud und in OneDrive auf demselben Gerät)
   – zweite Freigabe bekommt „Unterricht 2“, auf dem zweiten Gerät wird ein gespiegelter Name angeboten.
   Test: `FolderGrantNamingTests.*` (Aufgabe 1).

---

## Dateistruktur

| Datei | Verantwortung |
|---|---|
| `Packages/FrontstageCore/Sources/FrontstageCore/Storage/FileKind.swift` | Dateiart und zuständige Office-App aus der Endung |
| `…/Storage/MaterialReference.swift` | Wertetyp Materialverweis, `locationKey` |
| `…/Storage/StoragePath.swift` | Pfade normalisieren, Datei → (Freigabe, relativer Pfad), Namensabgleich NFC |
| `…/Storage/FolderGrantNaming.swift` | Namensvorschlag für eine neue Freigabe |
| `…/Storage/MaterialAvailability.swift` | Zustand aus Dateifakten |
| `…/Storage/OpenRouter.swift` | Öffnen-Weg und Rückfall-Regeln (`CloudOpenPolicy`) |
| `…/Storage/PrefetchPlanner.swift` | was bereitgehalten wird |
| `…/Storage/OneDrive/OneDriveItem.swift` | Graph-Element (decodierbar) |
| `…/Storage/OneDrive/OfficeAddress.swift` | Dokument-Adresse und Office-Adresse |
| `…/Storage/OneDrive/OneDriveFolderMatching.swift` | Kandidaten-Pfade und Namensvergleich für die Ordnererkennung |
| `Frontstage/Storage/FolderGrant.swift`, `FolderGrantStore.swift` | Ordnerfreigaben lokal speichern, Bookmarks |
| `Frontstage/Storage/MaterialResolver.swift`, `FileFactsReader.swift` | Verweis → URL, Zustand |
| `Frontstage/Storage/ScopedFile.swift` | geöffneter Zugriff auf eine Datei für Anzeige und Tafel |
| `Frontstage/Storage/NetworkMonitor.swift`, `Prefetcher.swift` | Netzstand, Herunterladen anstoßen |
| `Frontstage/Storage/DocumentHandOff.swift` | Übergabe an die zuständige App (iOS/macOS) |
| `Frontstage/Storage/MaterialReferenceStore.swift` | Protokoll, das Teilplan 02 erfüllt |
| `Frontstage/Storage/StorageService.swift` | Fassade für 04, 06, 07 |
| `Frontstage/Storage/OneDrive/MicrosoftAccount.swift`, `GraphClient.swift`, `OneDriveService.swift` | Anmeldung, Graph, Ordnererkennung und Element-Auflösung |
| `Packages/FrontstageCore/Tests/FrontstageCoreTests/Storage/*Tests.swift` | Kern-Tests |
| `FrontstageTests/Storage/*Tests.swift` | App-Tests (Simulator) |

---

### Task 1: Dateiart, Materialverweis, Pfade, Freigabe-Namen (Kern)

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Storage/FileKind.swift`
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Storage/MaterialReference.swift`
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Storage/StoragePath.swift`
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Storage/FolderGrantNaming.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/Storage/FileKindTests.swift`, `StoragePathTests.swift`, `FolderGrantNamingTests.swift`

**Interfaces:**
- Consumes: –
- Produces:
```swift
public enum FileKind: String, Codable, Sendable, CaseIterable {
    case presentation, document, spreadsheet, pdf, image, other
    public init(fileExtension: String)            // ohne Punkt, Groß-/Kleinschreibung egal
    public var opensInViewer: Bool { get }        // pdf, image
}
public enum OfficeApp: String, Codable, Sendable {
    case word, excel, powerpoint
    public init?(fileExtension: String)
    public var scheme: String { get }             // "ms-word", "ms-excel", "ms-powerpoint"
    public var addressLengthLimit: Int { get }    // 256, Excel 216 (Office URI Schemes 1.7)
}
public struct MaterialReference: Hashable, Codable, Sendable {
    public var grantName: String
    public var relativePath: String               // NFC, "/"-getrennt, ohne führenden "/"
    public var displayName: String
    public var fileKind: FileKind
    public var oneDriveItemID: String?
    public var oneDriveDriveID: String?
    public init(grantName: String, relativePath: String, displayName: String, fileKind: FileKind,
                oneDriveItemID: String? = nil, oneDriveDriveID: String? = nil)
    /// Ort ohne OneDrive-Kennung: Schlüssel für Zustände und für Neu verknüpfen.
    public var locationKey: String { get }        // grantName + "\u{1F}" + relativePath.lowercased()
    public var fileExtension: String { get }
}
public struct GrantLocation: Hashable, Sendable { public let name: String; public let components: [String] }
public struct RelativeLocation: Hashable, Sendable { public let grantName: String; public let relativePath: String }
public enum StoragePath {
    public static func normalizedComponents(_ path: String) -> [String]   // ohne "/", ohne führendes "private" vor var/tmp/etc, NFC
    public static func relativeLocation(ofFile file: [String], in grants: [GrantLocation]) -> RelativeLocation?
    public static func components(ofRelativePath path: String) -> [String]
    public static func matchName(_ wanted: String, among names: [String]) -> String?
}
public struct GrantNameSuggestion: Hashable, Sendable { public let name: String; public let matchesMirroredName: Bool }
public enum FolderGrantNaming {
    public static func suggestion(folderName: String, localGrantNames: Set<String>, mirroredNames: Set<String>) -> GrantNameSuggestion
}
```

- [ ] **Step 1: Tests schreiben**

```swift
@Test("Dateiart aus der Endung, unabhängig von Groß-/Kleinschreibung (FR-5, FR-6)")
func fileKindFromExtension() {
    #expect(FileKind(fileExtension: "PPTX") == .presentation)
    #expect(FileKind(fileExtension: "key") == .presentation)
    #expect(FileKind(fileExtension: "pages") == .document)
    #expect(FileKind(fileExtension: "numbers") == .spreadsheet)
    #expect(FileKind(fileExtension: "pdf") == .pdf)
    for ext in ["png", "jpg", "jpeg", "heic"] { #expect(FileKind(fileExtension: ext) == .image) }
    #expect(FileKind(fileExtension: "txt") == .other)
    #expect(FileKind(fileExtension: "pdf").opensInViewer && FileKind(fileExtension: "png").opensInViewer)
}
@Test("Office-App nur für Microsoft-Formate (FR-5.1)")
func officeAppOnlyForMicrosoftFormats() {
    #expect(OfficeApp(fileExtension: "pptx") == .powerpoint)
    #expect(OfficeApp(fileExtension: "ppsx") == .powerpoint)
    #expect(OfficeApp(fileExtension: "doc") == .word)
    #expect(OfficeApp(fileExtension: "xlsx") == .excel)
    #expect(OfficeApp(fileExtension: "key") == nil)
    #expect(OfficeApp.excel.addressLengthLimit == 216 && OfficeApp.powerpoint.addressLengthLimit == 256)
}
@Test("/private vor var wird entfernt, NFC") func normalizedComponentsDropPrivate() {
    #expect(StoragePath.normalizedComponents("/private/var/mobile/U\u{0308}bung.docx") == ["var", "mobile", "Übung.docx"])
    #expect(StoragePath.normalizedComponents("/Users/x/Unterricht/") == ["Users", "x", "Unterricht"])
}
@Test("Engste Freigabe gewinnt (Review Focus 3)") func longestGrantPrefixWins() {
    let grants = [GrantLocation(name: "Unterricht", components: ["Users", "x", "Unterricht"]),
                  GrantLocation(name: "Englisch", components: ["Users", "x", "Unterricht", "Englisch"])]
    let loc = StoragePath.relativeLocation(ofFile: ["Users", "x", "Unterricht", "Englisch", "8b", "Arbeitsblatt Vokabeln.pdf"], in: grants)
    #expect(loc == RelativeLocation(grantName: "Englisch", relativePath: "8b/Arbeitsblatt Vokabeln.pdf"))
}
@Test("Datei außerhalb jeder Freigabe oder die Freigabe selbst ergibt nil") func outsideOrFolderItselfIsNil() {
    let grants = [GrantLocation(name: "Unterricht", components: ["Users", "x", "Unterricht"])]
    #expect(StoragePath.relativeLocation(ofFile: ["Users", "x", "Downloads", "a.pdf"], in: grants) == nil)
    #expect(StoragePath.relativeLocation(ofFile: ["Users", "x", "Unterricht"], in: grants) == nil)
}
@Test("NFD-Datei passt zu NFC-Freigabe, Ergebnis NFC (Review Focus 1)") func nfdFileMatchesNfcGrant() {
    let grants = [GrantLocation(name: "Übungen", components: ["Users", "x", "Übungen"])]
    let loc = StoragePath.relativeLocation(ofFile: ["Users", "x", "U\u{0308}bungen", "U\u{0308}bung.docx"], in: grants)
    #expect(loc?.relativePath == "Übung.docx")
    #expect(loc?.relativePath.unicodeScalars.count == "Übung.docx".unicodeScalars.count)
}
@Test("Präfix ohne Groß-/Kleinschreibung") func prefixIsCaseInsensitive() {
    let grants = [GrantLocation(name: "Unterricht", components: ["Users", "x", "Unterricht"])]
    #expect(StoragePath.relativeLocation(ofFile: ["Users", "x", "unterricht", "a.pdf"], in: grants)?.grantName == "Unterricht")
}
@Test("Namensabgleich: exakt vor NFC vor ohne Groß-/Kleinschreibung; mehrdeutig = nil") func matchNamePrefersExactThenNfc() {
    #expect(StoragePath.matchName("Übung.docx", among: ["U\u{0308}bung.docx", "x"]) == "U\u{0308}bung.docx")
    #expect(StoragePath.matchName("a.pdf", among: ["A.pdf", "a.pdf"]) == "a.pdf")
    #expect(StoragePath.matchName("A.PDF", among: ["a.pdf"]) == "a.pdf")
    #expect(StoragePath.matchName("A.PDF", among: ["a.pdf", "A.pdf"]) == nil)
    #expect(StoragePath.matchName("fehlt.pdf", among: ["a.pdf"]) == nil)
}
@Test("locationKey ignoriert OneDrive-Kennung und Groß-/Kleinschreibung des Pfads") func locationKeyIgnoresOneDriveID() {
    let a = MaterialReference(grantName: "Unterricht", relativePath: "8b/Vokabeln Unit 4.pptx", displayName: "Vokabeln Unit 4", fileKind: .presentation)
    var b = a; b.oneDriveItemID = "01ABC"; b.relativePath = "8b/vokabeln unit 4.pptx"
    #expect(a.locationKey == b.locationKey)
    #expect(a.fileExtension == "pptx")
}
// FolderGrantNamingTests
@Test("Ordnername passt zu gespiegeltem Namen ohne lokale Freigabe") func suggestsMirroredName() {
    #expect(FolderGrantNaming.suggestion(folderName: "Unterricht", localGrantNames: [], mirroredNames: ["Unterricht"])
            == GrantNameSuggestion(name: "Unterricht", matchesMirroredName: true))
}
@Test("Neuer Name ohne Bezug") func suggestsFolderName() {
    #expect(FolderGrantNaming.suggestion(folderName: "Englisch", localGrantNames: ["Unterricht"], mirroredNames: [])
            == GrantNameSuggestion(name: "Englisch", matchesMirroredName: false))
}
@Test("Gleicher Ordnername zweimal: Zähler ab 2 (Review Focus 5)") func appendsCounter() {
    #expect(FolderGrantNaming.suggestion(folderName: "Unterricht", localGrantNames: ["Unterricht", "Unterricht 2"], mirroredNames: ["Unterricht"]).name == "Unterricht 3")
}
```

- [ ] **Step 2: Diff durchsehen** – Tests kompilieren nur gegen die Signaturen oben (`@testable import FrontstageCore`); `RelativeLocation` ist `Equatable` über `Hashable`.

- [ ] **Step 3: Implementieren** in den vier Dateien. `normalizedComponents`: `URL(fileURLWithPath:).standardizedFileURL.pathComponents`, führendes `"/"` weg, `"private"` weg, wenn das nächste Element `var`, `tmp` oder `etc` ist (dasselbe tut `resolvingSymlinksInPath`, aber testbar ohne Dateisystem), jedes Element NFC. Präfixvergleich je Element NFC + `caseInsensitiveCompare`. `matchName` in drei Stufen; in jeder Stufe gilt nur ein eindeutiger Treffer.

- [ ] **Step 4: Diff durchsehen** – nur `import Foundation`; keine `public` Eigenschaft ohne `///`-Doku auf Deutsch.

- [ ] **Step 5: Commit** – `git add Packages/FrontstageCore/Sources/FrontstageCore/Storage Packages/FrontstageCore/Tests/FrontstageCoreTests/Storage && git commit -m "feat(core): file kind, material reference, storage paths, grant naming"`

---

### Task 2: Zustand des Materials (Kern)

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Storage/MaterialAvailability.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/Storage/MaterialAvailabilityTests.swift`

**Interfaces:**
- Consumes: –
- Produces:
```swift
public enum DownloadStatus: Sendable { case current, downloaded, notDownloaded }   // Abbild von URLUbiquitousItemDownloadingStatus
public struct FileFacts: Hashable, Sendable {
    public var grantResolved: Bool
    public var exists: Bool
    public var isUbiquitous: Bool
    public var downloadStatus: DownloadStatus?
    public var isDownloading: Bool
    public var downloadFraction: Double?       // nur wenn das System sie liefert, sonst nil
    public var hasDownloadError: Bool
}
public enum UnavailableReason: String, Hashable, Codable, Sendable { case grantMissing, fileMissing, notDownloadedOffline, downloadFailed }
public enum MaterialAvailability: Hashable, Sendable {
    case onDevice(isCurrent: Bool)             // „auf dem Gerät“; isCurrent false = älterer Stand, nie still zeigen
    case downloading(fraction: Double?)        // „wird geladen“
    case unavailable(UnavailableReason)        // „nicht verfügbar“
}
public enum AvailabilityClassifier { public static func classify(_ facts: FileFacts, isOnline: Bool) -> MaterialAvailability }
```

- [ ] **Step 1: Tests schreiben** – ein parametrisierter Test `@Test("Zustand aus Dateifakten (NFR-1, Area ablage)", arguments: …)` mit diesen Zeilen (Fakten → erwarteter Zustand):

| grantResolved | exists | isUbiquitous | status | isDownloading | error | online | Ergebnis |
|---|---|---|---|---|---|---|---|
| false | – | – | – | – | – | true | `.unavailable(.grantMissing)` |
| true | false | – | – | – | – | true | `.unavailable(.fileMissing)` |
| true | true | false | nil | false | false | false | `.onDevice(isCurrent: true)` |
| true | true | true | .current | false | false | false | `.onDevice(isCurrent: true)` |
| true | true | true | .downloaded | false | false | false | `.onDevice(isCurrent: false)` |
| true | true | true | .downloaded | true | false | true | `.downloading(fraction: nil)` |
| true | true | true | .notDownloaded | true (fraction 0.4) | false | true | `.downloading(fraction: 0.4)` |
| true | true | true | .notDownloaded | false | false | true | `.downloading(fraction: nil)` (Bereithalten stößt an) |
| true | true | true | .notDownloaded | false | false | false | `.unavailable(.notDownloadedOffline)` |
| true | true | true | .notDownloaded | false | true | true | `.unavailable(.downloadFailed)` |

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: Implementieren** `classify` als `switch` in der Reihenfolge der Tabelle (erste passende Zeile gewinnt).
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `feat(core): material availability from file facts`

---

### Task 3: Öffnen-Weg und Rückfall (Kern)

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Storage/OpenRouter.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/Storage/OpenRouterTests.swift`, `CloudOpenPolicyTests.swift`

**Interfaces:**
- Consumes: `FileKind`, `OfficeApp` (Task 1), `MaterialAvailability`, `UnavailableReason` (Task 2)
- Produces:
```swift
public struct OpenContext: Sendable {
    public var fileKind: FileKind
    public var officeApp: OfficeApp?
    public var availability: MaterialAvailability
    public var isOnline: Bool
    public var isMicrosoftSignedIn: Bool
    public var isOfficeAppInstalled: Bool
    public var oneDriveDocumentURL: String?     // aus OfficeAddress.documentURL, nil = nicht in OneDrive/unbekannt
}
public indirect enum OpenRoute: Hashable, Sendable {
    case viewer                                 // eigene Anzeige (Teilplan 06)
    case handOff                                // Übergabe der Datei an die zuständige App
    case officeCloud(documentURL: String)       // FR-5.1
    case waitForDownload(then: OpenRoute)
    case unavailable(UnavailableReason)
}
public enum OpenRouter { public static func route(_ context: OpenContext) -> OpenRoute }
public enum CloudOpenStep: Hashable, Sendable { case keepWaiting, done, fallBackToHandOff }
public enum CloudOpenPolicy {
    public static let preparationLimit: Duration   // .seconds(5)
    public static let handOverLimit: Duration      // .seconds(10)
    public static let returnWindow: Duration       // .seconds(60)
    public static func afterPreparation(addressReady: Bool, elapsed: Duration) -> CloudOpenStep
    public static func afterHandOver(accepted: Bool?, elapsed: Duration) -> CloudOpenStep   // nil = noch keine Antwort
    public static func offersOpenWithoutAutoSave(returnedAfter: Duration) -> Bool
}
```

Regeln für `route` (in dieser Reihenfolge):
1. `officeApp != nil && isMicrosoftSignedIn && isOnline && isOfficeAppInstalled && oneDriveDocumentURL != nil && url.count <= officeApp.addressLengthLimit` → `.officeCloud` (unabhängig vom lokalen Zustand: das Cloud-Dokument braucht keine lokale Kopie).
2. Ziel `t = fileKind.opensInViewer ? .viewer : .handOff`; `availability` `.onDevice` → `t`; `.downloading` → `.waitForDownload(then: t)`; `.unavailable(r)` → `.unavailable(r)`.

- [ ] **Step 1: Tests schreiben**

```swift
@Test("PDF auf dem Gerät öffnet in der eigenen Anzeige (FR-6)") func pdfOnDeviceOpensViewer()          // .viewer
@Test("Bild wird geladen: warten, dann Anzeige") func imageDownloadingWaitsForViewer()                // .waitForDownload(then: .viewer)
@Test("Präsentation ohne Anmeldung: Übergabe (FR-5, AK-11)") func presentationWithoutSignInHandsOff() // .handOff
@Test("OneDrive-Präsentation mit Anmeldung online: Cloud-Dokument (FR-5.1, AK-12)") func signedInOnlineOneDriveOpensCloud()
    // documentURL "https://d.docs.live.net/ABC123/Unterricht/Vokabeln%20Unit%204.pptx" → .officeCloud(documentURL: dieselbe)
@Test("Cloud-Dokument auch, solange die lokale Kopie lädt") func cloudIgnoresLocalDownloading()
@Test("Offline mit Anmeldung: sofort Übergabe (AK-17, Review Focus 4)") func offlineOfficeGoesStraightToHandOff()
@Test("Ohne OneDrive-Adresse: Übergabe") func missingDocumentURLHandsOff()
@Test("PowerPoint nicht installiert: Übergabe") func officeAppMissingHandsOff()
@Test("Excel-Adresse mit 217 Zeichen: Übergabe; PowerPoint mit 256: Cloud, 257: Übergabe") func excelAddressOver216CharactersFallsBack()
@Test("Keynote ist keine Office-Datei: Übergabe") func keynoteHandsOff()                               // officeApp nil
@Test("Verweis löst nicht auf: nicht verfügbar mit Grund") func unresolvedIsUnavailable()             // .unavailable(.fileMissing)
// CloudOpenPolicyTests
@Test("Vorbereitung: 4,9 s weiter warten, 5 s Rückfall") func preparationLimit() {
    #expect(CloudOpenPolicy.afterPreparation(addressReady: false, elapsed: .milliseconds(4900)) == .keepWaiting)
    #expect(CloudOpenPolicy.afterPreparation(addressReady: false, elapsed: .seconds(5)) == .fallBackToHandOff)
    #expect(CloudOpenPolicy.afterPreparation(addressReady: true, elapsed: .seconds(6)) == .done)
}
@Test("Übergabe: abgelehnt sofort Rückfall, keine Antwort nach 10 s Rückfall") func handOverLimit() {
    #expect(CloudOpenPolicy.afterHandOver(accepted: false, elapsed: .seconds(1)) == .fallBackToHandOff)
    #expect(CloudOpenPolicy.afterHandOver(accepted: nil, elapsed: .seconds(9)) == .keepWaiting)
    #expect(CloudOpenPolicy.afterHandOver(accepted: nil, elapsed: .seconds(10)) == .fallBackToHandOff)
    #expect(CloudOpenPolicy.afterHandOver(accepted: true, elapsed: .seconds(3)) == .done)
}
@Test("Rückkehr binnen 60 s bietet Öffnen ohne AutoSpeichern an") func returnWindow() {
    #expect(CloudOpenPolicy.offersOpenWithoutAutoSave(returnedAfter: .seconds(60)))
    #expect(!CloudOpenPolicy.offersOpenWithoutAutoSave(returnedAfter: .seconds(61)))
}
```
Jeder `OpenRouterTests`-Fall baut einen `OpenContext` über eine Test-Hilfsfunktion `context(kind:ext:availability:online:signedIn:installed:url:)` mit Vorgaben `.onDevice(isCurrent: true)`, online, nicht angemeldet, installiert, `url` nil.

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: Implementieren** gemäß den Regeln; Grenzwerte mit `>=` (Frist erreicht = Rückfall).
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `feat(core): open routing and cloud open fallback policy`

---

### Task 4: Was bereitgehalten wird (Kern, NFR-1)

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Storage/PrefetchPlanner.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/Storage/PrefetchPlannerTests.swift`

**Interfaces:**
- Consumes: `TimetableCalculator.lessons(on:timetable:nonTeachingPeriods:changes:)`, `CalendarDay`, `LessonKey`, `Timetable`, `NonTeachingPeriod`, `ScheduleChange` (Teilplan 01); **erwartet von Teilplan 01:** `CalendarDay.adding(days: Int) -> CalendarDay` (siehe Abstimmungsbedarf)
- Produces:
```swift
public enum PrefetchPlanner {
    /// Unterrichtsstunden von heute (alle, auch vergangene) und vom nächsten Tag mit mindestens einer
    /// nicht ausgefallenen Unterrichtsstunde, höchstens `lookaheadDays` Tage voraus. Ausfälle zählen nicht.
    public static func lessonKeys(today: CalendarDay, timetable: Timetable, nonTeachingPeriods: [NonTeachingPeriod],
                                  changes: [ScheduleChange], lookaheadDays: Int = 14) -> [LessonKey]
    /// Verweise dieser Stunden, ohne Doppelte (gleicher locationKey), in Reihenfolge des ersten Auftretens.
    public static func references(for keys: [LessonKey], links: [(key: LessonKey, reference: MaterialReference)]) -> [MaterialReference]
}
```

- [ ] **Step 1: Tests schreiben** (Stundenplan einwöchig, `referenceWeekA` 16.11.2026; Freitag 13.11.2026)

```swift
@Test("Heute und nächster Unterrichtstag (NFR-1, AK-17)") func coversTodayAndNextTeachingDay()
    // Fr 1. Stunde 8b Englisch, Mo 2. Stunde 7a Mathe; today 13.11.2026
    // #expect(Set(keys.map(\.date)) == [13.11.2026, 16.11.2026]); keys.count == 2
@Test("Ferien werden übersprungen (AK-14-Aufbau)") func skipsNonTeachingPeriod()
    // Ferien 2.–6.11.2026, Einträge Fr und Mo; today Fr 30.10.2026 → Daten [30.10.2026, 9.11.2026]
@Test("Heute ohne Unterricht: nur der nächste Unterrichtstag") func weekendYieldsNextTeachingDayOnly()
    // today Sa 14.11.2026 → nur 16.11.2026
@Test("Tag nur mit Ausfällen zählt nicht als nächster Unterrichtstag") func cancelledOnlyDayIsSkipped()
    // Einträge Mo 7a, Di 8b; Mo 16.11. ausgefallen; today So 15.11.2026 → nur Di 17.11.2026
@Test("Vertretungsstunde wird bereitgehalten (FR-9)") func substituteLessonIncluded()
    // substituteLesson Mi 18.11.2026 4. Stunde 6c Mathe, sonst kein Eintrag; today Di 17.11.2026 → Key 18.11. 6c
@Test("Ohne Unterricht in 14 Tagen: leer") func emptyWithinLookahead()
@Test("Gleiche Datei in zwei Stunden nur einmal") func referencesAreDeduplicated()
    // zwei Links mit relativePath "8b/Vokabeln Unit 4.pptx" und "8B/vokabeln unit 4.pptx" → 1 Verweis, der erste
```

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: Implementieren** – Schleife `d = 1 … lookaheadDays` über `today.adding(days: d)`; erste Liste ohne `isCancelled` nicht leer → fertig. Heute: alle nicht ausgefallenen Stunden.
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `feat(core): prefetch planner for today and next teaching day`

---

### Task 5: OneDrive – Element, Dokument-Adresse, Office-Adresse, Ordnererkennung (Kern)

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Storage/OneDrive/OneDriveItem.swift`
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Storage/OneDrive/OfficeAddress.swift`
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Storage/OneDrive/OneDriveFolderMatching.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/Storage/OfficeAddressTests.swift`, `OneDriveFolderMatchingTests.swift`

**Interfaces:**
- Consumes: `OfficeApp` (Task 1)
- Produces:
```swift
/// Ausschnitt eines Graph-driveItem (`$select=id,name,webUrl,parentReference`).
public struct OneDriveItem: Hashable, Codable, Sendable {
    public struct ParentReference: Hashable, Codable, Sendable { public var driveId: String; public var driveType: String; public var path: String? }
    public var id: String
    public var name: String
    public var webUrl: String
    public var parentReference: ParentReference
}
public enum OfficeURIForm: String, Codable, Sendable { case documented, webStyle }
public enum OfficeAddress {
    /// privat: https://d.docs.live.net/<DRIVEID groß>/<Pfad>; business/documentLibrary: webUrl mit %2C → ","; sonst nil
    public static func documentURL(for item: OneDriveItem) -> String?
    public static func encodeSegment(_ segment: String) -> String     // NFC, nur A–Z a–z 0–9 - . _ ~ unkodiert
    public static func officeURI(app: OfficeApp, documentURL: String, form: OfficeURIForm,
                                 origin: UUID, correlation: UUID, timestampMillis: Int64) -> String
}
public enum OneDriveFolderMatching {
    /// Pfade relativ zur OneDrive-Wurzel, die der freigegebene Ordner sein könnte – längster zuerst.
    public static func candidatePaths(localFolderComponents: [String], maxDepth: Int = 6) -> [String]
    /// Alle sichtbaren lokalen Namen (ohne „.“-Präfix) stehen auch online; leer = kein Treffer.
    public static func childrenMatch(local: [String], remote: [String]) -> Bool
    /// Graph-Pfad eines Elements: Teil nach "root:" in parentReference.path + "/" + name, NFC, ohne führenden "/".
    public static func rootRelativePath(of item: OneDriveItem) -> String?
}
```

- [ ] **Step 1: Tests schreiben**

```swift
let origin = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
let cid = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
@Test("Privates OneDrive: d.docs.live.net mit CID in Großbuchstaben (FR-5.1)") func personalDocumentURL() {
    let item = OneDriveItem(id: "ABC123DEF!101", name: "Vokabeln Unit 4.pptx", webUrl: "https://onedrive.live.com/x",
        parentReference: .init(driveId: "abc123def", driveType: "personal", path: "/drive/root:/Unterricht/8b"))
    #expect(OfficeAddress.documentURL(for: item) == "https://d.docs.live.net/ABC123DEF/Unterricht/8b/Vokabeln%20Unit%204.pptx")
}
@Test("Datei in der Wurzel und Pfad in /drives/<id>/root:-Form") func personalRootAndDrivesForm() {
    // path "/drive/root:" → ".../ABC123DEF/Arbeitsblatt%20Vokabeln.pdf"; path "/drives/abc123def/root:/Unterricht" → ".../ABC123DEF/Unterricht/..."
}
@Test("Umlaut wird NFC kodiert") func umlautEncodedAsNfc() {
    #expect(OfficeAddress.encodeSegment("U\u{0308}bung.docx") == "%C3%9Cbung.docx")
}
@Test("Schulkonto: webUrl, %2C wird Komma") func businessUsesWebUrl() {
    let item = OneDriveItem(id: "01X", name: "Vokabeln, Teil 1.pptx",
        webUrl: "https://example-my.sharepoint.com/personal/m_example_com/Documents/Unterricht/Vokabeln%2C%20Teil%201.pptx",
        parentReference: .init(driveId: "b!x", driveType: "business", path: "/drive/root:/Unterricht"))
    #expect(OfficeAddress.documentURL(for: item) == "https://example-my.sharepoint.com/personal/m_example_com/Documents/Unterricht/Vokabeln,%20Teil%201.pptx")
}
@Test("Unbekannter driveType: nil") func unknownDriveTypeIsNil()
@Test("Office-Adresse, dokumentierte Form") func documentedForm() {
    #expect(OfficeAddress.officeURI(app: .powerpoint, documentURL: "https://d.docs.live.net/ABC/a.pptx", form: .documented,
        origin: origin, correlation: cid, timestampMillis: 1_763_020_800_000) == "ms-powerpoint:ofe|u|https://d.docs.live.net/ABC/a.pptx")
}
@Test("Office-Adresse wie „In Desktop-App öffnen“, URL(string:) ändert sie nicht") func webStyleForm() {
    let uri = OfficeAddress.officeURI(app: .word, documentURL: "https://d.docs.live.net/ABC/a.docx", form: .webStyle,
        origin: origin, correlation: cid, timestampMillis: 1_763_020_800_000)
    #expect(uri == "ms-word:ofe%7Cor%7C00000000-0000-0000-0000-00000000000a_0%7Cct%7C1763020800000%7Ccid%7C00000000-0000-0000-0000-00000000000b%7Cu%7Chttps://d.docs.live.net/ABC/a.docx")
    #expect(URL(string: uri)?.absoluteString == uri)
}
// OneDriveFolderMatchingTests
@Test("Mac: Pfad hinter CloudStorage/OneDrive-… ist der einzige Kandidat") func macCloudStorageCandidate() {
    #expect(OneDriveFolderMatching.candidatePaths(localFolderComponents: ["Users", "x", "Library", "CloudStorage", "OneDrive-Personal", "Schule", "Unterricht"]) == ["Schule/Unterricht"])
}
@Test("Sonst Endungen, längste zuerst, höchstens maxDepth") func genericCandidates() {
    #expect(OneDriveFolderMatching.candidatePaths(localFolderComponents: ["var", "mobile", "File Provider Storage", "Schule", "Unterricht"], maxDepth: 3)
            == ["File Provider Storage/Schule/Unterricht", "Schule/Unterricht", "Unterricht"])
}
@Test("Namensvergleich: Teilmenge, NFC, ohne Groß-/Kleinschreibung, versteckte ignoriert") func childrenMatchRules() {
    #expect(OneDriveFolderMatching.childrenMatch(local: ["Vokabeln Unit 4.pptx", "8b", ".DS_Store"], remote: ["8B", "vokabeln unit 4.pptx", "Extra.docx"]))
    #expect(!OneDriveFolderMatching.childrenMatch(local: [], remote: ["a"]))
    #expect(!OneDriveFolderMatching.childrenMatch(local: ["a.pdf", "b.pdf"], remote: ["a.pdf"]))
    #expect(OneDriveFolderMatching.childrenMatch(local: ["U\u{0308}bung.docx"], remote: ["Übung.docx"]))
}
@Test("Pfad relativ zur Wurzel") func rootRelativePath()   // "/drive/root:/Unterricht/8b" + "a.pptx" → "Unterricht/8b/a.pptx"; path nil → nil
```

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: Implementieren.** `documentURL` privat: Pfadsegmente aus `rootRelativePath(of:)` je `encodeSegment`; `driveId.uppercased()`. Business: `webUrl` mit `replacingOccurrences(of: "%2C", with: ",", options: .caseInsensitive)`. `officeURI` webStyle: Felder `["ofe", "or", origin.uuidString.lowercased() + "_0", "ct", String(ts), "cid", correlation.uuidString.lowercased(), "u", documentURL]` mit `"%7C"` verbunden, Präfix `"<scheme>:"`. `candidatePaths`: steht `"CloudStorage"` gefolgt von einem Element mit Präfix `"OneDrive-"`, nur der Rest als ein Kandidat; sonst Endungen der Länge `min(maxDepth, count)` … 1.
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `feat(core): onedrive item, office address and folder matching`

---

### Task 6: Ordnerfreigaben speichern (App)

**Files:**
- Create: `Frontstage/Storage/FolderGrant.swift`, `Frontstage/Storage/FolderGrantStore.swift`
- Modify: `project.yml` – macOS-App-Ziel: Entitlements `com.apple.security.app-sandbox: true`, `com.apple.security.files.user-selected.read-only: true`, `com.apple.security.files.bookmarks.app-scope: true`, `com.apple.security.network.client: true`
- Test: `FrontstageTests/Storage/FolderGrantStoreTests.swift`

**Interfaces:**
- Consumes: `FolderGrantNaming`, `GrantLocation`, `StoragePath` (Task 1)
- Produces:
```swift
/// Ordnerfreigabe – nur auf diesem Gerät, nie gespiegelt (ADR-0002, ADR-0003).
struct FolderGrant: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String                 // gespiegelter Name, über den Materialverweise die Freigabe finden
    var bookmark: Data
    var displayPath: String          // nur zur Anzeige
    var oneDrivePath: String?        // relativ zur OneDrive-Wurzel, gesetzt von OneDriveService oder von Hand
}
enum FolderGrantError: Error, Equatable { case nameInUse, accessDenied, bookmarkFailed }
@MainActor final class FolderGrantStore {
    init(fileURL: URL = FolderGrantStore.defaultFileURL)          // Application Support/FolderGrants.json
    static var defaultFileURL: URL { get }
    private(set) var grants: [FolderGrant]
    func add(folderURL: URL, name: String) throws -> FolderGrant  // URL aus der Ordnerauswahl (security-scoped)
    func rename(id: UUID, to name: String) throws
    func setOneDrivePath(id: UUID, _ path: String?)
    func remove(id: UUID)
    /// Löst das Bookmark auf, erneuert es bei isStale; nil = Freigabe entzogen oder Ordner weg (nie throw).
    func resolvedURL(for grant: FolderGrant) -> URL?
    func grant(named name: String) -> FolderGrant?
    func grantLocations() -> [GrantLocation]                      // für StoragePath.relativeLocation
}
```

- [ ] **Step 1: Tests schreiben** (Ordner im temporären Verzeichnis des Simulators; dessen Bookmarks lösen ohne Ordnerauswahl auf)

```swift
@Test("Freigabe wird gespeichert und nach Neustart geladen") func addPersistsAndReloads()
    // add(folderURL: tmp/Unterricht, name: "Unterricht"); neuer Store auf derselben Datei → grants.count == 1, name "Unterricht", resolvedURL != nil
@Test("Gleicher Name zweimal: nameInUse") func duplicateNameThrows()
@Test("Datei ist von der Sicherung ausgeschlossen") func fileExcludedFromBackup()
    // resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true
@Test("Entfernter Ordner: resolvedURL nil statt Fehler (Review Focus 2)") func unresolvableBookmarkIsReportedNotThrown()
    // Ordner nach add löschen → resolvedURL(for:) == nil
@Test("Umbenennen und OneDrive-Pfad setzen bleiben nach Neustart") func renameAndOneDrivePathPersist()
@Test("grantLocations liefert normalisierte Komponenten") func grantLocationsAreNormalized()
```

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: Implementieren.** Bookmark erzeugen innerhalb `startAccessingSecurityScopedResource()`/`stop…` (Apple-Doku oben). iOS: `bookmarkData(options: .minimalBookmark, …)`, Auflösen `URL(resolvingBookmarkData:options: [], relativeTo: nil, bookmarkDataIsStale:)`. macOS: Erzeugen `[.withSecurityScope, .securityScopeAllowOnlyReadAccess]`, Auflösen `[.withSecurityScope]`. Plattformcode mit `#if os(iOS)`/`#if os(macOS)`. Speichern als JSON (`JSONEncoder`, atomar), danach `isExcludedFromBackup = true` setzen. Keine Aufrufe außer auf die eigene Datei in Application Support.
- [ ] **Step 4: Diff durchsehen** – Entitlements nur im macOS-Ziel; kein `read-write`.
- [ ] **Step 5: Commit** – `feat(storage): device-local folder grants with security-scoped bookmarks`

---

### Task 7: Verweis auflösen und Zustand lesen (App)

**Files:**
- Create: `Frontstage/Storage/FileFactsReader.swift`, `Frontstage/Storage/MaterialResolver.swift`, `Frontstage/Storage/ScopedFile.swift`
- Test: `FrontstageTests/Storage/MaterialResolverTests.swift`

**Interfaces:**
- Consumes: `FolderGrantStore` (Task 6), `StoragePath`, `MaterialReference` (Task 1), `FileFacts`, `AvailabilityClassifier` (Task 2)
- Produces:
```swift
enum FileFactsReader {
    /// Liest isUbiquitousItemKey, ubiquitousItemDownloadingStatusKey, ubiquitousItemIsDownloadingKey,
    /// ubiquitousItemDownloadingErrorKey; Datei fehlt → exists false.
    static func facts(at url: URL) -> FileFacts
}
struct ResolvedMaterial: Sendable { let fileURL: URL; let grantURL: URL }
@MainActor final class MaterialResolver {
    init(grants: FolderGrantStore)
    /// Freigabe-URL + Pfad; fehlt eine Komponente unter genau diesem Namen, Nachschlagen per
    /// StoragePath.matchName im Ordnerinhalt (NFC/Groß-Klein, Review Focus 1). nil = löst nicht auf.
    func resolve(_ reference: MaterialReference) -> ResolvedMaterial?
    func availability(of reference: MaterialReference, isOnline: Bool) -> MaterialAvailability
    /// Öffnet den Zugriff (startAccessing auf grantURL) und hält ihn, bis close() oder deinit.
    func open(_ reference: MaterialReference) -> ScopedFile?
    /// Datei aus der Ordnerauswahl → Verweis; nil = außerhalb freigegebener Ordner.
    func reference(forPickedFile url: URL) -> MaterialReference?
}
/// Lesender Zugriff auf eine Datei der Ablage für Anzeige (Teilplan 06) und Tafel-Vorlage (Teilplan 07).
@MainActor final class ScopedFile {
    let url: URL
    let reference: MaterialReference
    func close()
}
```

- [ ] **Step 1: Tests schreiben** (temporäre Freigabe „Unterricht“ mit Datei `8b/Arbeitsblatt Vokabeln.pdf`)

```swift
@Test("Vorhandene lokale Datei: auf dem Gerät, aktuell") func localFileIsOnDevice()     // .onDevice(isCurrent: true)
@Test("Datei fehlt: nicht verfügbar, fileMissing (AK-9-Gegenfall)") func missingFileIsUnavailable()
@Test("Unbekannter Freigabename: grantMissing (Review Focus 2)") func unknownGrantNameIsGrantMissing()
@Test("NFD-Name auf der Platte löst NFC-Verweis auf (Review Focus 1)") func resolvesNfdNameOnDisk()
    // Datei angelegt als "U\u{0308}bung.docx", Verweis relativePath "Übung.docx" → resolve != nil
@Test("Gewählte Datei innerhalb der Freigabe ergibt Verweis mit Dateiart") func pickedFileBecomesReference()
    // → grantName "Unterricht", relativePath "8b/Arbeitsblatt Vokabeln.pdf", displayName "Arbeitsblatt Vokabeln", fileKind .pdf
@Test("Gewählte Datei außerhalb: nil") func pickedFileOutsideGrantsIsNil()
@Test("ScopedFile.close beendet den Zugriff nur einmal") func scopedFileClosesOnce()   // close() zweimal ohne Absturz
```

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: Implementieren.** `reference(forPickedFile:)`: `url.standardizedFileURL.resolvingSymlinksInPath().path` → `StoragePath.normalizedComponents` → `relativeLocation(ofFile:in: grants.grantLocations())`; `displayName` = Dateiname ohne Endung. Ressourcenwerte im Zugriff der Freigabe lesen. `ScopedFile` merkt sich, ob `startAccessing…` `true` lieferte, und ruft `stop…` genau einmal.
- [ ] **Step 4: Diff durchsehen** – Lesen nur über Ressourcenwerte und `contentsOfDirectory`, kein Schreibaufruf.
- [ ] **Step 5: Commit** – `feat(storage): resolve material references with availability`

---

### Task 8: Netzstand und Bereithalten (App, NFR-1)

**Files:**
- Create: `Frontstage/Storage/NetworkMonitor.swift`, `Frontstage/Storage/Prefetcher.swift`, `Frontstage/Storage/MaterialReferenceStore.swift`
- Test: `FrontstageTests/Storage/PrefetcherTests.swift`

**Interfaces:**
- Consumes: `PrefetchPlanner` (Task 4), `MaterialResolver` (Task 7)
- Produces:
```swift
/// Erfüllt Teilplan 02 (SwiftData); Tests nutzen eine Attrappe.
@MainActor protocol MaterialReferenceStore: AnyObject {
    func links(for keys: [LessonKey]) -> [(key: LessonKey, reference: MaterialReference)]
    func mirroredGrantNames() -> Set<String>
    /// Ersetzt an allen Zuordnungen mit diesem alten Ort den Verweis; Zuordnungen und Stiftnotizen bleiben.
    func replaceReferences(atLocation locationKey: String, with reference: MaterialReference)
}
@MainActor @Observable final class NetworkMonitor {
    private(set) var isOnline: Bool
    var onBecameOnline: (() -> Void)?
    func start()                                         // NWPathMonitor, status == .satisfied
}
/// Stößt das Herunterladen an; austauschbar für Tests.
protocol FileDownloading: Sendable { func requestDownload(of url: URL) async }
struct SystemFileDownloader: FileDownloading           // ubiquitär: FileManager.startDownloadingUbiquitousItem(at:);
                                                      // sonst koordiniertes Lesen (NSFileCoordinator, .withoutChanges) außerhalb des Hauptthreads
@MainActor final class Prefetcher {
    init(resolver: MaterialResolver, store: any MaterialReferenceStore, downloader: any FileDownloading)
    /// Liefert die angestoßenen Verweise (für Zustandsaktualisierung und Tests).
    func prefetch(today: CalendarDay, timetable: Timetable, nonTeachingPeriods: [NonTeachingPeriod], changes: [ScheduleChange]) async -> [MaterialReference]
    func prefetch(_ references: [MaterialReference]) async        // beim Zuordnen
}
```

- [ ] **Step 1: Tests schreiben** (Attrappen `FakeReferenceStore`, `RecordingDownloader`; Freitag 13.11.2026 wie Task 4)

```swift
@Test("Bereithalten fordert die Dateien von heute und vom nächsten Unterrichtstag an (NFR-1)") func prefetchRequestsTodayAndNext()
    // Links: Fr 8b „Arbeitsblatt Vokabeln.pdf“, Mo 7a „Vokabeln Unit 4.pptx“, Mi 9c „Übung.docx“ → angefordert: genau die ersten beiden URLs
@Test("Bereits aktuelle Dateien werden nicht erneut angefordert") func currentFilesAreSkipped()
    // lokale (nicht ubiquitäre) Datei → onDevice(true) → kein requestDownload
@Test("Nicht auflösbare Verweise werden übersprungen, ohne abzubrechen") func unresolvedReferencesAreSkipped()
```

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: Implementieren.** Angefordert wird, wenn `availability` `.downloading` oder `.onDevice(isCurrent: false)` ist. `SystemFileDownloader` hält den Zugriff der Freigabe während des Aufrufs. Quelle zum koordinierten Lesen: Apple-Doku oben („Use a file coordinator to perform read … operations“); dass es bei Fremdanbietern das Herunterladen auslöst, ist am Gerät zu belegen (Geräte-Checkliste AK-17, AK-19).
- [ ] **Step 4: Diff durchsehen** – `NWPathMonitor` auf eigener `DispatchQueue`, Zustandsänderung per `Task { @MainActor in … }`.
- [ ] **Step 5: Commit** – `feat(storage): network monitor and prefetching for today and next teaching day`

---

### Task 9: Microsoft-Anmeldung, Graph, OneDrive-Ordnererkennung (App, FR-5.1)

**Files:**
- Create: `Frontstage/Storage/OneDrive/MicrosoftAccount.swift`, `GraphClient.swift`, `OneDriveService.swift`
- Modify: `project.yml` – `packages: MSAL: { url: https://github.com/AzureAD/microsoft-authentication-library-for-objc, majorVersion: 2.0.0 }` (beim Bau auf die dann aktuelle 2.x exakt pinnen), Abhängigkeit `- package: MSAL` in beiden App-Zielen; Info.plist-Eigenschaften beider Ziele: `MSALClientID: $(MSAL_CLIENT_ID)`, `CFBundleURLTypes` mit Schema `msauth.$(PRODUCT_BUNDLE_IDENTIFIER)`; nur iOS: `LSApplicationQueriesSchemes: [msauthv2, msauthv3, ms-powerpoint, ms-word, ms-excel]`; Build-Einstellung `MSAL_CLIENT_ID: ""` als Vorgabe
- Modify: `.github/workflows/ci.yml` – `xcodebuild … MSAL_CLIENT_ID="${{ secrets.MSAL_CLIENT_ID }}"` (leer, wenn Secret fehlt)
- Test: `FrontstageTests/Storage/GraphClientTests.swift`, `OneDriveServiceTests.swift`

**Interfaces:**
- Consumes: `OneDriveItem`, `OneDriveFolderMatching`, `OfficeAddress` (Task 5), `FolderGrantStore` (Task 6)
- Produces:
```swift
#if os(iOS)
typealias AuthPresentationAnchor = UIViewController
#else
typealias AuthPresentationAnchor = NSViewController
#endif
enum MicrosoftAccountError: Error, Equatable { case notConfigured, interactionRequired, cancelled, failed(String) }
/// Hülle um MSAL (`@preconcurrency import MSAL`). Token-Cache im privaten Schlüsselbund:
/// MSALCacheConfig.keychainSharingGroup = Bundle-ID (NFR-4).
@MainActor @Observable final class MicrosoftAccount {
    var isConfigured: Bool { get }                    // MSALClientID nicht leer
    private(set) var signedInUsername: String?        // nur zur Anzeige in Einrichten (Teilplan 04)
    var isSignedIn: Bool { get }
    func signIn(anchor: AuthPresentationAnchor) async throws
    func signOut() async                              // Konto aus dem MSAL-Cache entfernen
    func accessToken() async throws -> String         // still; wirft .interactionRequired
    static func handleRedirect(_ url: URL) -> Bool    // MSALPublicClientApplication.handleMSALResponse, aus .onOpenURL
    static let scopes = ["Files.Read"]
    static let authority = "https://login.microsoftonline.com/common"
}
protocol AccessTokenProviding: Sendable { func accessToken() async throws -> String }
struct GraphClient: Sendable {
    init(tokens: any AccessTokenProviding, session: URLSession = .shared)
    /// GET /v1.0/me/drive/root:/{path}?$select=id,name,webUrl,parentReference ; 404 → nil
    func item(atRootPath path: String) async throws -> OneDriveItem?
    /// GET /v1.0/drives/{driveID}/items/{itemID}?$select=id,name,webUrl,parentReference ; 404 → nil
    func item(driveID: String, itemID: String) async throws -> OneDriveItem?
    /// GET /v1.0/me/drive/root:/{path}:/children?$select=name ; 404 → nil (eine Seite genügt für den Vergleich)
    func childNames(atRootPath path: String) async throws -> [String]?
}
@MainActor final class OneDriveService {
    init(account: MicrosoftAccount, graph: GraphClient, grants: FolderGrantStore, resolver: MaterialResolver)
    /// Für jede Freigabe ohne oneDrivePath: Kandidaten probieren (Task 5), erster Treffer mit childrenMatch → setOneDrivePath.
    func detectOneDriveFolders() async
    /// Element zum Verweis: über gespeicherte Kennung, sonst über oneDrivePath der Freigabe + relativePath.
    /// Ergebnis wird im Sitzungsspeicher gehalten; neue Kennungen gibt es über `resolvedIDs` zurück.
    func item(for reference: MaterialReference) async throws -> OneDriveItem?
}
```
Pfade in Graph-Adressen je Segment mit `OfficeAddress.encodeSegment` kodieren; Header `Authorization: Bearer <token>`.

- [ ] **Step 1: Tests schreiben** (URLProtocol-Attrappe `StubURLProtocol`, Antworten als JSON-Zeichenketten in den Tests; `FakeTokens` liefert „test-token“)

```swift
@Test("Element wird decodiert und mit Bearer-Token abgefragt (FR-5.1)") func itemDecodesAndSendsBearer()
    // Antwort {"id":"01ABC","name":"Vokabeln Unit 4.pptx","webUrl":"https://example-my.sharepoint.com/personal/m_example_com/Documents/Unterricht/Vokabeln%20Unit%204.pptx",
    //          "parentReference":{"driveId":"b!x","driveType":"business","path":"/drive/root:/Unterricht"}}
    // #expect(request.url == "https://graph.microsoft.com/v1.0/me/drive/root:/Unterricht/Vokabeln%20Unit%204.pptx?$select=id,name,webUrl,parentReference")
    // #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
@Test("404 ergibt nil, 500 wirft") func notFoundIsNilServerErrorThrows()
@Test("Ordnererkennung: erster Kandidat fehlt, zweiter passt → oneDrivePath gesetzt") func detectsOneDriveFolder()
    // Freigabe-Komponenten […, "Schule", "Unterricht"]; root:/…/Schule/Unterricht → 404; root:/Schule/Unterricht:/children → Namen der lokalen Dateien
    // → grants.grant(named: "Unterricht")?.oneDrivePath == "Schule/Unterricht"
@Test("Gleicher Pfad, andere Dateien: kein OneDrive-Ordner") func differentChildrenAreNotMatched()
@Test("Nicht angemeldet: keine Graph-Anfrage") func signedOutMakesNoRequests()
```

- [ ] **Step 2: Diff durchsehen** – MSAL-Aufrufe nur in `MicrosoftAccount`; `MicrosoftAccount` erfüllt `AccessTokenProviding` über eine `Sendable`-Hülle, die auf den Hauptakteur springt.
- [ ] **Step 3: Implementieren.** MSAL gemäß Quellen oben: `MSALPublicClientApplicationConfig(clientId:redirectUri: "msauth.\(Bundle.main.bundleIdentifier!)://auth", authority: try MSALAADAuthority(url:))`, `cacheConfig.keychainSharingGroup = Bundle.main.bundleIdentifier`; interaktiv `MSALInteractiveTokenParameters(scopes:webviewParameters: MSALWebviewParameters(authPresentationViewController: anchor))`; still `MSALSilentTokenParameters(scopes:account:)`; Konto über `account(forIdentifier:)` mit der gespeicherten Kennung (`UserDefaults`, nur die Konto-Kennung, kein Token); Abmelden mit `remove(_:)` des Kontos. Nach erfolgreichem `signIn` `OneDriveService.detectOneDriveFolders()` anstoßen (über Rückruf in `StorageService`, Task 11). Rückruf-Blöcke mit `withCheckedThrowingContinuation`.
- [ ] **Step 4: Diff durchsehen** – kein Token in Logs, `UserDefaults` oder Dateien; einzige Hosts `graph.microsoft.com` und die MSAL-Authority (NFR-2).
- [ ] **Step 5: Commit** – `feat(onedrive): MSAL sign-in, graph client and onedrive folder detection`

---

### Task 10: Übergabe an die zuständige App (App, FR-5)

Design-Takt: keiner (nur Systemdialoge: „Öffnen in …“-Menü des Systems; kein eigenes Bedienelement)

**Files:**
- Create: `Frontstage/Storage/DocumentHandOff.swift`
- Test: `FrontstageTests/Storage/DocumentHandOffTests.swift`

**Interfaces:**
- Consumes: `ScopedFile` (Task 7), `OfficeApp` (Task 1), `AuthPresentationAnchor` (Task 9)
- Produces:
```swift
/// Wo das „Öffnen in …“-Menü am Tablet erscheint. Teilplan 04 liefert es aus der angetippten Zeile.
struct HandOffAnchor { 
    #if os(iOS)
    weak var view: UIView?; var rect: CGRect
    #endif
    init() /* macOS */ 
}
@MainActor protocol DocumentHandingOff {
    /// Datei an die zuständige App übergeben (Öffnen am Ort, keine Kopie). true = übergeben/Menü gezeigt.
    func handOff(_ file: ScopedFile, anchor: HandOffAnchor) async -> Bool
    /// Office-Adresse übergeben; nil = keine Antwort innerhalb von `limit`.
    func openOfficeURI(_ uri: String, limit: Duration) async -> Bool?
    func isInstalled(_ app: OfficeApp) -> Bool
}
@MainActor final class SystemDocumentHandOff: DocumentHandingOff
/// SwiftUI-Hilfe: liefert den UIView/UIViewController unter einer Zeile als Anker (UIViewRepresentable / NSViewRepresentable).
struct HandOffAnchorReader: View   // init(onResolve: @escaping (HandOffAnchor, AuthPresentationAnchor) -> Void)
```
iOS: `UIDocumentInteractionController(url:)` + `presentOpenInMenu(from:in:animated:)`; der Controller und der `ScopedFile`-Zugriff bleiben gehalten, bis `documentInteractionController(_:didEndSendingToApplication:)` oder `documentInteractionControllerDidDismissOpenInMenu(_:)` kommt. Office-Adresse: `UIApplication.shared.open(_:options:completionHandler:)`, Rennen gegen `limit`. `isInstalled`: `canOpenURL(URL(string: "\(app.scheme):")!)` (dafür `LSApplicationQueriesSchemes` aus Task 9). macOS: `NSWorkspace.shared.open(_:configuration:)` für Datei und Adresse; `isInstalled`: `NSWorkspace.shared.urlForApplication(toOpen:)` != nil.

- [ ] **Step 1: Tests schreiben**

```swift
@Test("Office-Adresse ohne Antwort innerhalb der Frist ergibt nil") func officeURITimesOut()
    // SystemDocumentHandOff mit eingespeister Öffnen-Funktion, die nie antwortet; limit .milliseconds(50) → nil
@Test("Abgelehnte Office-Adresse ergibt false") func officeURIRejected()
```
Dafür bekommt `SystemDocumentHandOff` einen internen Initialisierer `init(openURL: @escaping @MainActor (URL) async -> Bool)`; der öffentliche nutzt die Systemfunktion.

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: Implementieren** wie oben, `#if os(iOS)`/`#if os(macOS)` in einer Datei.
- [ ] **Step 4: Diff durchsehen** – keine Kopie der Datei (kein `copyItem`, kein `asCopy: true`).
- [ ] **Step 5: Commit** – `feat(storage): hand off files and office addresses to the owning app`

---

### Task 11: Fassade `StorageService` – Freigaben, Neu verknüpfen, Öffnen, Bereithalten (App)

**Files:**
- Create: `Frontstage/Storage/StorageService.swift`
- Test: `FrontstageTests/Storage/StorageServiceTests.swift`

**Interfaces:**
- Consumes: alles aus Task 1–10
- Produces (für Teilplan 04, 06, 07):
```swift
enum RelinkResult: Equatable { case relinked(MaterialReference), outsideGrants }
enum OpenOutcome {
    case handedOff                       // an die zuständige App übergeben
    case openedAsCloudDocument           // FR-5.1
    case showInViewer(ScopedFile)        // Teilplan 06 zeigt an und ruft close()
    case waitingForDownload              // öffnet von selbst, sobald die Datei da ist
    case unavailable(UnavailableReason)  // Oberfläche bietet „Neu verknüpfen“ an
    case failed
}
@MainActor @Observable final class StorageService {
    init(grants: FolderGrantStore, references: any MaterialReferenceStore, resolver: MaterialResolver,
         prefetcher: Prefetcher, network: NetworkMonitor, account: MicrosoftAccount, oneDrive: OneDriveService,
         handOff: any DocumentHandingOff, uriForm: OfficeURIForm = .webStyle)
    private(set) var grants: [FolderGrant]
    /// Zustand je Ort (Schlüssel MaterialReference.locationKey) für die Tagesansicht.
    private(set) var availability: [String: MaterialAvailability]
    /// Gesetzt nach einer Cloud-Übergabe; Teilplan 04 fragt beim Zurückkehren `offerOpenWithoutAutoSave(now:)`.
    private(set) var lastCloudHandOver: (reference: MaterialReference, at: ContinuousClock.Instant)?
    func suggestedGrantName(for folderURL: URL) -> GrantNameSuggestion
    func addGrant(folderURL: URL, name: String) async throws -> FolderGrant   // danach detectOneDriveFolders, falls angemeldet
    func renameGrant(id: UUID, to name: String) throws
    func removeGrant(id: UUID)
    func reference(forPickedFile url: URL) -> MaterialReference?             // Zuordnen (04), Tafel-Vorlage (07)
    func relink(_ old: MaterialReference, toPickedFile url: URL) -> RelinkResult
    func refreshAvailability(for references: [MaterialReference])
    func open(_ reference: MaterialReference, anchor: HandOffAnchor) async -> OpenOutcome
    func openWithoutAutoSave(_ reference: MaterialReference, anchor: HandOffAnchor) async -> OpenOutcome   // Übergabe erzwingen
    func offerOpenWithoutAutoSave(now: ContinuousClock.Instant) -> MaterialReference?
    func readableFile(for reference: MaterialReference) -> ScopedFile?       // Anzeige (06) und Vorlage (07), ohne Weg-Entscheidung
    func prepareForTeaching(today: CalendarDay, timetable: Timetable, nonTeachingPeriods: [NonTeachingPeriod], changes: [ScheduleChange]) async
    func didAssign(_ references: [MaterialReference]) async                   // Bereithalten beim Zuordnen
}
```
Ablauf `open`: `OpenContext` bauen (Zustand vom Resolver, `network.isOnline`, `account.isSignedIn`, `handOff.isInstalled`, `documentURL` nur wenn der Verweis eine OneDrive-Kennung hat oder seine Freigabe einen `oneDrivePath` – Element über `oneDrive.item(for:)` mit Frist `CloudOpenPolicy.preparationLimit`), `OpenRouter.route` anwenden; `.officeCloud` → `OfficeAddress.officeURI(…, form: uriForm, origin: UUID(), correlation: UUID(), timestampMillis: jetzt)` → `handOff.openOfficeURI(_, limit: CloudOpenPolicy.handOverLimit)`; Ergebnis über `CloudOpenPolicy.afterHandOver` → bei `.fallBackToHandOff` Übergabe der Datei. Neue OneDrive-Kennungen schreibt `open` und `prepareForTeaching` per `references.replaceReferences(atLocation:with:)` zurück (gespiegelt, damit das zweite Gerät nicht erneut sucht). `.waitForDownload` → Herunterladen anfordern, Zustand alle 2 s neu lesen, bei `.onDevice` den Zielweg ausführen (höchstens 120 s, danach `.failed`).

- [ ] **Step 1: Tests schreiben** (Attrappen für Store, Downloader, `DocumentHandingOff`, Token; temporäre Freigabe „Unterricht“)

```swift
@Test("PDF öffnet in der Anzeige mit offenem Zugriff (FR-6)") func pdfOpensViewer()
    // open → .showInViewer(file), file.url.lastPathComponent == "Arbeitsblatt Vokabeln.pdf"
@Test("Präsentation ohne Anmeldung wird übergeben (FR-5, AK-11)") func presentationIsHandedOff()
    // spy.handOffCount == 1, kein openOfficeURI
@Test("Cloud-Übergabe abgelehnt: Rückfall auf Übergabe der Datei (FR-5.1)") func rejectedCloudFallsBackToHandOff()
    // angemeldet, online, oneDrivePath gesetzt, Graph-Attrappe liefert Element; spy.openOfficeURI → false → handOffCount == 1, Ergebnis .handedOff
@Test("Graph antwortet nicht binnen Frist: Übergabe") func slowPreparationFallsBack()
    // Frist im Test über init-Parameter auf .milliseconds(50) verkürzt (interner init)
@Test("Cloud-Übergabe angenommen: Rückkehr binnen 60 s bietet Öffnen ohne AutoSpeichern an") func acceptedCloudOffersFallbackOnReturn()
@Test("Neu verknüpfen ersetzt den Ort an allen Zuordnungen (ADR-0003)") func relinkReplacesAllAtOldLocation()
    // store.replaced == [(oldLocationKey, neuer Verweis "8b/Arbeitsblatt Vokabeln neu.pdf")]
@Test("Neu verknüpfen mit Datei außerhalb der Freigaben: outsideGrants") func relinkOutsideGrants()
@Test("Gefundene OneDrive-Kennung wird zurückgeschrieben") func resolvedOneDriveIDIsStored()
@Test("Freigabe mit gespiegeltem Namen wird vorgeschlagen (Area ablage, zweites Gerät)") func suggestsMirroredGrantName()
    // store.mirroredGrantNames == ["Unterricht"], keine lokale Freigabe → suggestion.matchesMirroredName
```

- [ ] **Step 2: Diff durchsehen.**
- [ ] **Step 3: Implementieren** gemäß Ablauf. Zeitmessung mit `ContinuousClock`; Fristen als Rennen in `withTaskGroup`.
- [ ] **Step 4: Diff durchsehen** – Fassade enthält keine Entscheidungslogik, die nicht aus `OpenRouter`/`CloudOpenPolicy`/`PrefetchPlanner` kommt.
- [ ] **Step 5: Commit** – `feat(storage): storage service facade for open, relink and prefetch`

---

### Task 12: CI-Lauf (workflow_dispatch) und Ergebnis prüfen

**Files:** keine Änderungen (nur bei roten Tests: Korrektur in der Datei der betroffenen Aufgabe, eigener Commit)

- [ ] **Step 1: Gesamtdiff des Teilplans durchsehen** – `git diff main...HEAD -- Packages Frontstage FrontstageTests project.yml .github`: Swift 6 strikt (`Sendable` an allen Typen, die Akteur-Grenzen überqueren; `@preconcurrency import MSAL`), `#if os(…)` vollständig, kein Schreibaufruf auf Ablage-URLs, keine echten Namen oder Domains.
- [ ] **Step 2: Branch pushen und CI anstoßen**

```bash
git push -u origin <branch>
gh workflow run ci.yml --ref <branch>
gh run list --workflow ci.yml --branch <branch> --limit 1
gh run watch <run-id>
```
Expected: Job „core“ (`swift test --package-path Packages/FrontstageCore`) grün mit allen Tests aus Task 1–5; Job „app“ (`xcodebuild test` im iPad-Simulator) grün mit allen Tests aus Task 6–11; macOS-Ziel baut.
- [ ] **Step 3: Bei Rot** – Log mit `gh run view <run-id> --log-failed` lesen, Ursache mit superpowers:systematic-debugging klären, korrigieren, Schritt 2 einmal wiederholen.

---

### Task 13: Geräte-Checkliste (Mensch mit iPad, Mac, PowerPoint, Microsoft-365-Konto)

Kein Code. Ergebnisse hier eintragen; ein Fehlschlag wird als Befund an die zuständige Aufgabe zurückgegeben.

| AK / Frage | Aufbau | Handlung | Erwartet | Ergebnis |
|---|---|---|---|---|
| AK-9 (FR-3.4) | Material „Vokabeln Unit 4.pptx“ zugeordnet, per „Für 8b übernehmen“ übernommen und „in die nächste Stunde“ geschoben (Oberfläche aus 04) | Datei am Mac in der Ablage ändern; jede Zuordnung öffnen; Dateien im Ordner zählen | jede Zuordnung öffnet den geänderten Stand; Dateianzahl unverändert | ☐ |
| AK-11 (FR-5) | „Vokabeln Unit 4.pptx“ in iCloud Drive zugeordnet, PowerPoint installiert, nicht bei Microsoft angemeldet | in der Tagesansicht antippen, PowerPoint im Menü wählen, Folie ändern, PowerPoint schließen; am Mac öffnen | öffnet bearbeitbar in PowerPoint (nicht „Kopie speichern“); Änderung steht in der Ablage | ☐ |
| AK-12 (FR-5.1, Q-18) | dieselbe Datei in OneDrive; in Einrichten bei Microsoft angemeldet; Freigabe als OneDrive-Ordner erkannt | antippen, auf einer Folie zeichnen; am Mac in derselben Datei nachsehen | PowerPoint zeigt AutoSpeichern; Zeichnung binnen einer Minute am Mac sichtbar | ☐ webStyle ☐ documented |
| AK-12-Rückfall | wie AK-12, PowerPoint gelöscht bzw. Flugmodus | antippen | Übergabe der Datei (bzw. ohne PowerPoint: Menü), kein Warten über 5 s | ☐ |
| AK-17 (NFR-1) | Material des Tages morgens im WLAN bereitgehalten (App geöffnet, Zustand „auf dem Gerät“); je ein PDF und eine PPTX aus iCloud Drive und OneDrive; danach WLAN aus | jedes Material antippen, Zeit messen | jedes öffnet in unter 3 s; OneDrive-PPTX trotz Anmeldung per Übergabe | ☐ |
| AK-19 (NFR-3) | je ein Material aus iCloud Drive, OneDrive (Dateien-App) und Google Drive, jeweils Ordner freigegeben | zuordnen und öffnen; Zustand vor und nach dem Bereithalten ablesen | alle drei öffnen; Zustand wechselt von „wird geladen“ auf „auf dem Gerät“ | ☐ iCloud ☐ OneDrive ☐ Google |
| Zweites Gerät (Area daten, Betrieb) | Zuordnungen am iPad angelegt, Mac mit derselben Apple-ID | am Mac den Ordner freigeben und dem Namen „Unterricht“ zuordnen | alle Verweise lösen am Mac auf | ☐ |
| Freigabe entzogen | iPad: Einstellungen > Datenschutz > Dateien und Ordner, Zugriff entziehen | Tagesansicht öffnen | Material „nicht verfügbar“, „Neu verknüpfen“ angeboten, kein Absturz | ☐ |
| Mac (FR-5) | „Vokabeln Unit 4.pptx“ aus iCloud Drive am Mac | antippen | öffnet in PowerPoint am Ort, bearbeitbar | ☐ |

---

## Abdeckung

| Anforderung / AK | Wo |
|---|---|
| FR-3.4 Zuordnen kopiert nie | Verweis statt Datei (Task 1, 7), keine Kopie bei Übergabe (Task 10); AK-9 Geräte-Checkliste |
| FR-5 Öffnen mit einem Tipp | Task 3, 10, 11; AK-11 Geräte-Checkliste (Oberfläche: Teilplan 04) |
| FR-5.1 AutoSpeichern bei OneDrive | Task 5, 9, 11; AK-12 Geräte-Checkliste |
| NFR-1 sofort und aktuell | Task 2, 4, 8, 11; AK-17 Geräte-Checkliste |
| NFR-3 jede Ablage | Task 6–8 über die Dateien-Schnittstelle; AK-19 Geräte-Checkliste |
| NFR-2 keine eigenen Server | nur Microsoft-Hosts (Task 9); AK-18 prüft Teilplan 04 im Gesamtablauf |
| ADR-0003 Neu verknüpfen | Task 7, 11 (Oberfläche: Teilplan 04) |
| FR-6 Anzeige | nur Schnittstelle `OpenOutcome.showInViewer(ScopedFile)`; Anzeige baut Teilplan 06 |

Nicht in diesem Teilplan: Oberflächen für Einrichten > Ablage, Microsoft-Anmeldung, Zustandsanzeige und
„Neu verknüpfen“ in Tagesansicht und Vorbereiten (Teilplan 04); Anzeige von PDF und Bild (Teilplan 06);
Tafel-Vorlage aus der Ablage (Teilplan 07, nutzt `reference(forPickedFile:)` und `readableFile(for:)`).

## Abstimmungsbedarf

- **Teilplan 01:** braucht `CalendarDay.adding(days: Int) -> CalendarDay` (für `PrefetchPlanner`; in der Übersicht
  nicht festgelegt). `project.yml` und `ci.yml` werden hier
  ergänzt (MSAL-Paket, Info.plist-Schlüssel, macOS-Entitlements, Secret `MSAL_CLIENT_ID`) – Namen der
  App-Ziele aus 01 übernehmen.
- **Teilplan 02:** erfüllt `MaterialReferenceStore` (Task 8) auf SwiftData: `links(for:)`,
  `mirroredGrantNames()`, `replaceReferences(atLocation:with:)`. Erwartet wird ein Datensatz
  `MaterialReferenceRecord` (oder Felder am `MaterialLinkRecord`) mit `grantName: String = ""`,
  `relativePath: String = ""`, `displayName: String = ""`, `fileKind: String = "other"`,
  `oneDriveItemID: String?`, `oneDriveDriveID: String?` und Übersetzung ↔ `MaterialReference`.
  `FolderGrant` ist **kein** SwiftData-Modell (Datei in Application Support, Task 6) – Area daten führt
  die Ordnerfreigabe zwar in der Modelltabelle, aber als „nur lokal“.
- **Teilplan 04:** baut Einrichten > Ablage (Ordnerauswahl `UIDocumentPickerViewController(forOpeningContentTypes: [.folder])`
  bzw. `.fileImporter`, Namensvorschlag, OneDrive-Pfad von Hand setzen/löschen, Microsoft an/ab),
  Zustandsanzeige je Material aus `StorageService.availability`, „Neu verknüpfen“, das Angebot „ohne
  AutoSpeichern öffnen“, `.onOpenURL { MicrosoftAccount.handleRedirect($0) }` und den Aufruf von
  `prepareForTeaching` beim Aktivwerden und bei `NetworkMonitor.onBecameOnline`.
- **Teilplan 06:** nimmt `ScopedFile` entgegen, liest über `NSFileCoordinator` und ruft beim Schließen
  `close()`.
- **Teilplan 07:** Tafel-Vorlage aus der Ablage über `reference(forPickedFile:)` und `readableFile(for:)`.
- **Glossar (PRD, Spalte „Im Code“) – neue Begriffe zur Aufnahme:** Dateiart `FileKind`; Zustand des
  Materials (auf dem Gerät / wird geladen / nicht verfügbar) `MaterialAvailability`; Bereithalten
  `prefetch`; Neu verknüpfen `relink`; OneDrive-Zusatz `OneDriveService`; Microsoft-Anmeldung
  `MicrosoftAccount`; Office-Adresse `OfficeAddress`; Übergabe der Datei `handOff`. Technische Typen ohne
  Fachbedeutung (`OpenRoute`, `CloudOpenPolicy`, `FileFacts`, `ScopedFile`) brauchen keine Glossarzeile.
- **Neue offene Frage für das Architecture Doc** (nächste freie Nummer vor Vergabe prüfen, derzeit Q-32):
  Übergibt `UIDocumentInteractionController` auf iPadOS 26 eine PowerPoint-Datei aus einem
  Dateien-Anbieter zum Bearbeiten am Ort, oder nur lesend? Rückfall bei „nur lesend“ ist offen.

## Annahmen, die ein Mensch bestätigen sollte

- MSAL statt `ASWebAuthenticationSession` (Begründung oben) und die Berechtigung `Files.Read` mit
  Authority `common`; die App-Registrierung bei Microsoft legt der Entwickler an (ADR-0003, Kosten).
- Fristen 5 s / 10 s / 60 s und die automatische Übergabe als Rückfall (am Mac zeigte OneDrive Opener nach
  15 s ein Fenster; auf dem Tablet kann die App nicht nachsehen, ob PowerPoint geöffnet hat).
- Office-Adresse in der Form „In Desktop-App öffnen“ als Vorgabe; private OneDrive-Adresse
  `d.docs.live.net/<CID>` aus OneDrive Opener übernommen, für iPadOS ungeprüft (Q-18).
- OneDrive-Ordnererkennung über Pfad-Endungen und Namensvergleich, mit Setzen von Hand als Ausweg.
- Neu verknüpfen ersetzt den Ort an allen Zuordnungen mit demselben alten Ort.
- Ein lokal vorhandener, nicht aktueller Stand wird offline geöffnet und als „älterer Stand“ gekennzeichnet
  (statt gesperrt) – Wortlaut und Darstellung sind offene Gestaltungskategorie (Teilplan 04).
- Vorausschau für den nächsten Unterrichtstag höchstens 14 Tage.
