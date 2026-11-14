import Foundation
import FrontstageCore
import OSLog

/// Warum eine Notiz-Datei weder gelesen noch überschrieben werden darf (Review Focus 4).
enum PenNoteBlockReason: Equatable, Sendable {
  /// Noch nicht aus der Cloud geladen oder nicht lesbar zu machen.
  case notDownloaded
  /// Kein gültiges JSON oder Aufbau nicht erkennbar.
  case unreadable
  /// Format neuer als diese App kennt.
  case newerFormat
}

/// Ergebnis des Lesens neben dem Dokument.
enum PenNoteFileRead: Equatable, Sendable {
  /// Es gibt (noch) keine Datei dieser Stunde für dieses Dokument.
  case none
  /// Gelesen; `path` ist der Pfad relativ zum Ordner des Dokuments (Standard- oder Ausweichname).
  case notes(PenNoteFile, path: String)
  /// Vorhanden, aber nicht lesbar oder zu neu – wird nie überschrieben.
  case blocked(PenNoteBlockReason)
}

enum PenNoteWriteError: Error, Equatable, Sendable {
  case blocked(PenNoteBlockReason)
  /// Ordner nicht beschreibbar (Rechte, nur lesbarer Datenträger) – die App fällt auf `PenNoteRecord` zurück.
  case notWritable
  case failed
}

