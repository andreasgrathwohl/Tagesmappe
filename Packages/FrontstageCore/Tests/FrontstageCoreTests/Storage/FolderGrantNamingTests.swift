import Testing
@testable import FrontstageCore

@Suite("FolderGrantNaming")
struct FolderGrantNamingTests {
  @Test("Ordnername passt zu gespiegeltem Namen ohne lokale Freigabe")
  func suggestsMirroredName() {
    #expect(
      FolderGrantNaming.suggestion(folderName: "Unterricht", localGrantNames: [], mirroredNames: ["Unterricht"])
        == GrantNameSuggestion(name: "Unterricht", matchesMirroredName: true))
  }

  @Test("Neuer Name ohne Bezug")
  func suggestsFolderName() {
    #expect(
      FolderGrantNaming.suggestion(folderName: "Englisch", localGrantNames: ["Unterricht"], mirroredNames: [])
        == GrantNameSuggestion(name: "Englisch", matchesMirroredName: false))
  }

  @Test("Gleicher Ordnername zweimal: Zähler ab 2 (Review Focus 5)")
  func appendsCounter() {
    #expect(
      FolderGrantNaming.suggestion(
        folderName: "Unterricht", localGrantNames: ["Unterricht", "Unterricht 2"],
        mirroredNames: ["Unterricht"]
      ).name == "Unterricht 3")
  }
}
