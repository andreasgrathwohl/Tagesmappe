import Foundation
import Testing
@testable import FrontstageCore

@Suite("OfficeAddress")
struct OfficeAddressTests {
  let origin = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
  let cid = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!

  @Test("Privates OneDrive: d.docs.live.net mit CID in Großbuchstaben (FR-5.1)")
  func personalDocumentURL() {
    let item = OneDriveItem(
      id: "ABC123DEF!101", name: "Vokabeln Unit 4.pptx", webUrl: "https://onedrive.live.com/x",
      parentReference: .init(driveId: "abc123def", driveType: "personal", path: "/drive/root:/Unterricht/8b"))
    #expect(OfficeAddress.documentURL(for: item) == "https://d.docs.live.net/ABC123DEF/Unterricht/8b/Vokabeln%20Unit%204.pptx")
  }

  @Test("Privates OneDrive: prozentkodierter Elternpfad wird nicht doppelt kodiert (FR-5.1)")
  func personalDocumentURLWithEncodedParentPath() {
    let item = OneDriveItem(
      id: "ABC123DEF!102", name: "Vokabeln Unit 4.pptx", webUrl: "https://onedrive.live.com/x",
      parentReference: .init(driveId: "abc123def", driveType: "personal", path: "/drive/root:/Klasse%208b"))
    #expect(OfficeAddress.documentURL(for: item) == "https://d.docs.live.net/ABC123DEF/Klasse%208b/Vokabeln%20Unit%204.pptx")
  }

  @Test("Datei in der Wurzel und Pfad in /drives/<id>/root:-Form")
  func personalRootAndDrivesForm() {
    let inRoot = OneDriveItem(
      id: "1", name: "Arbeitsblatt Vokabeln.pdf", webUrl: "https://onedrive.live.com/x",
      parentReference: .init(driveId: "abc123def", driveType: "personal", path: "/drive/root:"))
    #expect(OfficeAddress.documentURL(for: inRoot) == "https://d.docs.live.net/ABC123DEF/Arbeitsblatt%20Vokabeln.pdf")
    let drives = OneDriveItem(
      id: "2", name: "a.pdf", webUrl: "https://onedrive.live.com/x",
      parentReference: .init(driveId: "abc123def", driveType: "personal", path: "/drives/abc123def/root:/Unterricht"))
    #expect(OfficeAddress.documentURL(for: drives) == "https://d.docs.live.net/ABC123DEF/Unterricht/a.pdf")
  }

  @Test("Umlaut wird NFC kodiert")
  func umlautEncodedAsNfc() {
    #expect(OfficeAddress.encodeSegment("U\u{0308}bung.docx") == "%C3%9Cbung.docx")
  }

  @Test("Schulkonto: webUrl, %2C wird Komma")
  func businessUsesWebUrl() {
    let item = OneDriveItem(
      id: "01X", name: "Vokabeln, Teil 1.pptx",
      webUrl: "https://example-my.sharepoint.com/personal/m_example_com/Documents/Unterricht/Vokabeln%2C%20Teil%201.pptx",
      parentReference: .init(driveId: "b!x", driveType: "business", path: "/drive/root:/Unterricht"))
    #expect(OfficeAddress.documentURL(for: item) == "https://example-my.sharepoint.com/personal/m_example_com/Documents/Unterricht/Vokabeln,%20Teil%201.pptx")
  }

  @Test("Unbekannter driveType: nil")
  func unknownDriveTypeIsNil() {
    let item = OneDriveItem(
      id: "1", name: "a.pdf", webUrl: "https://example.com/a.pdf",
      parentReference: .init(driveId: "x", driveType: "unknown", path: "/drive/root:"))
    #expect(OfficeAddress.documentURL(for: item) == nil)
  }

  @Test("Office-Adresse, dokumentierte Form")
  func documentedForm() {
    #expect(
      OfficeAddress.officeURI(
        app: .powerpoint, documentURL: "https://d.docs.live.net/ABC/a.pptx", form: .documented,
        origin: origin, correlation: cid, timestampMillis: 1_763_020_800_000)
        == "ms-powerpoint:ofe|u|https://d.docs.live.net/ABC/a.pptx")
  }

  @Test("Office-Adresse wie „In Desktop-App öffnen“, URL(string:) ändert sie nicht")
  func webStyleForm() {
    let uri = OfficeAddress.officeURI(
      app: .word, documentURL: "https://d.docs.live.net/ABC/a.docx", form: .webStyle,
      origin: origin, correlation: cid, timestampMillis: 1_763_020_800_000)
    #expect(uri == "ms-word:ofe%7Cor%7C00000000-0000-0000-0000-00000000000a_0%7Cct%7C1763020800000%7Ccid%7C00000000-0000-0000-0000-00000000000b%7Cu%7Chttps://d.docs.live.net/ABC/a.docx")
    #expect(URL(string: uri)?.absoluteString == uri)
  }
}
