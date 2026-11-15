import Foundation

/// Ein lokaler Erscheinungsbild-Datensatz, wie ihn das Zusammenführen sieht.
public struct ThemeMergeEntry: Hashable, Sendable {
  public let id: UUID
  public let createdAt: Date
  public let updatedAt: Date

  public init(id: UUID, createdAt: Date, updatedAt: Date) {
    self.id = id
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

/// Ergebnis des Zusammenführens: welcher Datensatz bleibt, woher sein Inhalt kommt, was gelöscht wird.
public struct ThemeMergePlan: Hashable, Sendable {
  public let keeperID: UUID?
  public let contentSourceID: UUID?
  public let deletions: [UUID]

  public init(keeperID: UUID?, contentSourceID: UUID?, deletions: [UUID]) {
    self.keeperID = keeperID
    self.contentSourceID = contentSourceID
    self.deletions = deletions
  }

  public var isEmpty: Bool { deletions.isEmpty }
}

/// Zwei Geräte, die offline je ein Erscheinungsbild anlegen, ergeben nach dem Abgleich zwei Datensätze.
public enum ThemeMerger {
  /// Behalten: ältester (`createdAt`, bei Gleichstand kleinere `uuidString`); Inhalt: zuletzt geänderter
  /// (`updatedAt`, bei Gleichstand der Behaltene); löschen: alle anderen. Ein oder kein Eintrag → leerer Plan.
  public static func plan(for entries: [ThemeMergeEntry]) -> ThemeMergePlan {
    guard entries.count > 1 else {
      return ThemeMergePlan(keeperID: entries.first?.id, contentSourceID: entries.first?.id, deletions: [])
    }
    let keeper = entries.min {
      ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString)
    }!
    var source = keeper
    for entry in entries {
      // Gleichstand: der Behaltene gewinnt, sonst die kleinere Kennung (unabhängig von der Eingabereihenfolge).
      let newer = entry.updatedAt > source.updatedAt
      let tie =
        entry.updatedAt == source.updatedAt && source.id != keeper.id
        && entry.id.uuidString < source.id.uuidString
      if newer || tie { source = entry }
    }
    let deletions = entries.map(\.id).filter { $0 != keeper.id }.sorted { $0.uuidString < $1.uuidString }
    return ThemeMergePlan(keeperID: keeper.id, contentSourceID: source.id, deletions: deletions)
  }
}
