import Foundation
import FrontstageCore
import SwiftData

/// Zuordnungen von Material zu Stunden und Stiftnotizen (FR-3, FR-6.1, FR-7, FR-8; ADR-0003, ADR-0011).
/// Es gibt hier keinen Dateizugriff: Eine Zuordnung ist nur ein Verweis (FR-3.4).
///
/// Swift-Hinweis: Die Mengen sind klein (Zuordnungen im Hunderterbereich), deshalb wird vollständig
/// geladen und im Speicher gefiltert. Das vermeidet `#Predicate`-Einschränkungen (keine Aufrufe
/// eigener Methoden, kein Zerlegen von Textformaten) und hält die Sortierung an einer Stelle.
extension DataStore {
  // MARK: - Lesen

  func link(id: UUID) throws -> MaterialLinkRecord? {
    try allLinks().first { $0.id == id }
  }

  /// Sortiert nach (position, createdAt, id.uuidString) – löst gleiche Positionen nach Anlagezeit auf.
  func links(for key: LessonKey) throws -> [MaterialLinkRecord] {
    let text = key.storageText
    return try allLinks().filter { $0.lessonKeyText == text }.sorted(by: Self.linkOrder)
  }

  /// Alle Zuordnungen mit dayText in from…through (Woche im Vorbereiten), je Stunde wie `links(for:)` sortiert.
  func links(from: CalendarDay, through: CalendarDay) throws -> [MaterialLinkRecord] {
    let fromText = from.storageText
    let throughText = through.storageText
    // `yyyy-MM-dd` ist als Text chronologisch sortierbar.
    return try allLinks().filter { $0.dayText >= fromText && $0.dayText <= throughText }
      .sorted { lhs, rhs in
        if lhs.dayText != rhs.dayText { return lhs.dayText < rhs.dayText }
        if lhs.lessonKeyText != rhs.lessonKeyText { return lhs.lessonKeyText < rhs.lessonKeyText }
        return Self.linkOrder(lhs, rhs)
      }
  }

  /// Für Bereithalten (03): Schlüssel und Verweis aller Zuordnungen dieser Stunden, in Reihenfolge der
  /// Schlüssel und Positionen.
  func linkedReferences(for keys: [LessonKey]) throws -> [(key: LessonKey, reference: MaterialReference)] {
    var result: [(key: LessonKey, reference: MaterialReference)] = []
    for key in keys {
      for link in try links(for: key) { result.append((key: key, reference: link.reference)) }
    }
    return result
  }

  /// Alle folderGrantName, die in Zuordnungen vorkommen (gespiegelte Freigabe-Namen, 03 und 04).
  func folderGrantNames() throws -> Set<String> {
    Set(try allLinks().map(\.folderGrantName).filter { !$0.isEmpty })
  }

  // MARK: - Neu verknüpfen

  /// Neu verknüpfen (ADR-0003): ersetzt den Verweis an allen Zuordnungen mit `reference.locationKey == locationKey`;
  /// Zuordnungen und Stiftnotizen bleiben. Auch zum Zurückschreiben gefundener OneDrive-Kennungen (03). Liefert die Zahl.
  @discardableResult
  func replaceReferences(atLocation locationKey: String, with reference: MaterialReference) throws -> Int {
    let matches = try allLinks().filter { $0.reference.locationKey == locationKey }
    guard !matches.isEmpty else { return 0 }
    for link in matches { link.setReference(reference) }
    try saveAndBump()
    return matches.count
  }

  // MARK: - Zuordnen und Anordnen

  /// index nil → ans Ende; sonst an diese Stelle, alle Positionen der Stunde werden 0…n-1 neu vergeben.
  /// Ist dieselbe Datei (fileIdentity) oder derselbe Ort (locationKey) schon zugeordnet, wird die vorhandene
  /// Zuordnung unverändert zurückgegeben. Der Ort zählt mit, weil Teilplan 03 gefundene OneDrive-Kennungen
  /// zurückschreibt und `fileIdentity` dann von `path:` auf `onedrive:` wechselt; ein Verweis frisch aus der
  /// Dateiauswahl hat keine Kennung.
  @discardableResult
  func assign(_ reference: MaterialReference, to key: LessonKey, at index: Int? = nil) throws
    -> MaterialLinkRecord
  {
    var existing = try links(for: key)
    if let same = existing.first(where: { Self.isSameFile($0.reference, reference) }) {
      return same
    }
    let record = MaterialLinkRecord()
    modelContext.insert(record)
    record.setLessonKey(key)
    record.setReference(reference)
    if let index {
      existing.insert(record, at: min(max(index, 0), existing.count))
      renumber(existing)
    } else {
      record.position = (existing.map(\.position).max() ?? -1) + 1
    }
    try saveAndBump()
    return record
  }

  /// Dieselbe Datei: gleiche fachliche Kennung oder gleicher Ort in derselben Freigabe.
  private static func isSameFile(_ a: MaterialReference, _ b: MaterialReference) -> Bool {
    a.fileIdentity == b.fileIdentity || a.locationKey == b.locationKey
  }

