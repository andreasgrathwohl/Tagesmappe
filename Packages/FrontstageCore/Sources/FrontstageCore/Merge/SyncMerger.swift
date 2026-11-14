import Foundation

/// Was nach dem Abgleich zu tun ist. Reihenfolge beim Anwenden: siehe Teilplan 02, Task 7.
public struct MergePlan: Equatable, Sendable {
  /// Aufgegebene Datensätze (aller Arten), die zu löschen sind.
  public var deletions: Set<UUID> = []
  /// Eintrag → behaltener Stundenplan.
  public var entryTimetableChanges: [UUID: UUID] = [:]
  /// Stiftnotiz → behaltene Zuordnung.
  public var penNoteLinkChanges: [UUID: UUID] = [:]
  /// Behaltene Stiftnotiz ← Zeichnung dieser Notiz übernehmen.
  public var penNoteDrawingSources: [UUID: UUID] = [:]
  /// Behaltener Datensatz ← je Feld die Quelle.
  public var lessonInfoFieldSources: [UUID: [LessonInfoField: UUID]] = [:]

  public init() {}

  public var isEmpty: Bool {
    deletions.isEmpty && entryTimetableChanges.isEmpty && penNoteLinkChanges.isEmpty
      && penNoteDrawingSources.isEmpty && lessonInfoFieldSources.isEmpty
  }
}

/// Reine Zusammenführ-Logik nach einer Synchronisierung: je fachlichem Schlüssel bleibt der
/// älteste Datensatz (Architecture Doc, Nebenläufigkeit). Keine Seiteneffekte, nur Foundation.
public enum SyncMerger {
  private struct EntryKey: Hashable {
    var timetableID: UUID
    var entry: TimetableEntry
  }
  private struct LinkKey: Hashable {
    var lessonKeyText: String
    var fileIdentity: String
  }
  private struct NoteKey: Hashable {
    var linkID: UUID
    var pageIndex: Int
  }

  public static func plan(for snapshot: SyncSnapshot) -> MergePlan {
    var plan = MergePlan()

    // 1. Stundenpläne: alle aktiven bilden eine Gruppe; inaktive bleiben unangetastet.
    let timetableMap = survivors(
      snapshot.timetables, key: { $0.isActive ? true : nil }, id: { $0.id }, createdAt: { $0.createdAt })
    plan.deletions.formUnion(timetableMap.keys)

    // 2. Einträge: Einträge aufgegebener Stundenpläne wandern zum behaltenen Stundenplan.
    var effectiveTimetable: [UUID: UUID] = [:]
    for item in snapshot.entries {
      guard let original = item.timetableID else { continue }
      let effective = timetableMap[original] ?? original
      effectiveTimetable[item.id] = effective
      if effective != original { plan.entryTimetableChanges[item.id] = effective }
    }
    let entryMap = survivors(
      snapshot.entries,
      key: { item in effectiveTimetable[item.id].map { EntryKey(timetableID: $0, entry: item.entry) } },
      id: { $0.id }, createdAt: { $0.createdAt })
    for dropped in entryMap.keys {
      plan.deletions.insert(dropped)
      // Ein aufgegebener Eintrag steht nur in `deletions`.
      plan.entryTimetableChanges[dropped] = nil
    }

    // 3. Zuordnungen: ohne abgeglichenen Verweis nie zusammenführen.
    let linkMap = survivors(
      snapshot.links,
      key: { item in item.fileIdentity.map { LinkKey(lessonKeyText: item.lessonKeyText, fileIdentity: $0) } },
      id: { $0.id }, createdAt: { $0.createdAt })
    plan.deletions.formUnion(linkMap.keys)

    // 4. Stiftnotizen: Schlüssel über die wirksame Zuordnung; Zeichnung vom jüngsten `updatedAt`.
    func effectiveLink(_ note: PenNoteSnapshot) -> UUID? {
      guard let original = note.linkID else { return nil }
      return linkMap[original] ?? original
    }
    let noteMap = survivors(
      snapshot.penNotes,
      key: { note in effectiveLink(note).map { NoteKey(linkID: $0, pageIndex: note.pageIndex) } },
      id: { $0.id }, createdAt: { $0.createdAt })
    plan.deletions.formUnion(noteMap.keys)
    for note in snapshot.penNotes where noteMap[note.id] == nil {
      // Eine aufgegebene Notiz steht nur in `deletions`.
      if let effective = effectiveLink(note), effective != note.linkID {
        plan.penNoteLinkChanges[note.id] = effective
      }
    }
    let notesByID = Dictionary(uniqueKeysWithValues: snapshot.penNotes.map { ($0.id, $0) })
    let droppedByKeeper = Dictionary(grouping: noteMap.keys, by: { noteMap[$0]! })
    for (keeperID, droppedIDs) in droppedByKeeper {
      guard let keeper = notesByID[keeperID] else { continue }
      // Strikt jüngeres `updatedAt` gewinnt; bei Gleichstand bleibt die Hülle bei ihrer eigenen Zeichnung.
      var latest = keeper
      let candidates = droppedIDs.compactMap { notesByID[$0] }
        .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
      for candidate in candidates where candidate.updatedAt > latest.updatedAt { latest = candidate }
      if latest.id != keeperID { plan.penNoteDrawingSources[keeperID] = latest.id }
    }

    // 5. Stundenangaben: ältester Datensatz bleibt, je Feld kommt der jüngste Stand.
    for (_, group) in Dictionary(grouping: snapshot.lessonInfos, by: \.lessonKeyText) where group.count > 1 {
      let sorted = group.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
      let keeper = sorted[0]
      var sources: [LessonInfoField: UUID] = [:]
      for field in LessonInfoField.allCases {
        var best = keeper
        for candidate in sorted.dropFirst()
        where (candidate.fieldUpdatedAt[field] ?? .distantPast) > (best.fieldUpdatedAt[field] ?? .distantPast) {
          best = candidate
        }
        if best.id != keeper.id { sources[field] = best.id }
      }
      for dropped in sorted.dropFirst() { plan.deletions.insert(dropped.id) }
      if !sources.isEmpty { plan.lessonInfoFieldSources[keeper.id] = sources }
    }

    // 6./7. Abweichungen (inklusive Herkunft) und unterrichtsfreie Zeiträume: nach Wert.
    plan.deletions.formUnion(
      survivors(snapshot.scheduleChanges, key: { $0.change }, id: { $0.id }, createdAt: { $0.createdAt }).keys)
    plan.deletions.formUnion(
      survivors(snapshot.nonTeachingPeriods, key: { $0.period }, id: { $0.id }, createdAt: { $0.createdAt }).keys)

    return plan
  }

  /// Liefert je aufgegebenem Datensatz den behaltenen (ältester; bei gleicher Zeit kleinere UUID-Zeichenkette).
  static func survivors<Item, Key: Hashable>(
    _ items: [Item], key: (Item) -> Key?, id: (Item) -> UUID, createdAt: (Item) -> Date
  ) -> [UUID: UUID] {
    var result: [UUID: UUID] = [:]
    let keyed = items.compactMap { item in key(item).map { ($0, item) } }
    for (_, group) in Dictionary(grouping: keyed, by: { $0.0 }) where group.count > 1 {
      let sorted = group.map(\.1).sorted {
        (createdAt($0), id($0).uuidString) < (createdAt($1), id($1).uuidString)
      }
      for dropped in sorted.dropFirst() { result[id(dropped)] = id(sorted[0]) }
    }
    return result
  }
}
