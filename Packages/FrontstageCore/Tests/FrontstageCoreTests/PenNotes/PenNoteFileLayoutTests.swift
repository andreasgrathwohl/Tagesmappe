import Foundation
import Testing

@testable import FrontstageCore

struct PenNoteFileLayoutTests {
  let tue8b = LessonKey(
    date: CalendarDay(year: 2026, month: 11, day: 17), schoolClass: SchoolClass("8b"),
    subject: Subject("Englisch"), ordinal: 1)

  @Test("Notiz-Ordner heißt wie das Dokument ohne Endung (ADR-0011)")
  func folderNameDropsExtension() {
    #expect(
      PenNoteFileLayout.notesFolderName(documentFileName: "Arbeitsblatt Vokabeln.pdf")
        == "Arbeitsblatt Vokabeln.frontstage-notizen")
    #expect(
      PenNoteFileLayout.notesFolderName(documentFileName: "Ohne Endung") == "Ohne Endung.frontstage-notizen")
  }
  @Test("Stunden-Datei: Schlüsseltext ohne verbotene Zeichen (Entscheidung 1)")
  func lessonFileNameIsFileSafe() {
    #expect(PenNoteFileLayout.lessonFileName(for: tue8b) == "2026-11-17_8b_englisch_1.json")
    let french = LessonKey(
      date: tue8b.date, schoolClass: SchoolClass("8/9"), subject: Subject("Französisch"), ordinal: 2)
    let name = PenNoteFileLayout.lessonFileName(for: french)
    #expect(!name.contains(where: { "|/\\:*?\"<>%".contains($0) }))
    #expect(PenNoteFileLayout.lessonKey(fromLessonFileName: name) == french)
  }
  @Test("Ausweichname für gleichnamiges Dokument anderer Endung (Entscheidung 2)")
  func alternateNameCarriesExtension() {
    let name = PenNoteFileLayout.alternateLessonFileName(for: tue8b, documentFileName: "Tafelbild.png")
    #expect(name == "2026-11-17_8b_englisch_1.png.json")
    #expect(PenNoteFileLayout.lessonKey(fromLessonFileName: name) == tue8b)
  }
  @Test("Fremde Dateien im Notiz-Ordner sind keine Stunden-Dateien")
  func foreignFileIsNoLessonFile() {
    #expect(PenNoteFileLayout.lessonKey(fromLessonFileName: ".DS_Store") == nil)
    #expect(PenNoteFileLayout.lessonKey(fromLessonFileName: "2026-11-17_8b_englisch_1-Lehrer-PC.json") == nil)
  }
  @Test("Notiz-PDF: Name, Klasse, Datum; zweite Stunde am Tag mit (2) (Entscheidung 6)")
  func notesPDFNames() {
    #expect(
      PenNoteFileLayout.notesPDFName(documentFileName: "Arbeitsblatt Vokabeln.pdf", key: tue8b)
        == "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf")
    let second = LessonKey(
      date: tue8b.date, schoolClass: tue8b.schoolClass, subject: tue8b.subject, ordinal: 2)
    #expect(
      PenNoteFileLayout.notesPDFName(documentFileName: "Arbeitsblatt Vokabeln.pdf", key: second)
        == "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17 (2).pdf")
    #expect(
      PenNoteFileLayout.notesPDFSuffix(
        "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf", documentFileName: "Arbeitsblatt Vokabeln.pdf")
        == "8b 2026-11-17.pdf")
    #expect(
      PenNoteFileLayout.notesPDFSuffix(
        "Arbeitsblatt Vokabeln.pdf", documentFileName: "Arbeitsblatt Vokabeln.pdf") == nil)
  }
  @Test("Nur Notiz-Pfade sind schreibbar – nie das Original (FR-3.4)")
  func onlyNotesPathsAreWritable() {
    let doc = "Arbeitsblatt Vokabeln.pdf"
    #expect(
      PenNoteFileLayout.isNotesPath(
        "Arbeitsblatt Vokabeln.frontstage-notizen/2026-11-17_8b_englisch_1.json", documentFileName: doc))
    #expect(
      PenNoteFileLayout.isNotesPath("Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf", documentFileName: doc))
    #expect(!PenNoteFileLayout.isNotesPath("Arbeitsblatt Vokabeln.pdf", documentFileName: doc))
    #expect(
      !PenNoteFileLayout.isNotesPath(
        "Arbeitsblatt Vokabeln.frontstage-notizen/../Arbeitsblatt Vokabeln.pdf", documentFileName: doc))
    #expect(
      !PenNoteFileLayout.isNotesPath("Arbeitsblatt Vokabeln.frontstage-notizen/x.pdf", documentFileName: doc))
  }
}