/// Liest und schreibt Notiz-Dateien neben dem Dokument (ADR-0011). Arbeitet nur mit URLs und ist ohne
/// `StorageService` prüfbar. Alle Aufrufe blockieren den aufrufenden Thread (Dateikoordination): nie auf dem
/// Hauptthread aufrufen, sondern im `body` von `StorageService.withDocumentLocation`.
///
/// Geschrieben, verschoben oder gelöscht wird nur, was `PenNoteFileLayout.isNotesPath` zulässt – nie das
/// Original (FR-3.4).
///
/// Swift-Hinweis: `NSFileCoordinator` sorgt dafür, dass der Ablage-Anbieter (iCloud Drive, OneDrive-App …)
/// eine Datei nicht gleichzeitig abgleicht, während die App sie schreibt.
struct PenNoteFileStore: Sendable {
  /// Kennung dieses Geräts in der Datei (Feld `device`) beim Zusammenführen; reine Information.
  let device: String

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "PenNotes")

  init(device: String = PenNoteFileStore.defaultDevice) {
    self.device = device
  }

  static var defaultDevice: String {
    #if os(macOS)
      return "mac"
    #else
      return "ipad"
    #endif
  }

  // MARK: Lesen

  func read(documentURL: URL, key: LessonKey) -> PenNoteFileRead {
    let fileName = documentURL.lastPathComponent
    let standard = notesPath(PenNoteFileLayout.lessonFileName(for: key), documentFileName: fileName)
    let alternate = notesPath(
      PenNoteFileLayout.alternateLessonFileName(for: key, documentFileName: fileName), documentFileName: fileName)
    // Fehlt die Standard-Datei, kann trotzdem eine unter dem Ausweichnamen liegen (Dokument gleichen Namens
    // anderer Endung hat den Standardnamen später nie belegt, oder wurde gelöscht).
    for path in [standard, alternate] {
      switch readFile(at: path, beside: documentURL) {
      case .none: continue
      case .notes(let file, let found):
        // Gehört die Datei einem anderen Dokument: weiter mit dem Ausweichnamen.
        if file.belongs(toDocument: fileName) { return .notes(file, path: found) }
      case .blocked(let reason):
        return .blocked(reason)
      }
    }
    return .none
  }

  /// Liest genau diesen Pfad; keine Zuordnung zum Dokument.
  private func readFile(at path: String, beside documentURL: URL) -> PenNoteFileRead {
    let url = fileURL(path, beside: documentURL)
    guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return .none }
    let facts = FileFactsReader.facts(at: url)
    let data: Data
    do {
      // Koordiniertes Lesen lädt bei iCloud eine noch nicht geladene Datei.
      data = try coordinatedRead(url)
    } catch {
      if facts.isUbiquitous, facts.downloadStatus == .notDownloaded { return .blocked(.notDownloaded) }
      Self.logger.error("Notiz-Datei nicht lesbar (Lesefehler)")
      return .blocked(.unreadable)
    }
    do {
      return .notes(try PenNoteFileCoding.decode(data), path: path)
    } catch PenNoteFileDecodeError.newerFormat {
      return .blocked(.newerFormat)
    } catch {
      return .blocked(.unreadable)
    }
  }

  // MARK: Schreiben

  /// Liest die Platte neu, behält fremde Seiten (Entscheidung 3) und schreibt die Datei.
  /// Liefert den geschriebenen Stand.
  @discardableResult
  func write(_ file: PenNoteFile, changedPages: Set<Int>, documentURL: URL, key: LessonKey) throws(PenNoteWriteError)
    -> PenNoteFile
  {
    let fileName = documentURL.lastPathComponent
    let onDisk: PenNoteFile?
    let path: String
    switch read(documentURL: documentURL, key: key) {
    case .blocked(let reason):
      throw .blocked(reason)
    case .notes(let existing, let found):
      onDisk = existing
      path = found
    case .none:
      onDisk = nil
      path = writeTargetPath(documentURL: documentURL, key: key)
    }
    guard PenNoteFileLayout.isNotesPath(path, documentFileName: fileName) else { throw .failed }
    let merged = PenNoteFile.merged(local: file, changedPages: changedPages, onDisk: onDisk)
    let data: Data
    do { data = try PenNoteFileCoding.encode(merged) } catch { throw .failed }
    try ensureNotesFolder(documentURL: documentURL)
    try coordinatedWriteData(data, to: fileURL(path, beside: documentURL))
    return merged
  }

  /// Wo eine neue Datei liegt: Standardname; gehört dort schon eine Datei einem anderen Dokument
  /// (gleichnamig, andere Endung), der Ausweichname (Entscheidung 2).
  private func writeTargetPath(documentURL: URL, key: LessonKey) -> String {
    let fileName = documentURL.lastPathComponent
    let standard = notesPath(PenNoteFileLayout.lessonFileName(for: key), documentFileName: fileName)
    if FileManager.default.fileExists(atPath: fileURL(standard, beside: documentURL).path(percentEncoded: false)) {
      return notesPath(
        PenNoteFileLayout.alternateLessonFileName(for: key, documentFileName: fileName),
        documentFileName: fileName)
    }
    return standard
  }

  /// Schreibt das Notiz-PDF der Stunde neben das Dokument (ersetzt ein vorhandenes).
  func writePDF(_ data: Data, documentURL: URL, key: LessonKey) throws(PenNoteWriteError) {
    let name = PenNoteFileLayout.notesPDFName(documentFileName: documentURL.lastPathComponent, key: key)
    guard PenNoteFileLayout.isNotesPath(name, documentFileName: documentURL.lastPathComponent) else { throw .failed }
    try coordinatedWriteData(data, to: fileURL(name, beside: documentURL))
  }

  /// Entfernt das Notiz-PDF der Stunde; eine fehlende Datei ist kein Fehler.
  func removePDF(documentURL: URL, key: LessonKey) throws(PenNoteWriteError) {
    let name = PenNoteFileLayout.notesPDFName(documentFileName: documentURL.lastPathComponent, key: key)
    guard PenNoteFileLayout.isNotesPath(name, documentFileName: documentURL.lastPathComponent) else { throw .failed }
    try coordinatedDelete(fileURL(name, beside: documentURL))
  }

  /// Gibt es das Notiz-PDF der Stunde schon?
  func hasPDF(documentURL: URL, key: LessonKey) -> Bool {
    let name = PenNoteFileLayout.notesPDFName(documentFileName: documentURL.lastPathComponent, key: key)
    return FileManager.default.fileExists(atPath: fileURL(name, beside: documentURL).path(percentEncoded: false))
  }

  // MARK: Vorhandenes

  /// Pfade relativ zum Ordner des Dokuments: `<Notiz-Ordner>/<Datei>` für jede Datei im Notiz-Ordner plus
  /// die Notiz-PDFs dieses Dokuments neben ihm.
  func existingNotesPaths(documentURL: URL) -> [String] {
    let fileName = documentURL.lastPathComponent
    let fileManager = FileManager.default
    let folder = PenNoteFileLayout.notesFolderName(documentFileName: fileName)
    var result: [String] = []
    let folderURL = documentURL.deletingLastPathComponent().appending(path: folder, directoryHint: .isDirectory)
    if let names = try? fileManager.contentsOfDirectory(atPath: folderURL.path(percentEncoded: false)) {
      result += names.sorted().map { "\(folder)/\($0)" }
    }
    let siblings =
      (try? fileManager.contentsOfDirectory(
        atPath: documentURL.deletingLastPathComponent().path(percentEncoded: false))) ?? []
    result += siblings.sorted().filter { PenNoteFileLayout.notesPDFSuffix($0, documentFileName: fileName) != nil }
    return result
  }

  // MARK: Umbenennen und Zusammenführen

  /// Führt einen Plan von `PenNoteRelocation` aus. Pfade `from` gelten relativ zum Ordner von
  /// `sourceDocumentURL`, Pfade `to` relativ zum Ordner von `targetDocumentURL` (beim Neu verknüpfen
  /// verschieden). Vorab werden **alle** Pfade geprüft; ein unzulässiger bricht ab, bevor etwas geschieht.
  /// Bricht ein Schritt später ab, bleiben schon ausgeführte bestehen – der Aufrufer plant aus den
  /// vorhandenen Pfaden neu und wiederholt nur den Rest.
  ///
  /// Die Notiz-PDFs zu `plan.regeneratePDFFor` erzeugt der Aufrufer neu (`PenNotePDFWriter`).
  func apply(
    _ plan: PenNoteRelocationPlan, sourceDocumentURL: URL, targetDocumentURL: URL,
    combine: (Data, Data) -> Data
  ) throws(PenNoteWriteError) {
    let sourceName = sourceDocumentURL.lastPathComponent
    let targetName = targetDocumentURL.lastPathComponent
    for transfer in plan.transfers {
      guard PenNoteFileLayout.isNotesPath(transfer.from, documentFileName: sourceName),
        PenNoteFileLayout.isNotesPath(transfer.to, documentFileName: targetName)
      else { throw .failed }
    }
    let newDocumentName = plan.updatesDocumentName
    for transfer in plan.transfers {
      let from = fileURL(transfer.from, beside: sourceDocumentURL)
      let to = fileURL(transfer.to, beside: targetDocumentURL)
      switch transfer.kind {
      case .dropDerived:
        try coordinatedDelete(from)
      case .move:
        try move(transfer, from: from, to: to, targetDocumentURL: targetDocumentURL, newDocumentName: newDocumentName)
      case .mergeNotes:
        try mergeNotes(
          transfer, from: from, to: to, targetDocumentURL: targetDocumentURL, newDocumentName: newDocumentName,
          combine: combine)
      }
    }
    // Leeren Notiz-Ordner des alten Orts entfernen.
    removeFolderIfEmpty(documentURL: sourceDocumentURL)
  }

  private func move(
    _ transfer: PenNoteTransfer, from: URL, to: URL, targetDocumentURL: URL, newDocumentName: String?
  ) throws(PenNoteWriteError) {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: from.path(percentEncoded: false)) else { return }
    try ensureNotesFolder(documentURL: targetDocumentURL)
    let isLessonFile = transfer.to.hasSuffix(".json")
    let targetExists = fileManager.fileExists(atPath: to.path(percentEncoded: false))
    // Eine Stunden-Datei nie überschreiben (Strichdaten); ein abgeleitetes PDF darf ersetzt werden.
    if targetExists && isLessonFile { throw .failed }
    var moveError: Error?
    var coordinationError: NSError?
    let options: NSFileCoordinator.WritingOptions = [.forMoving]
    NSFileCoordinator(filePresenter: nil).coordinate(
      writingItemAt: from, options: options, writingItemAt: to, options: .forReplacing, error: &coordinationError
    ) { source, target in
      do {
        if targetExists { try fileManager.removeItem(at: target) }
        try fileManager.moveItem(at: source, to: target)
      } catch {
        moveError = error
      }
    }
    if let error = coordinationError ?? moveError.map({ $0 as NSError }) { throw map(error) }
    // Bei Stunden-Dateien stehen Schlüssel und Dokumentname in der Datei: nachziehen.
    guard isLessonFile else { return }
    try relabel(at: to, targetDocumentURL: targetDocumentURL, newDocumentName: newDocumentName)
  }

  private func mergeNotes(
    _ transfer: PenNoteTransfer, from: URL, to: URL, targetDocumentURL: URL, newDocumentName: String?,
    combine: (Data, Data) -> Data
  ) throws(PenNoteWriteError) {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: from.path(percentEncoded: false)) else { return }
    let source = try decodeFile(at: from)
    // Fehlt das Ziel inzwischen, ist es ein einfaches Verschieben.
    guard fileManager.fileExists(atPath: to.path(percentEncoded: false)) else {
      try move(
        PenNoteTransfer(kind: .move, from: transfer.from, to: transfer.to), from: from, to: to,
        targetDocumentURL: targetDocumentURL, newDocumentName: newDocumentName)
      return
    }
    let target = try decodeFile(at: to)
    let targetFileName = (transfer.to as NSString).lastPathComponent
    guard let key = PenNoteFileLayout.lessonKey(fromLessonFileName: targetFileName) else { throw .failed }
    var merged = PenNoteFile.union(target, source, into: key, now: Date(), device: device, combine: combine)
    if let newDocumentName { merged = merged.relabeled(document: newDocumentName) }
    let data: Data
    do { data = try PenNoteFileCoding.encode(merged) } catch { throw .failed }
    // Erst Ziel schreiben, dann Quelle löschen: bricht es dazwischen ab, geht nichts verloren.
    try coordinatedWriteData(data, to: to)
    try coordinatedDelete(from)
  }

  /// Schreibt die Datei mit Schlüssel (aus dem Dateinamen) und Dokumentname neu.
  private func relabel(at url: URL, targetDocumentURL: URL, newDocumentName: String?) throws(PenNoteWriteError) {
    let file = try decodeFile(at: url)
    guard let key = PenNoteFileLayout.lessonKey(fromLessonFileName: url.lastPathComponent) else { throw .failed }
    let relabeled = file.relabeled(lessonKey: key, document: newDocumentName)
    guard relabeled != file else { return }
    let data: Data
    do { data = try PenNoteFileCoding.encode(relabeled) } catch { throw .failed }
    try coordinatedWriteData(data, to: url)
  }

  private func decodeFile(at url: URL) throws(PenNoteWriteError) -> PenNoteFile {
    let data: Data
    do { data = try coordinatedRead(url) } catch { throw .blocked(.notDownloaded) }
    do {
      return try PenNoteFileCoding.decode(data)
    } catch PenNoteFileDecodeError.newerFormat {
      throw .blocked(.newerFormat)
    } catch {
      throw .blocked(.unreadable)
    }
  }

  private func removeFolderIfEmpty(documentURL: URL) {
    let folder = documentURL.deletingLastPathComponent().appending(
      path: PenNoteFileLayout.notesFolderName(documentFileName: documentURL.lastPathComponent),
      directoryHint: .isDirectory)
    let path = folder.path(percentEncoded: false)
    guard let names = try? FileManager.default.contentsOfDirectory(atPath: path), names.isEmpty else { return }
    try? coordinatedDelete(folder)
  }

  // MARK: Pfade

  private func notesPath(_ lessonFileName: String, documentFileName: String) -> String {
    PenNoteFileLayout.notesFolderName(documentFileName: documentFileName) + "/" + lessonFileName
  }

  /// Pfad relativ zum Ordner des Dokuments → URL. Aufrufer haben `isNotesPath` schon geprüft.
  private func fileURL(_ relativePath: String, beside documentURL: URL) -> URL {
    var url = documentURL.deletingLastPathComponent()
    for component in relativePath.split(separator: "/") {
      url = url.appending(path: String(component), directoryHint: .inferFromPath)
    }
    return url
  }

  // MARK: Koordination

  private func ensureNotesFolder(documentURL: URL) throws(PenNoteWriteError) {
    let folder = documentURL.deletingLastPathComponent().appending(
      path: PenNoteFileLayout.notesFolderName(documentFileName: documentURL.lastPathComponent),
      directoryHint: .isDirectory)
    var failure: Error?
    var coordinationError: NSError?
    NSFileCoordinator(filePresenter: nil).coordinate(
      writingItemAt: folder, options: .forReplacing, error: &coordinationError
    ) { url in
      do {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
      } catch {
        // „Existiert schon“ ist kein Fehler.
        if (error as NSError).code != CocoaError.fileWriteFileExists.rawValue
          || (error as NSError).domain != NSCocoaErrorDomain
        {
          failure = error
        }
      }
    }
    if let error = coordinationError ?? failure.map({ $0 as NSError }) { throw map(error) }
  }

  private func coordinatedRead(_ url: URL) throws -> Data {
    var coordinationError: NSError?
    var result: Result<Data, Error>?
    NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) {
      readURL in
      result = Result { try Data(contentsOf: readURL) }
    }
    if let coordinationError { throw coordinationError }
    guard let result else { throw CocoaError(.fileReadUnknown) }
    return try result.get()
  }

  private func coordinatedWriteData(_ data: Data, to url: URL) throws(PenNoteWriteError) {
    var failure: Error?
    var coordinationError: NSError?
    NSFileCoordinator(filePresenter: nil).coordinate(
      writingItemAt: url, options: .forReplacing, error: &coordinationError
    ) { writeURL in
      do { try data.write(to: writeURL, options: .atomic) } catch { failure = error }
    }
    if let error = coordinationError ?? failure.map({ $0 as NSError }) { throw map(error) }
  }

  private func coordinatedDelete(_ url: URL) throws(PenNoteWriteError) {
    guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
    var failure: Error?
    var coordinationError: NSError?
    NSFileCoordinator(filePresenter: nil).coordinate(
      writingItemAt: url, options: .forDeleting, error: &coordinationError
    ) { deleteURL in
      do { try FileManager.default.removeItem(at: deleteURL) } catch { failure = error }
    }
    if let error = coordinationError ?? failure.map({ $0 as NSError }) {
      // Eine inzwischen verschwundene Datei ist kein Fehler.
      if (error as NSError).domain == NSCocoaErrorDomain, (error as NSError).code == CocoaError.fileNoSuchFile.rawValue {
        return
      }
      throw map(error)
    }
  }

  /// Rechte- und Nur-Lese-Fehler → `.notWritable`, alles andere → `.failed` (Protokoll ohne Inhalte).
  private func map(_ error: NSError) -> PenNoteWriteError {
    if error.domain == NSCocoaErrorDomain,
      [CocoaError.fileWriteNoPermission.rawValue, CocoaError.fileWriteVolumeReadOnly.rawValue].contains(error.code)
    {
      return .notWritable
    }
    if error.domain == NSPOSIXErrorDomain, [EACCES, EPERM, EROFS].contains(Int32(error.code)) {
      return .notWritable
    }
    if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError, underlying !== error {
      let mapped = map(underlying)
      if mapped == .notWritable { return mapped }
    }
    Self.logger.error("Schreiben neben dem Dokument fehlgeschlagen (Bereich \(error.domain), Code \(error.code))")
    return .failed
  }
}
