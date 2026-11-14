import Foundation
import FrontstageCore
import PencilKit
import Testing

@testable import Frontstage

@MainActor struct PenNoteStoreTests {
  @Test("AK-13: Notiz übersteht Schließen und erneutes Öffnen – in der Notiz-Datei")
  func savedNoteIsLoadedAgain() async throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let files = InMemoryPenNoteFiles()
    let notes = PenNoteStore(link: link, files: files, fallback: ctx)
    _ = await notes.loadAll()
    notes.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4)
    await notes.flush()
    let reopened = await PenNoteStore(link: link, files: files, fallback: ctx).loadAll()
    #expect(reopened[0]?.drawing.strokes.count == TestDrawings.word.strokes.count)
    #expect(reopened[0]?.savedSize == .a4)
    #expect(try ctx.penNotes(for: link).isEmpty)  // nichts im Datenort
  }

  @Test("AK-13: Ohne Angabe wird 0,5 s nach der letzten Änderung geschrieben")
  func defaultSaveDelayIsHalfASecond() async throws {
    #expect(PenNoteStore.defaultSaveDelay == .milliseconds(500))
    let (ctx, link) = try TestStore.contextWithLink()
    let files = InMemoryPenNoteFiles()
    let notes = PenNoteStore(link: link, files: files, fallback: ctx)
    _ = await notes.loadAll()
    notes.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4)
    #expect(await files.writeCount == 0)
    // Spätestens nach 1,5 s geschrieben – mit einer Vorgabe von 2 s schlüge das fehl.
    for _ in 0..<15 {
      if await files.writeCount > 0 { break }
      try await Task.sleep(for: .milliseconds(100))
    }
    #expect(await files.writeCount == 1)
  }

  @Test("Review Focus 3: flush schreibt eine ausstehende Notiz sofort")
  func flushWritesPendingDrawingImmediately() async throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let files = InMemoryPenNoteFiles()
    let notes = PenNoteStore(link: link, files: files, fallback: ctx, saveDelay: .seconds(60))
    _ = await notes.loadAll()
    notes.scheduleSave(TestDrawings.word, pageIndex: 1, pageSize: .a4)
    #expect(await files.writeCount == 0)
    await notes.flush()
    #expect(await files.writeCount == 1)
  }

  @Test("Review Focus 6: vor dem Schreiben wird neu gelesen – fremde Seite bleibt")
  func saveRereadsBeforeWriting() async throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let files = InMemoryPenNoteFiles()
    let notes = PenNoteStore(link: link, files: files, fallback: ctx)
    _ = await notes.loadAll()
    // Ein anderes Gerät schreibt Seite 2.
    try await files.put(TestFiles.note(TestKeys.tue8aEnglish, pages: [2]), for: link.reference)
    notes.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4)
    await notes.flush()
    let reopened = await PenNoteStore(link: link, files: files, fallback: ctx).loadAll()
    #expect(reopened.keys.sorted() == [0, 2])
  }

  @Test("Review Focus 4: unlesbare Datei → nicht editierbar, nichts geschrieben")
  func unreadableFileIsNeverOverwritten() async throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let files = InMemoryPenNoteFiles(blocked: .notDownloaded)
    let notes = PenNoteStore(link: link, files: files, fallback: ctx)
    _ = await notes.loadAll()
    #expect(notes.location == .blocked(.notDownloaded) && !notes.isEditable)
    notes.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4)
    await notes.flush()
    #expect(await files.writeCount == 0)
  }

  @Test("Neueres Format: nur lesen")
  func newerFormatIsReadOnly() async throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let files = InMemoryPenNoteFiles(blocked: .newerFormat)
    let notes = PenNoteStore(link: link, files: files, fallback: ctx)
    _ = await notes.loadAll()
    #expect(notes.location == .blocked(.newerFormat))
    #expect(!notes.isEditable)
  }

  @Test("Review Focus 5: Ordner nicht beschreibbar → Ersatz in PenNoteRecord, Hinweis über location")
  func notWritableFallsBackToAppData() async throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let files = InMemoryPenNoteFiles(notWritable: true)
    let notes = PenNoteStore(link: link, files: files, fallback: ctx)
    _ = await notes.loadAll()
    notes.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4)
    await notes.flush()
    #expect(notes.location == .appDataFallback)
    #expect(try ctx.penNotes(for: link).count == 1)
  }

  @Test("Review Focus 5: Ersatz wandert in die Notiz-Datei, sobald der Ordner beschreibbar ist")
  func fallbackNotesMoveIntoFileOnceWritable() async throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let files = InMemoryPenNoteFiles()
    try TestStore.addFallbackNote(
      to: ctx, link: link, page: 0, drawing: TestDrawings.word, updatedAt: .now, size: .a4)
    let loaded = await PenNoteStore(link: link, files: files, fallback: ctx).loadAll()
    #expect(loaded[0] != nil)
    #expect(try ctx.penNotes(for: link).isEmpty)
    #expect(await files.writeCount == 1)
  }

  @Test("FR-6.1: dasselbe Material in einer anderen Stunde beginnt ohne Notizen")
  func otherLessonStartsEmpty() async throws {
    let (ctx, link8a) = try TestStore.contextWithLink(key: TestKeys.tue8aEnglish)
    let files = InMemoryPenNoteFiles()
    let link8b = try TestStore.addLink(to: ctx, sameFileAs: link8a, key: TestKeys.wed8bEnglish)
    let first = PenNoteStore(link: link8a, files: files, fallback: ctx)
    _ = await first.loadAll()
    first.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4)
    await first.flush()
    let other = await PenNoteStore(link: link8b, files: files, fallback: ctx).loadAll()
    #expect(other.isEmpty)
  }

  @Test("Unlesbare Zeichnungsdaten einer Seite werden übersprungen, die Datei bleibt")
  func corruptDrawingIsSkippedNotDeleted() async throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let files = InMemoryPenNoteFiles()
    let stamp = Date(timeIntervalSince1970: 1_800_000_000)
    let broken = PenNoteFile(
      lessonKey: TestKeys.tue8aEnglish, document: "Arbeitsblatt Vokabeln.pdf", device: "test", updatedAt: stamp,
      pages: [PenNotePage(index: 0, width: 595, height: 842, drawing: Data([0, 1]), updatedAt: stamp)])
    try await files.put(broken, for: link.reference)
    let loaded = await PenNoteStore(link: link, files: files, fallback: ctx).loadAll()
    #expect(loaded[0] == nil)
    #expect(await files.writeCount == 0)
    #expect(await files.lessonKeys(for: link.reference) == [TestKeys.tue8aEnglish])
  }

  @Test("Doppelte Ersatz-Datensätze nach Abgleich: der jüngste gilt (Teilplan 02 führt zusammen)")
  func duplicateFallbackRecordsUseNewest() async throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let files = InMemoryPenNoteFiles(notWritable: true)
    try TestStore.addFallbackNote(
      to: ctx, link: link, page: 0, drawing: TestDrawings.word, updatedAt: Date(timeIntervalSince1970: 100))
    try TestStore.addFallbackNote(
      to: ctx, link: link, page: 0, drawing: TestDrawings.twoWords, updatedAt: Date(timeIntervalSince1970: 200))
    let notes = PenNoteStore(link: link, files: files, fallback: ctx)
    let loaded = await notes.loadAll()
    #expect(loaded[0]?.drawing.strokes.count == TestDrawings.twoWords.strokes.count)
    #expect(notes.location == .appDataFallback)
    #expect(try ctx.penNotes(for: link).count == 2)  // nichts gelöscht, solange der Ordner nicht beschreibbar ist
  }

  // MARK: - Nachtrag 06: Ersatz beim Schließen und Abgleich beim Öffnen

  @Test("Nachtrag 06: Notiz-Datei beim Schließen nicht schreibbar (.failed) → Seiten in den Datenort, nicht verworfen")
  func failedWriteOnCloseKeepsPagesInFallback() async throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let files = InMemoryPenNoteFiles()
    let notes = PenNoteStore(link: link, files: files, fallback: ctx, saveDelay: .seconds(60))
    _ = await notes.loadAll()
    notes.scheduleSave(TestDrawings.twoWords, pageIndex: 1, pageSize: .a4)
    let drawnAt = try #require(notes.currentNotes()[1]?.updatedAt)
    await files.setUnreachable(true)
    await notes.flushBeforeClose()
    #expect(!notes.hasPendingChanges)
    let records = try ctx.penNotes(for: link)
    #expect(records.map(\.pageIndex) == [1])
    #expect(records.first?.updatedAt == drawnAt)  // Zeitpunkt der Zeichnung, nicht des Schließens

    // Nächstes Öffnen mit erreichbarer Datei: Seite wandert in die Datei, der Ersatz wird gelöscht.
    await files.setUnreachable(false)
    let reopened = await PenNoteStore(link: link, files: files, fallback: ctx).loadAll()
    #expect(reopened[1]?.drawing.strokes.count == TestDrawings.twoWords.strokes.count)
    #expect(await files.writeCount == 1)
    #expect(try ctx.penNotes(for: link).isEmpty)
  }

  @Test("Nachtrag 06: Notiz-Datei mitten in der Sitzung gesperrt → beim Schließen in den Datenort")
  func blockedWriteOnCloseKeepsPagesInFallback() async throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let files = InMemoryPenNoteFiles()
    let notes = PenNoteStore(link: link, files: files, fallback: ctx, saveDelay: .seconds(60))
    _ = await notes.loadAll()
    notes.scheduleSave(TestDrawings.word, pageIndex: 0, pageSize: .a4)
    await files.setBlocked(.newerFormat)
    await notes.flushBeforeClose()
    #expect(notes.location == .blocked(.newerFormat))
    #expect(await files.writeCount == 0)  // die gesperrte Datei wird nie angefasst
    #expect(try ctx.penNotes(for: link).map(\.pageIndex) == [0])
  }

  @Test("Nachtrag 06: neuere Ersatz-Seite gewinnt gegen die Datei und wird zurückgeschrieben")
  func newerFallbackPageWinsAndIsWrittenBack() async throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let files = InMemoryPenNoteFiles()
    // Datei: Seite 0 mit einem Strich, Stand 1_800_000_000.
    try await files.put(TestFiles.note(TestKeys.tue8aEnglish, pages: [0]), for: link.reference)
    try TestStore.addFallbackNote(
      to: ctx, link: link, page: 0, drawing: TestDrawings.twoWords,
      updatedAt: Date(timeIntervalSince1970: 1_800_000_600))
    let notes = PenNoteStore(link: link, files: files, fallback: ctx)
    let loaded = await notes.loadAll()
    #expect(loaded[0]?.drawing.strokes.count == TestDrawings.twoWords.strokes.count)
    #expect(await files.writeCount == 1)
    #expect(try ctx.penNotes(for: link).isEmpty)
    #expect(notes.hasChangesThisSession)  // das Notiz-PDF wird beim Schließen nachgezogen
    let again = await PenNoteStore(link: link, files: files, fallback: ctx).loadAll()
    #expect(again[0]?.drawing.strokes.count == TestDrawings.twoWords.strokes.count)
  }

  @Test("Nachtrag 06: Ersatz-Seiten, die die Datei gleich alt oder neuer hat, werden gelöscht")
  func obsoleteFallbackPagesAreRemoved() async throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let files = InMemoryPenNoteFiles()
    let stamp = Date(timeIntervalSince1970: 1_800_000_000)  // Stand der Datei aus `TestFiles.note`
    try await files.put(TestFiles.note(TestKeys.tue8aEnglish, pages: [0, 1]), for: link.reference)
    try TestStore.addFallbackNote(to: ctx, link: link, page: 0, drawing: TestDrawings.twoWords, updatedAt: stamp)
    try TestStore.addFallbackNote(
      to: ctx, link: link, page: 1, drawing: TestDrawings.twoWords, updatedAt: stamp.addingTimeInterval(-60))
    let loaded = await PenNoteStore(link: link, files: files, fallback: ctx).loadAll()
    #expect(loaded[0]?.drawing.strokes.count == TestDrawings.word.strokes.count)
    #expect(loaded[1]?.drawing.strokes.count == TestDrawings.word.strokes.count)
    #expect(await files.writeCount == 0)
    #expect(try ctx.penNotes(for: link).isEmpty)
  }

  @Test("Nachtrag 06: Übernahme scheitert vorübergehend → Hinweis Datenort, nächster flush schreibt in die Datei")
  func temporarilyFailedMoveIsRetriedOnFlush() async throws {
    let (ctx, link) = try TestStore.contextWithLink()
    let files = InMemoryPenNoteFiles(unreachable: true)
    try TestStore.addFallbackNote(to: ctx, link: link, page: 2, drawing: TestDrawings.word, updatedAt: .now)
    let notes = PenNoteStore(link: link, files: files, fallback: ctx, saveDelay: .seconds(60))
    let loaded = await notes.loadAll()
    #expect(loaded[2] != nil)
    #expect(notes.location == .besideDocument)
    #expect(notes.displayLocation == .appDataFallback)  // die Anzeige zeigt den Ersatz-Hinweis
    #expect(notes.hasPendingChanges)
    #expect(try ctx.penNotes(for: link).count == 1)

    await files.setUnreachable(false)
    await notes.flush()
    #expect(await files.writeCount == 1)
    #expect(try ctx.penNotes(for: link).isEmpty)
    #expect(notes.displayLocation == .besideDocument)
  }
}
