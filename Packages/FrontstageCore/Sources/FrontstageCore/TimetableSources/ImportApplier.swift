/// Stundenplan nach Übernahme einer Import-Vorschau.
public struct AppliedTimetable: Hashable, Sendable {
  public var entries: [TimetableEntry]
  public var manuallyEdited: Set<TimetableEntry>

  public init(entries: [TimetableEntry], manuallyEdited: Set<TimetableEntry>) {
    self.entries = entries
    self.manuallyEdited = manuallyEdited
  }
}

/// Wendet das Ergebnis des Abgleichs (`ImportDiff`) auf den vorhandenen Stundenplan an.
public enum ImportApplier {
  /// Ergebnis = `existing` − `removed` − `changed.old` + `changed.new` + `added`. Je Konflikt wird die eigene
  /// Fassung durch die Quell-Fassung ersetzt, wenn diese in `acceptedFromSource` steht, sonst bleibt sie.
  /// Die Reihenfolge von `existing` bleibt erhalten, Neues kommt hinten dran; doppelte Einträge entfallen.
  public static func apply(
    _ diff: ImportDiff, existing: [TimetableEntry], manuallyEdited: Set<TimetableEntry>,
    acceptedFromSource: Set<TimetableEntry>
  ) -> AppliedTimetable {
    let removed = Set(diff.removed)
    var replacement: [TimetableEntry: TimetableEntry] = [:]
    for pair in diff.changed { replacement[pair.old] = pair.new }
    for pair in diff.manualConflicts where acceptedFromSource.contains(pair.source) {
      replacement[pair.mine] = pair.source
    }

    var result: [TimetableEntry] = []
    var seen = Set<TimetableEntry>()
    func append(_ entry: TimetableEntry) {
      if seen.insert(entry).inserted { result.append(entry) }
    }
    for entry in existing where !removed.contains(entry) {
      append(replacement[entry] ?? entry)
    }
    diff.added.forEach(append)
    return AppliedTimetable(entries: result, manuallyEdited: manuallyEdited.intersection(seen))
  }
}
