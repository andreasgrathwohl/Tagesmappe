import Foundation
import FrontstageCore
import Observation
import OSLog
import PencilKit

/// Wo die Notizen einer Anzeige gerade liegen (ADR-0011).
enum PenNoteLocation: Equatable, Sendable {
  /// In der Notiz-Datei neben dem Dokument.
  case besideDocument
  /// Ordner nicht beschreibbar oder Stunde ohne gültigen Schlüssel: Ersatz in `PenNoteRecord` (Datenort).
  case appDataFallback
  /// Die Notiz-Datei ist vorhanden, aber nicht lesbar oder zu neu: nur ansehen, nie überschreiben.
  case blocked(PenNoteBlockReason)
}

/// Eine geladene Notiz einer Seite.
struct StoredPenNote {
  var drawing: PKDrawing
  /// Seitengröße beim ersten Zeichnen; `nil` = unbekannt (Breite oder Höhe 0).
  var savedSize: PageSize?
  var updatedAt: Date
}

/// Notizen **einer** Anzeige (Zuordnung Stunde + Dokument): lädt sie, hält sie im Speicher und schreibt
/// Änderungen verzögert zurück – in die Notiz-Datei neben dem Dokument, ersatzweise in den Datenort.
///
/// Swift-Hinweis: `@Observable` ersetzt `ObservableObject`; SwiftUI liest `location` und `isEditable`
/// und zeichnet bei Änderung neu. Ein `Task {}` in einer `@MainActor`-Klasse erbt den Hauptakteur, die
/// Dateiarbeit selbst läuft über `PenNoteFileAccessing` außerhalb des Hauptthreads.
@MainActor @Observable final class PenNoteStore {
  private(set) var location: PenNoteLocation = .besideDocument
  /// Mindestens eine Änderung seit dem Öffnen (für das Notiz-PDF beim Schließen).
  private(set) var hasChangesThisSession = false
  /// Gibt es Änderungen, die noch nicht geschrieben sind?
  var hasPendingChanges: Bool { !pending.isEmpty }
  var isEditable: Bool {
    if case .blocked = location { return false }
    return true
  }

