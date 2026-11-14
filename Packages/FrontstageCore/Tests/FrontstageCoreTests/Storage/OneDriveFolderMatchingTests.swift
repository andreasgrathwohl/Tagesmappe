import Testing
@testable import FrontstageCore

@Suite("OneDriveFolderMatching")
struct OneDriveFolderMatchingTests {
  @Test("Mac: Pfad hinter CloudStorage/OneDrive-… ist der einzige Kandidat")
  func macCloudStorageCandidate() {
    #expect(
      OneDriveFolderMatching.candidatePaths(localFolderComponents: ["Users", "x", "Library", "CloudStorage", "OneDrive-Personal", "Schule", "Unterricht"])
        == ["Schule/Unterricht"])
  }

  @Test("Sonst Endungen, längste zuerst, höchstens maxDepth")
  func genericCandidates() {
    #expect(
      OneDriveFolderMatching.candidatePaths(localFolderComponents: ["var", "mobile", "File Provider Storage", "Schule", "Unterricht"], maxDepth: 3)
        == ["File Provider Storage/Schule/Unterricht", "Schule/Unterricht", "Unterricht"])
  }

  @Test("Namensvergleich: Teilmenge, NFC, ohne Groß-/Kleinschreibung, versteckte ignoriert")
  func childrenMatchRules() {
    #expect(OneDriveFolderMatching.childrenMatch(local: ["Vokabeln Unit 4.pptx", "8b", ".DS_Store"], remote: ["8B", "vokabeln unit 4.pptx", "Extra.docx"]))
    #expect(!OneDriveFolderMatching.childrenMatch(local: [], remote: ["a"]))
    #expect(!OneDriveFolderMatching.childrenMatch(local: ["a.pdf", "b.pdf"], remote: ["a.pdf"]))
    #expect(OneDriveFolderMatching.childrenMatch(local: ["U\u{0308}bung.docx"], remote: ["Übung.docx"]))
  }

  @Test("Pfad relativ zur Wurzel")
  func rootRelativePath() {
    let item = OneDriveItem(
      id: "1", name: "a.pptx", webUrl: "https://example.com/a",
      parentReference: .init(driveId: "d", driveType: "personal", path: "/drive/root:/Unterricht/8b"))
    #expect(OneDriveFolderMatching.rootRelativePath(of: item) == "Unterricht/8b/a.pptx")
    var noPath = item
    noPath.parentReference.path = nil
    #expect(OneDriveFolderMatching.rootRelativePath(of: noPath) == nil)
  }

  @Test("Graph liefert parentReference.path prozentkodiert: Pfad wird roh zurückgegeben")
  func rootRelativePathDecodesPercentEncoding() {
    let item = OneDriveItem(
      id: "1", name: "Übung.docx", webUrl: "https://example.com/a",
      parentReference: .init(driveId: "d", driveType: "personal", path: "/drive/root:/Klasse%208b/U%CC%88bungen"))
    #expect(OneDriveFolderMatching.rootRelativePath(of: item) == "Klasse 8b/Übungen/Übung.docx")
  }
}
