import Foundation
import FrontstageCore
import PDFKit
import PencilKit
import Testing

@testable import Frontstage

@Suite struct PenNoteFileStoreTests {
  let store = PenNoteFileStore()
  @Test("Schreiben legt Notiz-Ordner und Stunden-Datei neben dem Dokument an; Original unverändert (AK-13)")
  func writeCreatesFolderAndFile() throws {
    let dir = try TestFolders.make(with: ["Arbeitsblatt Vokabeln.pdf": TestDocuments.pdfData(pages: 1, size: .a4)])
    let doc = dir.appending(path: "Arbeitsblatt Vokabeln.pdf"); let before = try Data(contentsOf: doc)
    _ = try store.write(TestFiles.note(TestKeys.tue8bEnglish, pages: [0]), changedPages: [0], documentURL: doc, key: TestKeys.tue8bEnglish)
    #expect(FileManager.default.fileExists(atPath: dir.appending(path: "Arbeitsblatt Vokabeln.frontstage-notizen/2026-11-17_8b_englisch_1.json").path))
    #expect(try Data(contentsOf: doc) == before)
    guard case .notes(let read, _) = store.read(documentURL: doc, key: TestKeys.tue8bEnglish) else { Issue.record(); return }
    #expect(read.pages.map(\.index) == [0])
  }
  @Test("Review Focus 6: Schreiben liest neu und behält fremde Seiten")
  func writeMergesWithDisk() throws {
    let (doc, key) = try TestFolders.documentWithNote(pages: [1])        // Seite 1 „vom anderen Gerät“
    let written = try store.write(TestFiles.note(key, pages: [0]), changedPages: [0], documentURL: doc, key: key)
    #expect(written.pages.map(\.index) == [0, 1])
  }
  @Test("Review Focus 4: kaputte oder neuere Datei wird nie überschrieben")
  func blockedFileIsNotOverwritten() throws {
    let (doc, key) = try TestFolders.documentWithRawNote(Data("{".utf8))
    #expect(store.read(documentURL: doc, key: key) == .blocked(.unreadable))
    #expect(throws: PenNoteWriteError.blocked(.unreadable)) { _ = try store.write(TestFiles.note(key, pages: [0]), changedPages: [0], documentURL: doc, key: key) }
    #expect(try TestFolders.rawNote(beside: doc, key: key) == Data("{".utf8))
  }
  @Test("Nicht beschreibbarer Ordner meldet notWritable (Review Focus 5)")
  func readOnlyFolderIsNotWritable() throws {
    let (doc, key) = try TestFolders.readOnlyDocument()                  // Ordner mit Rechten 0o555
    #expect(throws: PenNoteWriteError.notWritable) { _ = try store.write(TestFiles.note(key, pages: [0]), changedPages: [0], documentURL: doc, key: key) }
  }
  @Test("Gleichnamiges Bild schreibt unter dem Ausweichnamen (Entscheidung 2)")
  func sameStemOtherExtensionUsesAlternateName() throws {
    let (pdf, key) = try TestFolders.documentWithNote(pages: [0], documentName: "Tafelbild.pdf")
    let png = pdf.deletingLastPathComponent().appending(path: "Tafelbild.png")
    #expect(store.read(documentURL: png, key: key) == .none)
    _ = try store.write(TestFiles.note(key, pages: [0], document: "Tafelbild.png"), changedPages: [0], documentURL: png, key: key)
    #expect(store.existingNotesPaths(documentURL: png).contains("Tafelbild.frontstage-notizen/2026-11-17_8b_englisch_1.png.json"))
    guard case .notes(let pdfNotes, _) = store.read(documentURL: pdf, key: key) else { Issue.record(); return }
    #expect(pdfNotes.document == "Tafelbild.pdf")
  }
  @Test("Umbenennen nach Plan; Original und fremde Dateien bleiben (AK-22)")
  func applyMovePlan() throws {
    let (doc, key) = try TestFolders.documentWithNote(pages: [0], withPDF: true)
    let plan = PenNoteRelocation.planMove(documentFileName: doc.lastPathComponent, from: key, to: TestKeys.thu8bEnglish, existing: store.existingNotesPaths(documentURL: doc))
    try store.apply(plan, sourceDocumentURL: doc, targetDocumentURL: doc, combine: { $0 + $1 })
    #expect(store.read(documentURL: doc, key: key) == .none)
    guard case .notes(let moved, _) = store.read(documentURL: doc, key: TestKeys.thu8bEnglish) else { Issue.record(); return }
    #expect(moved.lessonKey == TestKeys.thu8bEnglish.storageText)          // Feld in der Datei mit umgestellt
    #expect(FileManager.default.fileExists(atPath: doc.path))
  }
  @Test("Ein Pfad außerhalb der Notiz-Pfade wird verweigert (FR-3.4)")
  func refusesNonNotesPath() throws {
    let (doc, _) = try TestFolders.documentWithNote(pages: [0])
    let evil = PenNoteRelocationPlan(transfers: [PenNoteTransfer(kind: .move, from: doc.lastPathComponent, to: "x.pdf")], regeneratePDFFor: [], updatesDocumentName: nil)
    #expect(throws: PenNoteWriteError.failed) { try store.apply(evil, sourceDocumentURL: doc, targetDocumentURL: doc, combine: { $0 + $1 }) }
    #expect(FileManager.default.fileExists(atPath: doc.path))
  }
}