  private let link: MaterialLinkRecord
  private let files: any PenNoteFileAccessing
  private let fallback: DataStore
  private let saveDelay: Duration
  private let reference: MaterialReference
  private let key: LessonKey?
  private let documentName: String
  private let device = DeviceIdentity.current()
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "PenNoteStore")

  /// Zuletzt gelesener oder geschriebener Stand der Notiz-Datei.
  @ObservationIgnored private var lastFile: PenNoteFile?
  /// Zeichnungen im Speicher, je Seite (auch die noch nicht geschriebenen).
  @ObservationIgnored private var current: [Int: StoredPenNote] = [:]
  /// Ausstehende Seiten mit Versionszähler: eine während des Schreibens erneut geänderte Seite bleibt ausstehend.
  @ObservationIgnored private var pending: [Int: Int] = [:]
  @ObservationIgnored private var version = 0
  @ObservationIgnored private var saveTask: Task<Void, Never>?
  @ObservationIgnored private var flushTask: Task<Void, Never>?

  init(
    link: MaterialLinkRecord, files: any PenNoteFileAccessing, fallback: DataStore,
    saveDelay: Duration = .seconds(2)
  ) {
    self.link = link
    self.files = files
    self.fallback = fallback
    self.saveDelay = saveDelay
    self.reference = link.reference
    self.key = LessonKey(storageText: link.lessonKeyText)
    self.documentName =
      link.reference.relativePath.split(separator: "/").last.map(String.init) ?? link.reference.relativePath
    // Altdaten ohne gültigen Schlüssel: nur der Ersatz im Datenort ist möglich.
    if key == nil { location = .appDataFallback }
  }

  // MARK: - Laden

  /// Lädt alle Notizen der Anzeige (Seitenindex → Notiz). Führt Ersatz-Notizen in die Datei über, sobald sie
  /// beschreibbar ist.
  func loadAll() async -> [Int: StoredPenNote] {
    var fromFile: [Int: StoredPenNote] = [:]
    if let key {
      switch await files.read(reference, key: key) {
      case .notes(let file, _):
        location = .besideDocument
        lastFile = file
        fromFile = Self.decode(file.pages)
      case .none:
        location = .besideDocument
        lastFile = emptyFile(for: key)
      case .blocked(let reason):
        // Aus dem unlesbaren Teil gibt es keine Seiten; die Datei wird nie angefasst.
        location = .blocked(reason)
        lastFile = nil
      }
    }

    var result = fromFile
    if location != .besideDocument || key == nil {
      // Blockiert oder ohne Schlüssel: Ersatz-Seiten nur anzeigen (bei blockiert zusätzlich, wenn vorhanden).
      for (index, note) in newestFallbackNotes() where result[index] == nil { result[index] = note }
    } else {
      let fallbackNotes = newestFallbackNotes()
      let missing = fallbackNotes.filter { fromFile[$0.key] == nil }
      if !fallbackNotes.isEmpty {
        result = await moveFallbackIntoFile(missing: missing, fromFile: fromFile, all: fallbackNotes)
      }
    }
    // Im Speicher gehaltene, noch nicht geschriebene Zeichnungen gehen nicht verloren.
    for (index, note) in current where pending[index] != nil { result[index] = note }
    current = result
    return result
  }

  /// Übernimmt fehlende Ersatz-Seiten in die Datei; bei Erfolg werden die Datensätze gelöscht.
  private func moveFallbackIntoFile(
    missing: [Int: StoredPenNote], fromFile: [Int: StoredPenNote], all: [Int: StoredPenNote]
  ) async -> [Int: StoredPenNote] {
    var shown = fromFile
    guard let key else { return shown }
    // Nichts fehlt: die Datei gilt, die Ersatz-Datensätze bleiben unangetastet.
    guard !missing.isEmpty else { return shown }
    var file = lastFile ?? emptyFile(for: key)
    for (index, note) in missing.sorted(by: { $0.key < $1.key }) {
      file = file.updating(
        pageIndex: index, drawing: note.drawing.dataRepresentation(),
        currentSize: note.savedSize ?? PageSize(width: 0, height: 0), now: note.updatedAt, device: device)
    }
    do {
      let written = try await files.write(file, changedPages: Set(missing.keys), reference: reference, key: key)
      lastFile = written
      shown = Self.decode(written.pages)
      removeFallbackLoggingFailure()
    } catch PenNoteWriteError.notWritable {
      location = .appDataFallback
      for (index, note) in all where shown[index] == nil { shown[index] = note }
    } catch PenNoteWriteError.blocked(let reason) {
      location = .blocked(reason)
      for (index, note) in all where shown[index] == nil { shown[index] = note }
    } catch {
      // Nächster Öffnungsversuch probiert es erneut; bis dahin sind die Ersatz-Seiten sichtbar.
      Self.logger.error("Ersatz-Notizen konnten nicht in die Notiz-Datei übernommen werden")
      for (index, note) in all where shown[index] == nil { shown[index] = note }
    }
    return shown
  }

  // MARK: - Speichern

  /// Merkt die Zeichnung der Seite vor und schreibt sie nach `saveDelay` (jede weitere Änderung startet neu).
  func scheduleSave(_ drawing: PKDrawing, pageIndex: Int, pageSize: PageSize) {
    guard isEditable else { return }
    let known = current[pageIndex]?.savedSize
    current[pageIndex] = StoredPenNote(drawing: drawing, savedSize: known ?? pageSize, updatedAt: .now)
    version += 1
    pending[pageIndex] = version
    hasChangesThisSession = true
    saveTask?.cancel()
    let delay = saveDelay
    saveTask = Task {
      do { try await Task.sleep(for: delay) } catch { return }
      self.saveTask = nil
      await self.flush()
    }
  }

  /// Stand der Notizen im Speicher, auch noch nicht geschriebene (für das Notiz-PDF beim Schließen).
  func currentNotes() -> [Int: StoredPenNote] { current }

  /// Schreibt alle ausstehenden Seiten sofort (Schließen, Szenenwechsel, Hintergrund).
  func flush() async {
    saveTask?.cancel()
    saveTask = nil
    while let running = flushTask { await running.value }
    guard !pending.isEmpty, isEditable else { return }
    let task = Task { await self.performFlush() }
    flushTask = task
    await task.value
  }

  private func performFlush() async {
    defer { flushTask = nil }
    let snapshot = pending
    var pages: [Int: StoredPenNote] = [:]
    for index in snapshot.keys { if let note = current[index] { pages[index] = note } }

    if location == .besideDocument, let key {
      var file = lastFile ?? emptyFile(for: key)
      for (index, note) in pages.sorted(by: { $0.key < $1.key }) {
        file = file.updating(
          pageIndex: index, drawing: note.drawing.dataRepresentation(),
          currentSize: note.savedSize ?? PageSize(width: 0, height: 0), now: .now, device: device)
      }
      do {
        let written = try await files.write(file, changedPages: Set(pages.keys), reference: reference, key: key)
        lastFile = written
        clearPending(snapshot)
        return
      } catch PenNoteWriteError.notWritable {
        location = .appDataFallback
      } catch PenNoteWriteError.blocked(let reason) {
        // Die Zeichnung bleibt im Speicher und wird nicht verworfen.
        location = .blocked(reason)
        Self.logger.error("Notiz-Datei gesperrt, Änderungen bleiben nur im Speicher")
        return
      } catch {
        // Zeichnung bleibt ausstehend, der nächste `flush` versucht es erneut.
        Self.logger.error("Notiz-Datei konnte nicht geschrieben werden")
        return
      }
    }

    if location == .appDataFallback {
      var saved: [Int: Int] = [:]
      for (index, note) in pages.sorted(by: { $0.key < $1.key }) {
        do {
          try fallback.savePenNote(
            for: link, pageIndex: index, drawingData: note.drawing.dataRepresentation(),
            pageWidth: note.savedSize?.width ?? 0, pageHeight: note.savedSize?.height ?? 0)
          saved[index] = snapshot[index]
        } catch {
          Self.logger.error("Ersatz-Notiz konnte nicht gespeichert werden")
        }
      }
      clearPending(saved)
    }
  }

  private func clearPending(_ written: [Int: Int]) {
    for (index, stamp) in written where pending[index] == stamp { pending[index] = nil }
  }

  // MARK: - Hilfen

  private func emptyFile(for key: LessonKey) -> PenNoteFile {
    PenNoteFile(lessonKey: key, document: documentName, device: device, updatedAt: .now, pages: [])
  }

  private func removeFallbackLoggingFailure() {
    do { try fallback.removePenNotes(for: link) } catch {
      Self.logger.error("Ersatz-Notizen konnten nach dem Umzug nicht gelöscht werden")
    }
  }

  /// Jüngster Ersatz-Datensatz je Seite (nach dem Abgleich kann es Doppelte geben).
  private func newestFallbackNotes() -> [Int: StoredPenNote] {
    guard let records = try? fallback.penNotes(for: link) else { return [:] }
    var newest: [Int: PenNoteRecord] = [:]
    for record in records {
      if let old = newest[record.pageIndex], (old.updatedAt, old.createdAt) >= (record.updatedAt, record.createdAt) {
        continue
      }
      newest[record.pageIndex] = record
    }
    var result: [Int: StoredPenNote] = [:]
    for (index, record) in newest {
      guard let data = record.drawingData, let drawing = try? PKDrawing(data: data) else { continue }
      result[index] = StoredPenNote(
        drawing: drawing, savedSize: Self.size(width: record.pageWidth, height: record.pageHeight),
        updatedAt: record.updatedAt)
    }
    return result
  }

  /// Unlesbare Zeichnungsdaten einer Seite lassen die Seite aus; die Datei bleibt unverändert.
  private static func decode(_ pages: [PenNotePage]) -> [Int: StoredPenNote] {
    var result: [Int: StoredPenNote] = [:]
    for page in pages {
      do {
        let drawing = try PKDrawing(data: page.drawing)
        result[page.index] = StoredPenNote(
          drawing: drawing, savedSize: size(width: page.width, height: page.height), updatedAt: page.updatedAt)
      } catch {
        logger.error("Zeichnungsdaten einer Seite unlesbar, Seite übersprungen")
      }
    }
    return result
  }

  private static func size(width: Double, height: Double) -> PageSize? {
    width > 0 && height > 0 ? PageSize(width: width, height: height) : nil
  }
}
