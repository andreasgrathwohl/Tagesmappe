import Testing

@testable import FrontstageCore

struct PenNoteRelocationTests {
  let doc = "Arbeitsblatt Vokabeln.pdf"
  let folder = "Arbeitsblatt Vokabeln.frontstage-notizen"
  let tue = LessonKey(date: CalendarDay(year: 2026, month: 11, day: 17), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
  let thu = LessonKey(date: CalendarDay(year: 2026, month: 11, day: 19), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)

  @Test("AK-22: Schieben benennt Stunden-Datei und Notiz-PDF auf die neue Stunde um")
  func moveRenamesBoth() {
    let plan = PenNoteRelocation.planMove(documentFileName: doc, from: tue, to: thu,
      existing: ["\(folder)/2026-11-17_8b_englisch_1.json", "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf"])
    #expect(plan.transfers == [
      PenNoteTransfer(kind: .move, from: "\(folder)/2026-11-17_8b_englisch_1.json", to: "\(folder)/2026-11-19_8b_englisch_1.json"),
      PenNoteTransfer(kind: .move, from: "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf", to: "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-19.pdf"),
    ])
    #expect(plan.regeneratePDFFor.isEmpty)
  }
  @Test("Ohne Notizen: nichts zu tun")
  func moveWithoutNotesIsEmpty() {
    #expect(PenNoteRelocation.planMove(documentFileName: doc, from: tue, to: thu, existing: []).transfers.isEmpty)
  }
  @Test("Ziel hat schon Notizen: zusammenführen, altes PDF weg, Ziel-PDF neu (Entscheidung 8)")
  func moveIntoLessonWithNotesMerges() {
    let plan = PenNoteRelocation.planMove(documentFileName: doc, from: tue, to: thu, existing: [
      "\(folder)/2026-11-17_8b_englisch_1.json", "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf",
      "\(folder)/2026-11-19_8b_englisch_1.json", "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-19.pdf"])
    #expect(plan.transfers.map(\.kind) == [.mergeNotes, .dropDerived])
    #expect(plan.regeneratePDFFor == [thu.storageText])
  }
  @Test("Ausweichname (gleichnamiges Bild) wandert mit seinem Namen")
  func alternateNameMoves() {
    let plan = PenNoteRelocation.planMove(documentFileName: "Tafelbild.png", from: tue, to: thu,
      existing: ["Tafelbild.frontstage-notizen/2026-11-17_8b_englisch_1.png.json"])
    #expect(plan.transfers == [PenNoteTransfer(kind: .move, from: "Tafelbild.frontstage-notizen/2026-11-17_8b_englisch_1.png.json", to: "Tafelbild.frontstage-notizen/2026-11-19_8b_englisch_1.png.json")])
  }
  @Test("Neu verknüpfen: alle Stunden-Dateien und PDFs neben die neue Datei, PDFs mit neuem Namen")
  func relinkMovesAllNotes() {
    let plan = PenNoteRelocation.planRelink(oldDocumentFileName: doc, existingAtOld: [
        "\(folder)/2026-11-17_8b_englisch_1.json", "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf", "\(folder)/.DS_Store"],
      newDocumentFileName: "Vokabeln neu.pdf", existingAtNew: [])
    #expect(Set(plan.transfers) == [
      PenNoteTransfer(kind: .move, from: "\(folder)/2026-11-17_8b_englisch_1.json", to: "Vokabeln neu.frontstage-notizen/2026-11-17_8b_englisch_1.json"),
      PenNoteTransfer(kind: .move, from: "Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf", to: "Vokabeln neu – Notizen 8b 2026-11-17.pdf"),
    ])
    #expect(plan.updatesDocumentName == "Vokabeln neu.pdf")
  }
  @Test("Neu verknüpfen in einen Ordner mit Notizen derselben Stunde: zusammenführen, nie überschreiben")
  func relinkMergesExisting() {
    let plan = PenNoteRelocation.planRelink(oldDocumentFileName: doc, existingAtOld: ["\(folder)/2026-11-17_8b_englisch_1.json"],
      newDocumentFileName: "Vokabeln neu.pdf", existingAtNew: ["Vokabeln neu.frontstage-notizen/2026-11-17_8b_englisch_1.json"])
    #expect(plan.transfers.map(\.kind) == [.mergeNotes])
    #expect(plan.regeneratePDFFor == [tue.storageText])
  }
}