  /// Semantik wie SwiftUI `onMove`: toOffset zählt vor dem Entfernen. Danach Positionen 0…n-1.
  func moveLinks(in key: LessonKey, fromOffsets: IndexSet, toOffset: Int) throws {
    let ordered = try links(for: key)
    let moved = fromOffsets.filter { ordered.indices.contains($0) }.sorted().map { ordered[$0] }
    guard !moved.isEmpty else { return }
    // Bewegte Einträge zählen beim Ziel nur mit, wenn sie davor lagen (wie bei `onMove`).
    let before = fromOffsets.filter { $0 < toOffset }.count
    var rest = ordered.enumerated().filter { !fromOffsets.contains($0.offset) }.map(\.element)
    let insertAt = min(max(toOffset - before, 0), rest.count)
    rest.insert(contentsOf: moved, at: insertAt)
    renumber(rest)
    try saveAndBump()
  }

  // MARK: - Für eine andere Klasse übernehmen (FR-3.2)

  /// FR-3.2 (Nutzerentscheidung 2026-11-13): Kandidaten für die Auswahlliste – `ParallelLessonFinder.candidates`
  /// mit den gespeicherten Daten. Leer ohne Stundenplan.
  func candidateLessons(for schoolClass: SchoolClass, from day: CalendarDay, maxDays: Int = 28) throws
    -> [Lesson]
  {
    guard let timetable = try timetable() else { return [] }
    return ParallelLessonFinder.candidates(
      for: schoolClass, from: day, timetable: timetable, nonTeachingPeriods: try nonTeachingPeriods(),
      changes: try scheduleChanges(), maxDays: maxDays)
  }

  func selectableClasses(excluding: SchoolClass) throws -> [SchoolClass] {
    guard let timetable = try timetable() else { return [] }
    return ParallelLessonFinder.selectableClasses(in: timetable, excluding: excluding)
  }

  /// FR-3.2: neue Zuordnungen gleicher Werte in der gewählten Zielstunde, ohne Stiftnotizen, ans Ende;
  /// Dateien (fileIdentity), die das Ziel schon hat, werden übersprungen. Liefert die Zahl der neuen Zuordnungen.
  @discardableResult
  func copyMaterialLinks(from source: LessonKey, to target: LessonKey) throws -> Int {
    let sourceLinks = try links(for: source)
    let targetLinks = try links(for: target)
    var identities = Set(targetLinks.map { $0.reference.fileIdentity })
    var locations = Set(targetLinks.map { $0.reference.locationKey })
    var position = (targetLinks.map(\.position).max() ?? -1) + 1
    var created = 0
    for link in sourceLinks {
      let reference = link.reference
      // Dieselbe Datei wie bei `assign`: gleiche Kennung oder gleicher Ort.
      guard !identities.contains(reference.fileIdentity), !locations.contains(reference.locationKey) else { continue }
      identities.insert(reference.fileIdentity)
      locations.insert(reference.locationKey)
      let copy = MaterialLinkRecord()
      modelContext.insert(copy)
      copy.setLessonKey(target)
      copy.setReference(reference)
      copy.position = position
      position += 1
      created += 1
    }
    if created > 0 { try saveAndBump() }
    return created
  }

  // MARK: - Verschieben (FR-3.3, FR-7, FR-8)

  /// FR-3.3: ändert nur den Schlüssel; Stiftnotizen bleiben an der Zuordnung. nil → nichts geändert. Danach wird zusammengeführt;
  /// ein Fehler dabei wird nur protokolliert, die Verschiebung bleibt gespeichert.
  @discardableResult
  func moveLinkToNextLesson(_ link: MaterialLinkRecord) throws -> LessonKey? {
    guard let key = link.lessonKey, let target = try nextLesson(after: key) else { return nil }
    let position = try nextPosition(in: target)
    link.setLessonKey(target)
    link.position = position
    try saveAndBump()
    mergeDuplicatesLoggingFailure()
    return target
  }

  /// FR-8: alle Zuordnungen der Stunde in die nächste Stunde (Ausfälle übersprungen), Reihenfolge bleibt, ans Ende.
  @discardableResult
  func moveAllLinksToNextLesson(from key: LessonKey) throws -> LessonKey? {
    guard let target = try nextLesson(after: key) else { return nil }
    let moving = try links(for: key)
    var position = try nextPosition(in: target)
    for link in moving {
      link.setLessonKey(target)
      link.position = position
      position += 1
    }
    if !moving.isEmpty {
      try saveAndBump()
      mergeDuplicatesLoggingFailure()
    }
    return target
  }

  /// FR-7: Zuordnung „ohne Stunde“ an eine gewählte Unterrichtsstunde hängen; ändert nur Schlüssel, Tag, Position.
  func moveLink(_ link: MaterialLinkRecord, to key: LessonKey) throws {
    let position = try nextPosition(in: key)
    link.setLessonKey(key)
    link.position = position
    try saveAndBump()
  }

  func removeLink(_ link: MaterialLinkRecord) throws {
    modelContext.delete(link)  // Stiftnotizen fallen per Kaskade mit weg
    try saveAndBump()
  }

