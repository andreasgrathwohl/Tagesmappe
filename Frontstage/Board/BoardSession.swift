import Foundation
import FrontstageCore
import Observation
import PencilKit

/// Fehler der Tafel-Sitzung.
enum BoardSessionError: Error, Equatable {
  /// Es gibt kein früheres Tafelbild dieser Klasse in diesem Fach (FR-12.3).
  case noPreviousBoardDrawing
  /// Die Tafel ist nicht geöffnet.
  case notOpen
  /// Die Aktion ist nur auf der eigenen Tafel der Stunde erlaubt, nicht beim Ansehen eines früheren Tafelbilds.
  case readOnly
}

/// Sitzung der geöffneten Tafel (FR-12): welche Stunde, welche Seite, die Zeichnung in Echtzeit und das Speichern.
///
/// Tablet und Zweitbildschirm lesen denselben Zustand (`pages`, `pageIndex`, `liveDrawing`, `cover`); die
/// Zeichnung erscheint am Zweitbildschirm sofort, gespeichert wird 1 s nach dem letzten Strich, beim Seitenwechsel
/// und beim Schließen.
///
/// Swift-Hinweis: `@Observable` verfolgt jede gespeicherte Eigenschaft; `@ObservationIgnored` nimmt Dinge aus,
/// die nie eine Ansicht neu zeichnen sollen (Store, Datensätze, Speicher-Task).
@MainActor @Observable final class BoardSession {
  enum Mode: Equatable {
    case closed
    case own(LessonKey)
    /// Nur ansehen: das letzte Tafelbild derselben Klasse und desselben Fachs (FR-12.3).
    case previous(own: LessonKey, shown: LessonKey)
  }

  private(set) var mode: Mode = .closed
  private(set) var pages: [BoardPageSnapshot] = []
  private(set) var pageIndex = 0
  /// Spiegel der Zeichnung der gezeigten Seite für den Zweitbildschirm (Seitenkoordinaten).
  var liveDrawing = PKDrawing()
  /// Abdeckung der Tafel (Aufgabe 11); ein Seitenwechsel hebt sie auf.
  var cover: BoardCover?
  /// Das Livebild der Kamera ersetzt die Tafel (Aufgabe 13).
  var isCameraLive = false
  /// Das letzte Speichern ist gescheitert; die ungesicherte Zeichnung bleibt im Speicher und wird beim nächsten
  /// Speichern erneut versucht.
  private(set) var saveFailed = false

  @ObservationIgnored private let store: BoardStore
  @ObservationIgnored private let secondScreen: SecondScreenState
  @ObservationIgnored private let saveDelay: Duration
  @ObservationIgnored private var records: [BoardPageRecord] = []
  @ObservationIgnored private var ownRecords: [BoardPageRecord] = []
  @ObservationIgnored private var ownPageIndex = 0
  @ObservationIgnored private var isDirty = false
  @ObservationIgnored private var saveTask: Task<Void, Never>?

  init(store: BoardStore, secondScreen: SecondScreenState, saveDelay: Duration = .seconds(1)) {
    self.store = store
    self.secondScreen = secondScreen
    self.saveDelay = saveDelay
  }

  /// Die Seiten für den PDF-Export: wie `pages`, aber mit der noch nicht gespeicherten Zeichnung der gezeigten Seite
  /// (das Speichern läuft verzögert). Die teure Serialisierung läuft nur bei ungespeicherten Strichen.
  var exportPages: [BoardPageSnapshot] {
    var result = pages
    if isDirty, case .own = mode, result.indices.contains(pageIndex) {
      result[pageIndex].drawingData = liveDrawing.dataRepresentation()
    }
    return result
  }

  /// Die gezeigte Seite.
  var currentPage: BoardPageSnapshot? {
    pages.indices.contains(pageIndex) ? pages[pageIndex] : nil
  }

  // MARK: Öffnen und Schließen

  /// Öffnet die Tafel der Stunde; legt Seite 1 (leer) an, wenn es keine Seite gibt. Der Zweitbildschirm zeigt die Tafel.
  func open(_ key: LessonKey) throws {
    try flush()
    var loaded = try store.pages(for: key)
    if loaded.isEmpty { loaded = [try store.addPage(for: key, background: .blank)] }
    records = loaded
    ownRecords = []
    mode = .own(key)
    cover = nil
    reloadSnapshots()
    show(pageAt: 0)
    secondScreen.setBoardLesson(key)
    secondScreen.select(.board)
  }

  /// Speichert sofort und schließt. Scheitert das Speichern, bleibt die Tafel offen (die Zeichnung geht nicht verloren).
  /// Danach fällt der Zweitbildschirm auf den Klassenbildschirm zurück.
  func close() throws {
    guard mode != .closed else { return }
    try flush()
    mode = .closed
    records = []
    ownRecords = []
    pages = []
    pageIndex = 0
    liveDrawing = PKDrawing()
    cover = nil
    isCameraLive = false
    secondScreen.setBoardLesson(nil)
  }

  // MARK: Seiten

