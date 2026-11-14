import Foundation
import Testing
@testable import FrontstageCore

@Suite("DataFolder Layout")
struct RemoteLayoutTests {
  private func id(_ n: Int) -> UUID {
    let digits = String(n)
    let padded = String(repeating: "0", count: 12 - digits.count) + digits
    return UUID(uuidString: "00000000-0000-0000-0000-\(padded)")!
  }

  @Test("Pfad eines Datensatzes und eines Anhangs")
  func buildsPaths() {
    #expect(RemoteLayout.recordPath(model: .materialLink, id: id(1)) == "MaterialLink/\(id(1).uuidString).json")
    #expect(
      RemoteLayout.attachmentPath(model: .boardPage, id: id(2), field: "drawing", hash: "0011aabbccddeeff")
        == "BoardPage/\(id(2).uuidString).drawing.0011aabbccddeeff.bin")
  }

  @Test("Datensatz wird erkannt")
  func classifiesRecord() {
    let path = RemoteLayout.recordPath(model: .lessonInfo, id: id(3))
    #expect(RemoteLayout.classify(path: path) == .record(model: .lessonInfo, id: id(3)))
  }

  @Test("Konfliktkopien werden erkannt")
  func classifiesConflictCopies() {
    for extra in ["-PC-LEHRER", " (1)", " 2"] {
      let path = "LessonInfo/\(id(3).uuidString)\(extra).json"
      #expect(RemoteLayout.classify(path: path) == .conflictCopy(model: .lessonInfo, id: id(3)))
    }
  }

  @Test("library.json, kleingeschriebene Kennung, Anhang-Kopie")
  func classifiesSpecialNames() {
    #expect(RemoteLayout.classify(path: "library.json") == .library)
    let lower = "PenNote/\(id(4).uuidString.lowercased()).json"
    #expect(RemoteLayout.classify(path: lower) == .record(model: .penNote, id: id(4)))
    let attachment = "BoardPage/\(id(5).uuidString).drawing.00ff.bin"
    #expect(
      RemoteLayout.classify(path: attachment) == .attachment(model: .boardPage, id: id(5), field: "drawing", hash: "00ff"))
    let copy = "BoardPage/\(id(5).uuidString) (1).bin"
    #expect(RemoteLayout.classify(path: copy) == .attachmentCopy(model: .boardPage, id: id(5)))
    let copy2 = "BoardPage/\(id(5).uuidString).drawing.00ff-PC.x.bin"
    #expect(RemoteLayout.classify(path: copy2) == .attachmentCopy(model: .boardPage, id: id(5)))
  }

  @Test("Fremde Dateien werden nicht angefasst")
  func ignoresForeignFiles() {
    let uuid = id(6).uuidString
    for path in [
      "Notizen.txt", "Unknown/\(uuid).json", "MaterialLink/abc.json", "MaterialLink/x/\(uuid).json",
      "MaterialLink/\(uuid).txt", "MaterialLink/\(uuid)", "\(uuid).json",
    ] {
      #expect(RemoteLayout.classify(path: path) == nil, "\(path)")
    }
  }

  @Test("Nur gültige Pfade dürfen geschrieben werden")
  func validPathCheck() {
    let uuid = id(7).uuidString
    #expect(RemoteLayout.isValidPath(RemoteLayout.recordPath(model: .materialLink, id: id(7))))
    #expect(RemoteLayout.isValidPath("library.json"))
    for path in ["../x.json", "/MaterialLink/\(uuid).json", "Material/Vokabeln.pdf", "MaterialLink/../\(uuid).json"] {
      #expect(!RemoteLayout.isValidPath(path), "\(path)")
    }
  }

  @Test("library.json hin und zurück")
  func libraryMarkerRoundTrip() throws {
    let marker = LibraryMarker(libraryID: id(8), createdAt: Date(timeIntervalSince1970: 1_795_000_000))
    let data = try JSONEncoder().encode(marker)
    #expect(try JSONDecoder().decode(LibraryMarker.self, from: data) == marker)
    #expect(marker.formatVersion == RecordEnvelope.currentFormatVersion)
  }
}
