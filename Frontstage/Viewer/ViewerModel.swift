import Foundation
import FrontstageCore
import Observation
import OSLog
import PDFKit
import PencilKit

/// Zustand einer geöffneten Anzeige: lädt das Material, hält Seite und Notizen, führt den Zweitbildschirm nach
/// und schreibt beim Schließen das Notiz-PDF (ADR-0011).
///
/// Swift-Hinweis: `@Observable` + `@MainActor` – SwiftUI liest `phase`, `pageIndex` usw. im `body` und zeichnet bei
/// Änderung neu. Das geschieht nur auf dem Hauptthread; die Dateiarbeit liegt in `PenNoteStore` und
/// `PenNoteFileAccessing` außerhalb davon.
@MainActor @Observable final class ViewerModel {
  enum Phase: Equatable { case loading, ready, unavailable }

  private(set) var phase: Phase = .loading
  private(set) var document: PDFDocument?
  /// Rohdaten des Materials (PDF oder Bild) – für die reine Anzeige am Mac.
  private(set) var documentData: Data?
  private(set) var pageIndex = 0
  /// Passung je Seite mit Notiz (andere Seiten fehlen).
  private(set) var fitByPage: [Int: PenNoteFit] = [:]

  /// Seiten, deren Größe sich seit dem Zeichnen geändert hat, aufsteigend.
  var outdatedPages: [Int] { pages(with: .sizeChanged) }
  /// Notizen zu Seiten, die das Dokument nicht mehr hat, aufsteigend.
  var missingPages: [Int] { pages(with: .pageMissing) }
  /// Wo die Notizen liegen – für den Hinweis in der Anzeige (auch Seiten, die vorerst nur im Datenort liegen).
  var notesLocation: PenNoteLocation { notes.displayLocation }
  /// Zeichnen ist nur auf dem iPad möglich und nur, wenn die Notiz-Datei beschrieben werden darf.
  var canDraw: Bool {
    #if os(iOS)
      notes.isEditable
    #else
      false
    #endif
  }

