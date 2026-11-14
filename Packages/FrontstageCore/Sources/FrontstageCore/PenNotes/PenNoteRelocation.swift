import Foundation

/// Eine Dateioperation, die beim Schieben oder Neuverknüpfen auszuführen ist.
/// Pfade sind relativ zum Ordner des Dokuments (Notiz-Ordner/Datei oder Notiz-PDF).
public struct PenNoteTransfer: Equatable, Hashable, Sendable {
  public enum Kind: Equatable, Hashable, Sendable {
    /// Datei umbenennen bzw. verschieben.
    case move
    /// Striche der Quelle in die vorhandene Ziel-Datei übernehmen, danach die Quelle entfernen.
    case mergeNotes
    /// Abgeleitete Datei (Notiz-PDF) ersatzlos entfernen; sie wird bei Bedarf neu erzeugt.
    case dropDerived
  }

  public var kind: Kind
  public var from: String
  public var to: String

  public init(kind: Kind, from: String, to: String) {
    self.kind = kind
    self.from = from
    self.to = to
  }
}

/// Ergebnis der Planung; die Ausführung übernimmt der Aufrufer (App-Ebene).
public struct PenNoteRelocationPlan: Equatable, Sendable {
  public var transfers: [PenNoteTransfer]
  /// Schlüsseltexte der Stunden, deren Notiz-PDF neu zu erzeugen ist (nach dem Zusammenführen).
  public var regeneratePDFFor: [String]
  /// Neuer Dokumentname für die Verknüpfung (nur beim Neu verknüpfen).
  public var updatesDocumentName: String?

  public init(transfers: [PenNoteTransfer] = [], regeneratePDFFor: [String] = [], updatesDocumentName: String? = nil) {
    self.transfers = transfers
    self.regeneratePDFFor = regeneratePDFFor
    self.updatesDocumentName = updatesDocumentName
  }
}

/// Plant Umbenennungen der Notiz-Dateien, wenn ein Dokument in eine andere Stunde geschoben
/// oder auf eine andere Datei neu verknüpft wird (ADR-0011). Reine Funktionen, kein Dateizugriff.
public enum PenNoteRelocation {
  private static let pdfInfix = " – Notizen "

  /// Dokument von Stunde `from` auf Stunde `to` schieben.
  /// `existing`: vorhandene Pfade relativ zum Dokumentordner.
  public static func planMove(
    documentFileName: String, from: LessonKey, to: LessonKey, existing: [String]
  ) -> PenNoteRelocationPlan {
    let present = Set(existing.map(nfc))
    let folder = PenNoteFileLayout.notesFolderName(documentFileName: documentFileName)
    var transfers: [PenNoteTransfer] = []
    var regenerate: [String] = []
    var merged = false

    let forms: [(String, String)] = [
      (PenNoteFileLayout.lessonFileName(for: from), PenNoteFileLayout.lessonFileName(for: to)),
      (
        PenNoteFileLayout.alternateLessonFileName(for: from, documentFileName: documentFileName),
        PenNoteFileLayout.alternateLessonFileName(for: to, documentFileName: documentFileName)
      ),
    ]
    var seen = Set<String>()
    for (source, target) in forms where seen.insert(source).inserted {
      let sourcePath = nfc("\(folder)/\(source)")
      let targetPath = nfc("\(folder)/\(target)")
      guard present.contains(sourcePath), sourcePath != targetPath else { continue }
      if present.contains(targetPath) {
        transfers.append(PenNoteTransfer(kind: .mergeNotes, from: sourcePath, to: targetPath))
        merged = true
        if !regenerate.contains(to.storageText) { regenerate.append(to.storageText) }
      } else {
        transfers.append(PenNoteTransfer(kind: .move, from: sourcePath, to: targetPath))
      }
    }

    let pdfFrom = nfc(PenNoteFileLayout.notesPDFName(documentFileName: documentFileName, key: from))
    let pdfTo = nfc(PenNoteFileLayout.notesPDFName(documentFileName: documentFileName, key: to))
    if present.contains(pdfFrom), pdfFrom != pdfTo {
      if merged || present.contains(pdfTo) {
        transfers.append(PenNoteTransfer(kind: .dropDerived, from: pdfFrom, to: pdfTo))
      } else {
        transfers.append(PenNoteTransfer(kind: .move, from: pdfFrom, to: pdfTo))
      }
    }
    return PenNoteRelocationPlan(transfers: transfers, regeneratePDFFor: regenerate)
  }

