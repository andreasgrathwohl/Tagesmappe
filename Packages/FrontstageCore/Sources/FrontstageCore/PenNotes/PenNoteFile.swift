import Foundation

/// Eine Seite einer Notiz-Datei (Glossar „Notiz-Datei“).
public struct PenNotePage: Codable, Hashable, Sendable {
  public var index: Int
  /// Seitengröße beim ersten Zeichnen, 0 = unbekannt (Entscheidung 4).
  public var width: Double
  public var height: Double
  /// `PKDrawing.dataRepresentation()`; im JSON Base64.
  public var drawing: Data
  public var updatedAt: Date

  public init(index: Int, width: Double, height: Double, drawing: Data, updatedAt: Date) {
    self.index = index
    self.width = width
    self.height = height
    self.drawing = drawing
    self.updatedAt = updatedAt
  }
}

/// Notiz-Datei einer Unterrichtsstunde neben dem Dokument (ADR-0011, Glossar `PenNoteFile`).
public struct PenNoteFile: Codable, Hashable, Sendable {
  public static let currentFormat = 1

  public var format: Int
  /// Speichertext des `LessonKey`.
  public var lessonKey: String
  /// Dateiname des Dokuments, zu dem die Notizen gehören (Entscheidung 2).
  public var document: String
  public var device: String
  public var updatedAt: Date
  /// Nach `index` sortiert, je `index` einmal.
  public var pages: [PenNotePage]

  public init(lessonKey: LessonKey, document: String, device: String, updatedAt: Date, pages: [PenNotePage]) {
    self.format = Self.currentFormat
    self.lessonKey = lessonKey.storageText
    self.document = document
    self.device = device
    self.updatedAt = updatedAt
    self.pages = Self.normalized(pages)
  }

  /// Sortiert nach Index; bei doppeltem Index gewinnt die spätere Seite der Liste.
  private static func normalized(_ pages: [PenNotePage]) -> [PenNotePage] {
    var byIndex: [Int: PenNotePage] = [:]
    for page in pages { byIndex[page.index] = page }
    return byIndex.values.sorted { $0.index < $1.index }
  }

  /// Gehört die Datei zu diesem Dokument? NFC, Groß-/Kleinschreibung egal (Entscheidung 2).
  public func belongs(toDocument fileName: String) -> Bool {
    func key(_ text: String) -> String { text.precomposedStringWithCanonicalMapping.lowercased() }
    return key(document) == key(fileName)
  }

  /// Seite setzen. Eine vorhandene Größe (> 0) bleibt: sie ist die beim ersten Zeichnen (Entscheidung 4).
  public func updating(pageIndex: Int, drawing: Data, currentSize: PageSize, now: Date, device: String)
    -> PenNoteFile
  {
    var result = self
    var size = currentSize
    if let old = pages.first(where: { $0.index == pageIndex }), old.width > 0, old.height > 0 {
      size = PageSize(width: old.width, height: old.height)
    }
    let page = PenNotePage(
      index: pageIndex, width: size.width, height: size.height, drawing: drawing, updatedAt: now)
    result.pages = Self.normalized(pages.filter { $0.index != pageIndex } + [page])
    result.updatedAt = now
    result.device = device
    return result
  }

  /// Vor dem Schreiben: Seiten aus `changedPages` kommen aus `local`, alle anderen von der Platte –
  /// was ein anderes Gerät geschrieben hat, bleibt erhalten (Entscheidung 3). Seiten nur in `local`
  /// (weder geändert noch auf der Platte) bleiben. Kopf (`updatedAt`, `device`) von `local`.
  public static func merged(local: PenNoteFile, changedPages: Set<Int>, onDisk: PenNoteFile?) -> PenNoteFile {
    guard let onDisk else { return local }
    var byIndex: [Int: PenNotePage] = [:]
    for page in onDisk.pages { byIndex[page.index] = page }
    for page in local.pages where changedPages.contains(page.index) || byIndex[page.index] == nil {
      byIndex[page.index] = page
    }
    var result = local
    result.pages = byIndex.values.sorted { $0.index < $1.index }
    return result
  }

  /// Schieben in eine Stunde mit vorhandener Datei: Seiten beider vereinigen, gleiche Seite über
  /// `combine` aneinanderhängen (App: `PKDrawing.appending`) – nichts geht verloren (Entscheidung 8).
  /// Größe von `a`, `updatedAt` = `now`.
  public static func union(
    _ a: PenNoteFile, _ b: PenNoteFile, into key: LessonKey, now: Date, device: String,
    combine: (Data, Data) -> Data
  ) -> PenNoteFile {
    var byIndex: [Int: PenNotePage] = [:]
    for page in a.pages { byIndex[page.index] = page }
    for page in b.pages {
      if var existing = byIndex[page.index] {
        existing.drawing = combine(existing.drawing, page.drawing)
        existing.updatedAt = now
        byIndex[page.index] = existing
      } else {
        byIndex[page.index] = page
      }
    }
    return PenNoteFile(
      lessonKey: key, document: a.document, device: device, updatedAt: now,
      pages: Array(byIndex.values))
  }

  /// Kopie mit neuem Schlüssel und/oder Dokumentnamen (Schieben, Neu verknüpfen).
  public func relabeled(lessonKey: LessonKey? = nil, document: String? = nil) -> PenNoteFile {
    var result = self
    if let lessonKey { result.lessonKey = lessonKey.storageText }
    if let document { result.document = document }
    return result
  }
}