  /// Hängt eine Seite an und zeigt sie. Nur auf der eigenen Tafel.
  func addPage(background: BoardBackground, imageData: Data? = nil) throws {
    guard case .own(let key) = mode else { throw mode == .closed ? BoardSessionError.notOpen : .readOnly }
    try flush()
    let record = try store.addPage(for: key, background: background, backgroundImageData: imageData)
    records.append(record)
    reloadSnapshots()
    cover = nil
    show(pageAt: records.count - 1)
  }

  /// Ändert den Hintergrund der gezeigten Seite. Nur auf der eigenen Tafel.
  func setBackground(_ background: BoardBackground) throws {
    guard case .own = mode else { throw mode == .closed ? BoardSessionError.notOpen : .readOnly }
    guard records.indices.contains(pageIndex) else { return }
    let record = records[pageIndex]
    let imageData = background == .image ? record.backgroundImageData : nil
    try store.setBackground(background, imageData: imageData, of: record)
    pages[pageIndex].background = background
    pages[pageIndex].backgroundImageData = imageData
  }

  /// Wechselt die Seite: speichert vorher und hebt die Abdeckung auf (auch beim „Wechsel“ auf dieselbe Seite).
  /// Scheitert das Speichern, bleibt die Seite stehen (`saveFailed`).
  func goToPage(_ index: Int) {
    cover = nil
    guard mode != .closed, pages.indices.contains(index), index != pageIndex else { return }
    do { try flush() } catch { return }
    show(pageAt: index)
  }

  // MARK: Zeichnen und Speichern

  /// Spiegelt die Zeichnung sofort und speichert 1 s nach dem letzten Strich. Beim Ansehen eines früheren Tafelbilds wirkungslos.
  func drawingChanged(_ drawing: PKDrawing) {
    guard case .own = mode else { return }
    liveDrawing = drawing
    isDirty = true
    saveTask?.cancel()
    let delay = saveDelay
    saveTask = Task { [weak self] in
      do { try await Task.sleep(for: delay) } catch { return }
      try? self?.flush()
    }
  }

  /// Schreibt eine ungespeicherte Zeichnung sofort.
  func flush() throws {
    saveTask?.cancel()
    saveTask = nil
    guard isDirty, case .own = mode, records.indices.contains(pageIndex) else { return }
    let data = liveDrawing.dataRepresentation()
    do {
      try store.saveDrawing(data, to: records[pageIndex])
    } catch {
      saveFailed = true
      throw error
    }
    pages[pageIndex].drawingData = data
    isDirty = false
    saveFailed = false
  }

  // MARK: Letztes Tafelbild (FR-12.3)

  /// Zeigt das letzte Tafelbild derselben Klasse und desselben Fachs, nur zum Ansehen.
  func showPreviousBoardDrawing() throws {
    guard case .own(let key) = mode else { throw mode == .closed ? BoardSessionError.notOpen : .readOnly }
    guard let shown = try store.previousBoardDrawingKey(before: key) else {
      throw BoardSessionError.noPreviousBoardDrawing
    }
    let shownRecords = try store.pages(for: shown)
    guard !shownRecords.isEmpty else { throw BoardSessionError.noPreviousBoardDrawing }
    try flush()
    ownRecords = records
    ownPageIndex = pageIndex
    records = shownRecords
    mode = .previous(own: key, shown: shown)
    cover = nil
    reloadSnapshots()
    show(pageAt: 0)
  }

  /// Zurück zur Tafel dieser Stunde, auf der Seite, auf der die Lehrkraft war.
  func returnToOwnBoard() throws {
    guard case .previous(let own, _) = mode else { return }
    records = ownRecords
    ownRecords = []
    mode = .own(own)
    cover = nil
    reloadSnapshots()
    show(pageAt: min(ownPageIndex, max(records.count - 1, 0)))
  }

  /// Löscht alle Seiten der Stunde (FR-12.2); danach eine leere Seite 1. Nur auf der eigenen Tafel.
  func deleteBoardDrawing() throws {
    guard case .own(let key) = mode else { throw mode == .closed ? BoardSessionError.notOpen : .readOnly }
    saveTask?.cancel()
    saveTask = nil
    isDirty = false
    saveFailed = false
    try store.deleteBoardDrawing(for: key)
    records = []
    reloadSnapshots()
    records = [try store.addPage(for: key, background: .blank)]
    cover = nil
    reloadSnapshots()
    show(pageAt: 0)
  }

  // MARK: Hilfen

  private func reloadSnapshots() {
    pages = records.map {
      BoardPageSnapshot(
        background: $0.background, backgroundImageData: $0.backgroundImageData, drawingData: $0.drawingData)
    }
  }

  /// Zeigt die Seite und lädt ihre Zeichnung in `liveDrawing`; eine unlesbare Zeichnung ergibt eine leere Seite.
  private func show(pageAt index: Int) {
    pageIndex = index
    isDirty = false
    if pages.indices.contains(index), let data = pages[index].drawingData,
      let drawing = try? PKDrawing(data: data)
    {
      liveDrawing = drawing
    } else {
      liveDrawing = PKDrawing()
    }
  }
}