  /// Notizen von `oldDocumentFileName` neben die neue Datei holen.
  /// `existingAtOld` / `existingAtNew`: vorhandene Pfade relativ zum jeweiligen Dokumentordner.
  public static func planRelink(
    oldDocumentFileName: String, existingAtOld: [String],
    newDocumentFileName: String, existingAtNew: [String]
  ) -> PenNoteRelocationPlan {
    let oldFolder = PenNoteFileLayout.notesFolderName(documentFileName: oldDocumentFileName)
    let newFolder = PenNoteFileLayout.notesFolderName(documentFileName: newDocumentFileName)
    let atNew = Set(existingAtNew.map(nfc))
    let oldNames = existingAtOld.map(nfc)

    var transfers: [PenNoteTransfer] = []
    var regenerate: [String] = []
    var handledPDFs = Set<String>()

    // Stunden-Dateien im alten Notiz-Ordner; fremde Dateien bleiben liegen.
    let prefix = oldFolder + "/"
    let lessonFiles = oldNames.filter { $0.hasPrefix(prefix) }.sorted().compactMap { path -> (String, String, LessonKey)? in
      let name = String(path.dropFirst(prefix.count))
      guard !name.contains("/"), let key = PenNoteFileLayout.lessonKey(fromLessonFileName: name) else { return nil }
      return (path, name, key)
    }
    for (path, name, key) in lessonFiles {
      // Standardname bleibt; ein Ausweichname (`…_1.png.json`) bekommt die Endung des neuen Dokuments,
      // sonst würde die Notiz für das neue Dokument nie gefunden.
      let isStandard = name == PenNoteFileLayout.lessonFileName(for: key)
      let targetName = isStandard
        ? name : PenNoteFileLayout.alternateLessonFileName(for: key, documentFileName: newDocumentFileName)
      let target = nfc("\(newFolder)/\(targetName)")
      // Gleicher Notiz-Ordner und gleicher Name: nichts zu übertragen (sonst Selbst-Merge mit Datenverlust).
      let unchanged = path == target
      let merging = !unchanged && atNew.contains(target)
      if !unchanged {
        transfers.append(PenNoteTransfer(kind: merging ? .mergeNotes : .move, from: path, to: target))
        if merging, !regenerate.contains(key.storageText) { regenerate.append(key.storageText) }
      }

      // Das zur Stunde gehörende Notiz-PDF folgt dem Schicksal der Stunden-Datei.
      let oldPDF = nfc(PenNoteFileLayout.notesPDFName(documentFileName: oldDocumentFileName, key: key))
      let newPDF = nfc(PenNoteFileLayout.notesPDFName(documentFileName: newDocumentFileName, key: key))
      if oldNames.contains(oldPDF), handledPDFs.insert(oldPDF).inserted {
        let drop = merging || atNew.contains(newPDF)
        if oldPDF != newPDF {
          transfers.append(PenNoteTransfer(kind: drop ? .dropDerived : .move, from: oldPDF, to: newPDF))
        }
      }
    }

    // Notiz-PDFs ohne Stunden-Datei: nur umbenennen.
    let stem = String(newFolder.dropLast(PenNoteFileLayout.folderSuffix.count))
    for name in oldNames.sorted() where !handledPDFs.contains(name) {
      guard let rest = PenNoteFileLayout.notesPDFSuffix(name, documentFileName: oldDocumentFileName) else { continue }
      let target = nfc(stem + pdfInfix + rest)
      guard target != name else { continue }
      transfers.append(PenNoteTransfer(kind: atNew.contains(target) ? .dropDerived : .move, from: name, to: target))
    }

    return PenNoteRelocationPlan(
      transfers: transfers, regeneratePDFFor: regenerate, updatesDocumentName: newDocumentFileName)
  }

  private static func nfc(_ text: String) -> String { text.precomposedStringWithCanonicalMapping }
}
