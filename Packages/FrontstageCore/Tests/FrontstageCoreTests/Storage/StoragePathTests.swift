import Testing
@testable import FrontstageCore

@Suite("StoragePath")
struct StoragePathTests {
  @Test("/private vor var wird entfernt, NFC")
  func normalizedComponentsDropPrivate() {
    #expect(
      StoragePath.normalizedComponents("/private/var/mobile/U\u{0308}bung.docx")
        == ["var", "mobile", "Übung.docx"])
    #expect(StoragePath.normalizedComponents("/Users/x/Unterricht/") == ["Users", "x", "Unterricht"])
  }

  @Test("Punkte und doppelte Punkte werden aufgelöst")
  func dotsAreResolved() {
    #expect(StoragePath.normalizedComponents("/a/./b/../c//d") == ["a", "c", "d"])
  }

  @Test("Engste Freigabe gewinnt (Review Focus 3)")
  func longestGrantPrefixWins() {
    let grants = [
      GrantLocation(name: "Unterricht", components: ["Users", "x", "Unterricht"]),
      GrantLocation(name: "Englisch", components: ["Users", "x", "Unterricht", "Englisch"]),
    ]
    let loc = StoragePath.relativeLocation(
      ofFile: ["Users", "x", "Unterricht", "Englisch", "8b", "Arbeitsblatt Vokabeln.pdf"], in: grants)
    #expect(loc == RelativeLocation(folderGrantName: "Englisch", relativePath: "8b/Arbeitsblatt Vokabeln.pdf"))
  }

  @Test("Datei außerhalb jeder Freigabe oder die Freigabe selbst ergibt nil")
  func outsideOrFolderItselfIsNil() {
    let grants = [GrantLocation(name: "Unterricht", components: ["Users", "x", "Unterricht"])]
    #expect(StoragePath.relativeLocation(ofFile: ["Users", "x", "Downloads", "a.pdf"], in: grants) == nil)
    #expect(StoragePath.relativeLocation(ofFile: ["Users", "x", "Unterricht"], in: grants) == nil)
  }

  @Test("NFD-Datei passt zu NFC-Freigabe, Ergebnis NFC (Review Focus 1)")
  func nfdFileMatchesNfcGrant() {
    let grants = [GrantLocation(name: "Übungen", components: ["Users", "x", "Übungen"])]
    let loc = StoragePath.relativeLocation(
      ofFile: ["Users", "x", "U\u{0308}bungen", "U\u{0308}bung.docx"], in: grants)
    #expect(loc?.relativePath == "Übung.docx")
    #expect(loc?.relativePath.unicodeScalars.count == "Übung.docx".unicodeScalars.count)
  }

  @Test("Präfix ohne Groß-/Kleinschreibung")
  func prefixIsCaseInsensitive() {
    let grants = [GrantLocation(name: "Unterricht", components: ["Users", "x", "Unterricht"])]
    #expect(
      StoragePath.relativeLocation(ofFile: ["Users", "x", "unterricht", "a.pdf"], in: grants)?
        .folderGrantName == "Unterricht")
  }

  @Test("Relativer Pfad wird in Bestandteile zerlegt")
  func componentsOfRelativePath() {
    #expect(StoragePath.components(ofRelativePath: "8b/Arbeitsblatt.pdf") == ["8b", "Arbeitsblatt.pdf"])
    #expect(StoragePath.components(ofRelativePath: "a.pdf") == ["a.pdf"])
  }

  @Test("Namensabgleich: exakt vor NFC vor ohne Groß-/Kleinschreibung; mehrdeutig = nil")
  func matchNamePrefersExactThenNfc() {
    #expect(StoragePath.matchName("Übung.docx", among: ["U\u{0308}bung.docx", "x"]) == "U\u{0308}bung.docx")
    #expect(StoragePath.matchName("a.pdf", among: ["A.pdf", "a.pdf"]) == "a.pdf")
    #expect(StoragePath.matchName("A.PDF", among: ["a.pdf"]) == "a.pdf")
    #expect(StoragePath.matchName("A.PDF", among: ["a.pdf", "A.pdf"]) == nil)
    #expect(StoragePath.matchName("fehlt.pdf", among: ["a.pdf"]) == nil)
  }
}
