/// Ergebnis des Abgleichs zwischen vorhandenem und importiertem Stundenplan.
///
/// Was nicht in `removed` steht, bleibt bestehen. Von Hand angelegte oder geänderte Einträge
/// erscheinen nie in `removed` oder `changed`, sondern höchstens in `manualConflicts` (AK-3).
public struct ImportDiff: Sendable {
  /// Im Import neu, am Platz bisher nichts vorhanden.
  public var added: [TimetableEntry]
  /// Quell-Eintrag, der am selben Platz im Import abweicht.
  public var changed: [(old: TimetableEntry, new: TimetableEntry)]
  /// Von Hand bearbeiteter Eintrag, an dessen Platz der Import abweicht; die Vorschau fragt nach.
  public var manualConflicts: [(mine: TimetableEntry, source: TimetableEntry)]
  /// Quell-Eintrag ohne Hand-Markierung, der im Import fehlt.
  public var removed: [TimetableEntry]

  public init(
    added: [TimetableEntry] = [],
    changed: [(old: TimetableEntry, new: TimetableEntry)] = [],
    manualConflicts: [(mine: TimetableEntry, source: TimetableEntry)] = [],
    removed: [TimetableEntry] = []
  ) {
    self.added = added
    self.changed = changed
    self.manualConflicts = manualConflicts
    self.removed = removed
  }

  /// `true`, wenn der Import nichts verändert.
  public var isEmpty: Bool {
    added.isEmpty && changed.isEmpty && manualConflicts.isEmpty && removed.isEmpty
  }
}