  private let linkID: UUID
  private let reference: MaterialReference
  private let lessonKeyText: String
  private let notes: PenNoteStore
  private let fileReader: any MaterialFileReading
  private let files: any PenNoteFileAccessing
  private let secondScreen: SecondScreenState
  private let beforeLoad: @MainActor () async -> Void
  /// Dieses Modell hat Material und Tafel auf den Zweitbildschirm gebracht; nur dann gibt `close()` sie frei.
  @ObservationIgnored private var presentsOnSecondScreen = false
  /// Gesetzt von `close()`: Ein noch laufendes Laden schreibt danach keinen Zustand mehr (Nachtrag 06).
  @ObservationIgnored private var isClosed = false
  /// Das laufende Laden; `close()` bricht es kooperativ ab.
  @ObservationIgnored private var loadTask: Task<Void, Never>?
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "ViewerModel")

  /// - Parameter beforeLoad: Wird vor dem Laden erwartet (Warteliste der Umbenennungen nachholen, Task 9).
  init(
    link: MaterialLinkRecord, notes: PenNoteStore, fileReader: any MaterialFileReading,
    files: any PenNoteFileAccessing, secondScreen: SecondScreenState,
    beforeLoad: @escaping @MainActor () async -> Void = {}
  ) {
    self.linkID = link.id
    self.reference = link.reference
    self.lessonKeyText = link.lessonKeyText
    self.notes = notes
    self.fileReader = fileReader
    self.files = files
    self.secondScreen = secondScreen
    self.beforeLoad = beforeLoad
  }

  // MARK: - Laden

  /// Liest das Material, lädt die Notizen und zeigt alles auf dem Zweitbildschirm. Scheitert Lesen oder
  /// Öffnen, ist die Anzeige „nicht verfügbar“; Zweitbildschirm und Notizen bleiben unberührt.
  ///
  /// Wird die Anzeige währenddessen geschlossen (oder der aufrufende Task abgebrochen), endet das Laden am
  /// nächsten `await` ohne weitere Zustandsänderung – sonst öffnete ein spätes Laden das Material erneut auf
  /// dem Zweitbildschirm, nachdem `close()` ihn schon freigegeben hat.
  ///
  /// Swift-Hinweis: Abbrechen ist in Swift kooperativ – `cancel()` setzt nur ein Kennzeichen, das der Code an
  /// seinen Wartepunkten selbst prüfen muss (`Task.isCancelled`). `withTaskCancellationHandler` reicht den
  /// Abbruch des Aufrufers (z. B. `.task` beim Verschwinden der Ansicht) an den inneren Task weiter.
  func load() async {
    guard !isClosed else { return }
    let task = Task { await self.performLoad() }
    loadTask = task
    await withTaskCancellationHandler {
      await task.value
    } onCancel: {
      task.cancel()
    }
    if loadTask == task { loadTask = nil }
  }

  /// Abgebrochen oder geschlossen: kein Zustand mehr schreiben.
  private var loadIsStale: Bool { isClosed || Task.isCancelled }

  private func performLoad() async {
    phase = .loading
    await beforeLoad()
    guard !loadIsStale else { return }
    let data: Data
    let loaded: PDFDocument
    do {
      data = try await fileReader.readData(for: reference)
      try Task.checkCancellation()
      loaded = try MaterialDocumentLoader.makeDocument(from: data, kind: reference.fileKind)
    } catch {
      guard !loadIsStale else { return }
      Self.logger.error("Material konnte nicht geladen werden")
      phase = .unavailable
      return
    }
    guard !loadIsStale else { return }
    let stored = await notes.loadAll()
    guard !loadIsStale else { return }

    var fits: [Int: PenNoteFit] = [:]
    for (index, note) in stored {
      let current = loaded.page(at: index).map(DrawingGeometry.pageSize(of:))
      fits[index] = PenNoteFit.evaluate(
        savedSize: note.savedSize, pageIndex: index, pageCount: loaded.pageCount, currentSize: current)
    }

    document = loaded
    documentData = data
    fitByPage = fits
    pageIndex = 0
    secondScreen.openMaterial(
      MaterialPresentation(
        linkID: linkID, documentData: data, kind: reference.fileKind, pageIndex: 0, visibleRect: nil,
        drawings: stored.mapValues(\.drawing)))
    // AK-29: Die Tafel der Unterrichtsstunde ist wählbar (nil bei „Material ohne Stunde“).
    secondScreen.setBoardLesson(LessonKey(storageText: lessonKeyText))
    presentsOnSecondScreen = true
    phase = .ready
  }

  // MARK: - Zeichnen und Blättern

  /// Die Zeichnung einer Seite in Seitenkoordinaten, auch noch nicht geschriebene; `nil` ohne Notiz.
  func drawing(forPage pageIndex: Int) -> PKDrawing? {
    notes.currentNotes()[pageIndex]?.drawing
  }

  /// Eine Zeichnung (Seitenkoordinaten) hat sich geändert.
  func drawingChanged(_ drawingInPageSpace: PKDrawing, pageIndex: Int) {
    guard canDraw, let page = document?.page(at: pageIndex) else { return }
    notes.scheduleSave(drawingInPageSpace, pageIndex: pageIndex, pageSize: DrawingGeometry.pageSize(of: page))
    secondScreen.updateDrawing(drawingInPageSpace, pageIndex: pageIndex)
  }

  /// Seitenwechsel oder neuer Ausschnitt; die Notizen der verlassenen Seite werden zuerst geschrieben.
  func pageChanged(to pageIndex: Int, visibleRect: CGRect?) async {
    await notes.flush()
    self.pageIndex = pageIndex
    secondScreen.showPage(pageIndex, visibleRect: visibleRect)
  }

  /// Schreibt ausstehende Notizen sofort (App geht in den Hintergrund).
  func flushNow() async {
    await notes.flush()
  }

  // MARK: - Schließen

  /// Speichert, schreibt bei Bedarf das Notiz-PDF und gibt den Zweitbildschirm frei (AK-13, AK-23).
  func close() async {
    // Zuerst, vor jedem `await`: ein noch laufendes Laden darf danach nichts mehr öffnen.
    isClosed = true
    loadTask?.cancel()
    // Scheitert die Notiz-Datei, landen ausstehende Seiten im Datenort statt verloren zu gehen.
    await notes.flushBeforeClose()
    await writeNotesPDFIfNeeded()
    // Eine gescheiterte Anzeige hat nichts geöffnet und nimmt deshalb auch nichts weg (z. B. die Tafel).
    guard presentsOnSecondScreen else { return }
    presentsOnSecondScreen = false
    secondScreen.closeMaterial()
    secondScreen.setBoardLesson(nil)
  }

  /// Das Notiz-PDF entsteht nur neben dem Dokument und nur, wenn sich etwas geändert hat oder es trotz
  /// vorhandener Striche fehlt (ADR-0011, Entscheidung 5). Ohne Striche wird es entfernt. Fehler werden nur
  /// protokolliert: Maßgeblich ist die Notiz-Datei.
  private func writeNotesPDFIfNeeded() async {
    guard notes.location == .besideDocument, let document, let key = LessonKey(storageText: lessonKeyText)
    else { return }
    let current = notes.currentNotes()
    let hasStrokes = current.values.contains { !$0.drawing.strokes.isEmpty }
    var needed = notes.hasChangesThisSession
    if !needed, hasStrokes, let paths = await files.existingNotesPaths(for: reference) {
      let documentName = reference.relativePath.split(separator: "/").last.map(String.init) ?? reference.relativePath
      let pdfName = PenNoteFileLayout.notesPDFName(documentFileName: documentName, key: key)
      needed = !paths.contains(pdfName)
    }
    guard needed else { return }
    do {
      if let data = PenNotePDFWriter.makePDF(document: document, notes: current) {
        try await files.writePDF(data, reference: reference, key: key)
      } else {
        try await files.removePDF(reference: reference, key: key)
      }
    } catch {
      Self.logger.error("Notiz-PDF konnte nicht geschrieben werden")
    }
  }

  private func pages(with fit: PenNoteFit) -> [Int] {
    fitByPage.filter { $0.value == fit }.keys.sorted()
  }
}