  /// Zuordnungen mit dayText des Tages, zu deren Schlüssel keine berechnete Unterrichtsstunde passt (Area daten, „ohne Stunde“).
  /// Eine ausgefallene Unterrichtsstunde zählt als vorhanden.
  func orphanedLinks(on day: CalendarDay) throws -> [MaterialLinkRecord] {
    let text = day.storageText
    let existing = Set(try lessons(on: day).map { $0.key.storageText })
    return try allLinks().filter { $0.dayText == text && !existing.contains($0.lessonKeyText) }
      .sorted(by: Self.linkOrder)
  }

  // MARK: - Stiftnotizen (ADR-0011, FR-6.1)

  /// Alle Datensätze der Zuordnung, auch doppelte nach dem Abgleich (06 nimmt je Seite den jüngsten).
  func penNotes(for link: MaterialLinkRecord) throws -> [PenNoteRecord] {
    let id = link.id
    return try modelContext.fetch(FetchDescriptor<PenNoteRecord>())
      .filter { $0.materialLink?.id == id }
      .sorted { ($0.pageIndex, $0.createdAt) < ($1.pageIndex, $1.createdAt) }
  }

  /// Jüngster Datensatz der Seite (nach `updatedAt`, dann `createdAt`).
  func penNote(for link: MaterialLinkRecord, pageIndex: Int) throws -> PenNoteRecord? {
    try penNotes(for: link).filter { $0.pageIndex == pageIndex }
      .max { ($0.updatedAt, $0.createdAt) < ($1.updatedAt, $1.createdAt) }
  }

  /// Überschreibt den jüngsten Datensatz der Seite oder legt einen an; updatedAt = `updatedAt` (Vorgabe: jetzt).
  /// pageWidth/pageHeight werden nur gesetzt, wenn der Datensatz neu ist oder bisher keine Größe (0) trug –
  /// so bleibt die Seitengröße erhalten, zu der die Notiz geschrieben wurde (06, PenNoteFit). Löscht nie einen Datensatz.
  /// - Parameter updatedAt: Zeitpunkt der Änderung; beim Ersatz nach gescheitertem Schließen der Zeitpunkt der
  ///   Zeichnung, damit der Abgleich mit der Notiz-Datei je Seite den wirklich neueren Stand wählt (Nachtrag 06).
  func savePenNote(
    for link: MaterialLinkRecord, pageIndex: Int, drawingData: Data, pageWidth: Double,
    pageHeight: Double, updatedAt: Date = Date.now
  ) throws {
    let note: PenNoteRecord
    if let existing = try penNote(for: link, pageIndex: pageIndex) {
      note = existing
    } else {
      note = PenNoteRecord(materialLink: link, pageIndex: pageIndex)
      modelContext.insert(note)
    }
    note.drawingData = drawingData
    if note.pageWidth == 0 || note.pageHeight == 0 {
      note.pageWidth = pageWidth
      note.pageHeight = pageHeight
    }
    note.updatedAt = updatedAt
    try saveAndBump()
  }

  /// Löscht alle `PenNoteRecord`s der Zuordnung und speichert. Nur für den Umzug der Ersatz-Notizen in die
  /// Notiz-Datei (ADR-0011) und für den Abgleich (08, Löschmarken); sonst löscht keine Stelle Stiftnotizen.
  func removePenNotes(for link: MaterialLinkRecord) throws {
    let notes = try penNotes(for: link)
    guard !notes.isEmpty else { return }
    for note in notes { modelContext.delete(note) }
    try saveAndBump()
  }

  /// Löscht die `PenNoteRecord`s dieser Seiten der Zuordnung (alle Datensätze je Seite, auch doppelte) und
  /// speichert. Nur für Ersatz-Seiten, die gleich alt oder neuer in der Notiz-Datei stehen (Nachtrag 06).
  func removePenNotes(for link: MaterialLinkRecord, pageIndices: Set<Int>) throws {
    guard !pageIndices.isEmpty else { return }
    let notes = try penNotes(for: link).filter { pageIndices.contains($0.pageIndex) }
    guard !notes.isEmpty else { return }
    for note in notes { modelContext.delete(note) }
    try saveAndBump()
  }

  // MARK: - Hilfen

  private func allLinks() throws -> [MaterialLinkRecord] {
    try modelContext.fetch(FetchDescriptor<MaterialLinkRecord>())
  }

  /// Ordnung innerhalb einer Stunde: Position, Anlagezeit, id als letzter Tiebreaker (stabil auf allen Geräten).
  private static func linkOrder(_ lhs: MaterialLinkRecord, _ rhs: MaterialLinkRecord) -> Bool {
    if lhs.position != rhs.position { return lhs.position < rhs.position }
    if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
    return lhs.id.uuidString < rhs.id.uuidString
  }

  private func renumber(_ ordered: [MaterialLinkRecord]) {
    for (index, link) in ordered.enumerated() { link.position = index }
  }

  /// Position hinter der letzten Zuordnung der Stunde.
  private func nextPosition(in key: LessonKey) throws -> Int {
    (try links(for: key).map(\.position).max() ?? -1) + 1
  }
}
