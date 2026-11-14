import Foundation
import Testing

@testable import FrontstageCore

struct PenNoteFileTests {
  let tue8b = LessonKey(
    date: CalendarDay(year: 2026, month: 11, day: 17), schoolClass: SchoolClass("8b"),
    subject: Subject("Englisch"), ordinal: 1)
  func t(_ n: TimeInterval) -> Date { Date(timeIntervalSince1970: n) }
  func file(_ pages: [PenNotePage], at time: Date = Date(timeIntervalSince1970: 0)) -> PenNoteFile {
    PenNoteFile(
      lessonKey: tue8b, document: "Arbeitsblatt Vokabeln.pdf", device: "device-A", updatedAt: time, pages: pages)
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
    var newer = file([page(0, 1)])
    newer.format = 2
    let data = try PenNoteFileCoding.encode(newer)
    #expect(throws: PenNoteFileDecodeError.newerFormat(2)) { try PenNoteFileCoding.decode(data) }
    #expect(throws: PenNoteFileDecodeError.unreadable) { try PenNoteFileCoding.decode(Data("kein json".utf8)) }
  }
  @Test("Erste Seitengröße bleibt beim Weiterschreiben (Entscheidung 4)")
  func updatingKeepsFirstSize() {
    let updated = file([page(0, 1)]).updating(
      pageIndex: 0, drawing: Data([2]), currentSize: PageSize(width: 842, height: 595), now: t(5),
      device: "device-A")
    #expect(updated.pages == [PenNotePage(index: 0, width: 595, height: 842, drawing: Data([2]), updatedAt: t(5))])
    let added = updated.updating(
      pageIndex: 3, drawing: Data([3]), currentSize: PageSize(width: 595, height: 842), now: t(6),
      device: "device-A")
    #expect(added.pages.map(\.index) == [0, 3])
  }
  @Test("Review Focus 6: Zusammenführen behält Seiten, die ein anderes Gerät geschrieben hat")
  func mergeKeepsPagesWrittenElsewhere() {
    let disk = file([page(0, 1), page(1, 9, at: 50)])  // Seite 1 von einem anderen Gerät
    let local = file([page(0, 5, at: 60), page(1, 2)])  // hier nur Seite 0 geändert
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
    let thu = LessonKey(
      date: CalendarDay(year: 2026, month: 11, day: 19), schoolClass: SchoolClass("8b"),
      subject: Subject("Englisch"), ordinal: 1)
    let a = file([page(0, 1), page(2, 3)])
    let b = file([page(0, 2)])
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
