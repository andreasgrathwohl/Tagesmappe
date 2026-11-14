import FrontstageCore
import Foundation
import Testing

@testable import Frontstage

extension PendingPenNoteMoves {
  /// Warteliste in einem frischen temporären Ordner (nur für Tests).
  static func inTemporaryDirectory() -> PendingPenNoteMoves {
    PendingPenNoteMoves(
      fileURL: FileManager.default.temporaryDirectory
        .appending(path: "frontstage-pending-\(UUID().uuidString)", directoryHint: .isDirectory)
        .appending(path: "pending-moves.json"))
  }
}

/// Zählt die Aufrufe der PDF-Erzeugung je Stunde.
private actor PDFCalls {
  private(set) var calls: [LessonKey] = []
  func record(_ key: LessonKey) { calls.append(key) }
}

@MainActor struct PenNoteFileServiceTests {
  private let reference = TestFiles.reference("Arbeitsblatt Vokabeln.pdf")

  @Test("AK-22: Schieben benennt Notiz-Datei und Notiz-PDF auf die nächste Stunde um")
  func moveRenamesNotes() async throws {
    let files = InMemoryPenNoteFiles()
    try await files.put(TestFiles.note(TestKeys.tue8aEnglish, pages: [0]), for: reference, withPDF: true)
    let service = PenNoteFileService(files: files, pending: .inTemporaryDirectory(), makePDF: { _, _ in })
    service.linksMoved([PenNoteMove(reference: reference, from: TestKeys.tue8aEnglish, to: TestKeys.thu8aEnglish)])
    await service.retryPending()
    #expect(await files.lessonKeys(for: reference) == [TestKeys.thu8aEnglish])
    #expect(await files.pdfNames(for: reference) == ["Arbeitsblatt Vokabeln – Notizen 8a 2026-11-19.pdf"])
  }

  @Test("Review Focus 8: gescheitertes Umbenennen bleibt in der Warteliste und wird nachgeholt")
  func failedMoveStaysPendingAndRetries() async throws {
    let files = InMemoryPenNoteFiles(unreachable: true)
    let pending = PendingPenNoteMoves.inTemporaryDirectory()
    let service = PenNoteFileService(files: files, pending: pending, makePDF: { _, _ in })
    service.linksMoved([PenNoteMove(reference: reference, from: TestKeys.tue8aEnglish, to: TestKeys.thu8aEnglish)])
    await service.retryPending()
    #expect(pending.load().count == 1)
    await files.setUnreachable(false)
    await service.retryPending()
    #expect(pending.load().isEmpty)
  }

  @Test("Review Focus 8: zwei Schiebungen hintereinander laufen in Reihenfolge")
  func chainedMovesRunInOrder() async throws {
    let files = InMemoryPenNoteFiles()
    try await files.put(TestFiles.note(TestKeys.tue8aEnglish, pages: [0]), for: reference)
    let nextTuesday = LessonKey(
      date: CalendarDay(year: 2026, month: 11, day: 24), schoolClass: SchoolClass("8a"),
      subject: Subject("Englisch"), ordinal: 1)
    let service = PenNoteFileService(files: files, pending: .inTemporaryDirectory(), makePDF: { _, _ in })
    service.linksMoved([
      PenNoteMove(reference: reference, from: TestKeys.tue8aEnglish, to: TestKeys.thu8aEnglish),
      PenNoteMove(reference: reference, from: TestKeys.thu8aEnglish, to: nextTuesday),
    ])
    await service.retryPending()
    #expect(await files.lessonKeys(for: reference) == [nextTuesday])
  }

  @Test("Ziel mit Notizen: zusammenführen und Ziel-PDF neu erzeugen (Entscheidung 8)")
  func moveIntoNotesMergesAndRegenerates() async throws {
    let files = InMemoryPenNoteFiles()
    try await files.put(TestFiles.note(TestKeys.tue8aEnglish, pages: [0]), for: reference)
    try await files.put(TestFiles.note(TestKeys.thu8aEnglish, pages: [0]), for: reference)
    let calls = PDFCalls()
    let service = PenNoteFileService(
      files: files, pending: .inTemporaryDirectory(), makePDF: { _, key in await calls.record(key) })
    service.linksMoved([PenNoteMove(reference: reference, from: TestKeys.tue8aEnglish, to: TestKeys.thu8aEnglish)])
    await service.retryPending()
    #expect(await files.lessonKeys(for: reference) == [TestKeys.thu8aEnglish])
    #expect(await calls.calls == [TestKeys.thu8aEnglish])
  }

  @Test("Übernehmen legt nichts an (FR-6.1, AK-22)")
  func copyCreatesNothing() async throws {
    let files = InMemoryPenNoteFiles()
    try await files.put(TestFiles.note(TestKeys.tue8aEnglish, pages: [0]), for: reference)
    let pending = PendingPenNoteMoves.inTemporaryDirectory()
    let service = PenNoteFileService(files: files, pending: pending, makePDF: { _, _ in })
    service.linksMoved([])
    await service.retryPending()
    #expect(pending.load().isEmpty)
    #expect(await files.lessonKeys(for: reference) == [TestKeys.tue8aEnglish])
  }

  @Test("Neu verknüpfen: Notizen am alten Ort werden gezählt und neben die neue Datei verschoben (ADR-0011)")
  func relinkMovesNotesToNewFile() async throws {
    let files = InMemoryPenNoteFiles()
    let old = TestFiles.reference("Arbeitsblatt Vokabeln.pdf")
    let new = TestFiles.reference("Ordner neu/Vokabeln neu.pdf")
    try await files.put(TestFiles.note(TestKeys.tue8aEnglish, pages: [0]), for: old, withPDF: true)
    let service = PenNoteFileService(files: files, pending: .inTemporaryDirectory(), makePDF: { _, _ in })
    #expect(await service.notesCount(beside: old) == 1)
    try await service.moveNotes(from: old, to: new)
    #expect(await files.lessonKeys(for: new) == [TestKeys.tue8aEnglish])
    #expect(await files.documentName(for: new, key: TestKeys.tue8aEnglish) == "Vokabeln neu.pdf")
    #expect(await files.lessonKeys(for: old).isEmpty)
  }

  @Test("Alter Ort nicht erreichbar: nichts anzubieten")
  func unreachableOldLocationOffersNothing() async throws {
    let files = InMemoryPenNoteFiles(unreachable: true)
    let service = PenNoteFileService(files: files, pending: .inTemporaryDirectory(), makePDF: { _, _ in })
    #expect(await service.notesCount(beside: reference) == 0)
  }

  @Test("Die Warteliste speichert nur Verweis und Schlüsseltexte")
  func pendingKeepsReferenceAndKeys() throws {
    let pending = PendingPenNoteMoves.inTemporaryDirectory()
    pending.append([PenNoteMove(reference: reference, from: TestKeys.tue8aEnglish, to: TestKeys.thu8aEnglish)])
    let entry = try #require(pending.load().first)
    #expect(entry.fromKeyText == TestKeys.tue8aEnglish.storageText)
    #expect(entry.reference.relativePath == reference.relativePath)
  }
}
