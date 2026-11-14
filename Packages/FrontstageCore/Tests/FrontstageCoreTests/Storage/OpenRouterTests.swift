import Testing
@testable import FrontstageCore

@Suite("OpenRouter")
struct OpenRouterTests {
  /// Baut einen Kontext; die Office-App folgt aus der Endung.
  private func context(
    kind: MaterialFileKind,
    ext: String,
    availability: MaterialAvailability = .onDevice(isCurrent: true),
    online: Bool = true,
    signedIn: Bool = false,
    installed: Bool = true,
    url: String? = nil
  ) -> OpenContext {
    OpenContext(
      fileKind: kind,
      officeApp: OfficeApp(fileExtension: ext),
      availability: availability,
      isOnline: online,
      isMicrosoftSignedIn: signedIn,
      isOfficeAppInstalled: installed,
      oneDriveDocumentURL: url
    )
  }

  private let sampleURL = "https://d.docs.live.net/ABC123/Unterricht/Vokabeln%20Unit%204.pptx"

  @Test("PDF auf dem Gerät öffnet in der eigenen Anzeige (FR-6)")
  func pdfOnDeviceOpensViewer() {
    #expect(OpenRouter.route(context(kind: .pdf, ext: "pdf")) == .viewer)
  }

  @Test("Bild wird geladen: warten, dann Anzeige")
  func imageDownloadingWaitsForViewer() {
    let c = context(kind: .image, ext: "png", availability: .downloading(progress: nil))
    #expect(OpenRouter.route(c) == .waitForDownload(then: .viewer))
  }

  @Test("Präsentation ohne Anmeldung: Übergabe (FR-5, AK-11)")
  func presentationWithoutSignInHandsOff() {
    #expect(OpenRouter.route(context(kind: .presentation, ext: "pptx", url: sampleURL)) == .handOff)
  }

  @Test("OneDrive-Präsentation mit Anmeldung online: Cloud-Dokument (FR-5.1, AK-12)")
  func signedInOnlineOneDriveOpensCloud() {
    let c = context(kind: .presentation, ext: "pptx", signedIn: true, url: sampleURL)
    #expect(OpenRouter.route(c) == .officeCloud(documentURL: sampleURL))
  }

  @Test("Cloud-Dokument auch, solange die lokale Kopie lädt")
  func cloudIgnoresLocalDownloading() {
    let c = context(
      kind: .presentation, ext: "pptx", availability: .downloading(progress: 0.3),
      signedIn: true, url: sampleURL)
    #expect(OpenRouter.route(c) == .officeCloud(documentURL: sampleURL))
  }

  @Test("Offline mit Anmeldung: sofort Übergabe (AK-17, Review Focus 4)")
  func offlineOfficeGoesStraightToHandOff() {
    let c = context(kind: .presentation, ext: "pptx", online: false, signedIn: true, url: sampleURL)
    #expect(OpenRouter.route(c) == .handOff)
  }

  @Test("Ohne OneDrive-Adresse: Übergabe")
  func missingDocumentURLHandsOff() {
    #expect(OpenRouter.route(context(kind: .presentation, ext: "pptx", signedIn: true)) == .handOff)
  }

  @Test("PowerPoint nicht installiert: Übergabe")
  func officeAppMissingHandsOff() {
    let c = context(kind: .presentation, ext: "pptx", signedIn: true, installed: false, url: sampleURL)
    #expect(OpenRouter.route(c) == .handOff)
  }

  @Test("Excel-Adresse mit 217 Zeichen: Übergabe; PowerPoint mit 256: Cloud, 257: Übergabe")
  func excelAddressOver216CharactersFallsBack() {
    func url(_ count: Int) -> String { String(repeating: "a", count: count) }
    let excel216 = context(kind: .spreadsheet, ext: "xlsx", signedIn: true, url: url(216))
    let excel217 = context(kind: .spreadsheet, ext: "xlsx", signedIn: true, url: url(217))
    let ppt256 = context(kind: .presentation, ext: "pptx", signedIn: true, url: url(256))
    let ppt257 = context(kind: .presentation, ext: "pptx", signedIn: true, url: url(257))
    #expect(OpenRouter.route(excel216) == .officeCloud(documentURL: url(216)))
    #expect(OpenRouter.route(excel217) == .handOff)
    #expect(OpenRouter.route(ppt256) == .officeCloud(documentURL: url(256)))
    #expect(OpenRouter.route(ppt257) == .handOff)
  }

  @Test("Keynote ist keine Office-Datei: Übergabe")
  func keynoteHandsOff() {
    let c = context(kind: .presentation, ext: "key", signedIn: true, url: sampleURL)
    #expect(OpenRouter.route(c) == .handOff)
  }

  @Test("Verweis löst nicht auf: nicht verfügbar mit Grund")
  func unresolvedIsUnavailable() {
    let c = context(kind: .pdf, ext: "pdf", availability: .unavailable(.fileMissing))
    #expect(OpenRouter.route(c) == .unavailable(.fileMissing))
  }
}
