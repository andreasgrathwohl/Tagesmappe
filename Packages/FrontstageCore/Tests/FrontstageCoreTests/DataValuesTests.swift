import Foundation
import Testing
@testable import FrontstageCore

@Suite("DataValuesTests")
struct DataValuesTests {
  @Test("Dateiart aus der Endung, unabhängig von Groß-/Kleinschreibung (FR-5, FR-6)")
  func fileKindFromExtension() {
    #expect(MaterialFileKind(fileExtension: "PPTX") == .presentation)
    #expect(MaterialFileKind(fileExtension: "key") == .presentation)
    #expect(MaterialFileKind(fileExtension: "pages") == .document)
    #expect(MaterialFileKind(fileExtension: "docx") == .document)
    #expect(MaterialFileKind(fileExtension: "numbers") == .spreadsheet)
    #expect(MaterialFileKind(fileExtension: "pdf") == .pdf)
    for ext in ["png", "jpg", "jpeg", "heic"] { #expect(MaterialFileKind(fileExtension: ext) == .image) }
    #expect(MaterialFileKind(fileExtension: "txt") == .other)
    #expect(MaterialFileKind.pdf.opensInViewer && MaterialFileKind.image.opensInViewer && !MaterialFileKind.presentation.opensInViewer)
  }

  @Test("Dieselbe Datei: OneDrive-Kennung vor Pfad")
  func materialReferenceFileIdentity() {
    let a = MaterialReference(folderGrantName: "Unterricht", relativePath: "Englisch/Vokabeln.pdf", displayName: "Vokabeln", fileKind: .pdf)
    #expect(a.fileIdentity == "path:Unterricht/Englisch/Vokabeln.pdf")
    var b = a; b.oneDriveItemID = "01ABC"
    #expect(b.fileIdentity == "onedrive:01ABC")
    b.oneDriveItemID = ""
    #expect(b.fileIdentity == a.fileIdentity)
  }

  @Test("locationKey ignoriert OneDrive-Kennung und Groß-/Kleinschreibung des Pfads (ADR-0003, Neu verknüpfen)")
  func locationKeyIgnoresOneDriveID() {
    let a = MaterialReference(folderGrantName: "Unterricht", relativePath: "8b/Vokabeln Unit 4.pptx", displayName: "Vokabeln Unit 4", fileKind: .presentation)
    var b = a; b.oneDriveItemID = "01ABC"; b.relativePath = "8b/vokabeln unit 4.pptx"
    #expect(a.locationKey == b.locationKey)
    #expect(a.fileExtension == "pptx")
  }

  @Test("locationKey vergleicht den Freigabe-Namen wie FolderGrantStore: ohne Groß-/Kleinschreibung, NFC")
  func locationKeyNormalizesGrantName() {
    let a = MaterialReference(folderGrantName: "Übungen", relativePath: "8b/a.pdf", displayName: "a", fileKind: .pdf)
    var b = a; b.folderGrantName = "u\u{0308}bungen"
    #expect(a.locationKey == b.locationKey)
  }

  @Test("Tafelhintergründe in fester Reihenfolge")
  func boardBackgroundRawValues() {
    #expect(BoardBackground.allCases.map(\.rawValue) == ["blank", "lined", "grid", "image"])
  }

  @Test("AK-25: leere Stundenangaben gelten als nicht vorhanden")
  func lessonInfoNormalizesEmptyFields() {
    let info = LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: "", homework: nil)
    #expect(info.topic == "Unit 4 – Wortschatz")
    #expect(info.toPrepare == nil)
    #expect(LessonInfo().isEmpty)
  }

  @Test("Review Focus 3: nur Leerraum ist leer")
  func lessonInfoTreatsWhitespaceAsEmpty() {
    let info = LessonInfo(topic: "  Unit 4 – Wortschatz \n", toPrepare: " \n\t ", homework: "   ")
    #expect(info.topic == "Unit 4 – Wortschatz")
    #expect(info.toPrepare == nil)
    #expect(info.homework == nil)
  }

  @Test("Feldzugriff per Subscript")
  func lessonInfoSubscript() {
    var info = LessonInfo()
    info[.homework] = "S. 12"
    #expect(info.homework == "S. 12")
    #expect(info[.topic] == nil)
    #expect(!info.isEmpty)
  }
}
