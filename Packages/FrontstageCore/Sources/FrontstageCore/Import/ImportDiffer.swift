/// Vergleicht einen Stundenplan-Import mit dem vorhandenen Stand, ohne Handarbeit zu verlieren.
public enum ImportDiffer {
  /// Platz eines Eintrags im Raster: Woche, Wochentag, Stunde.
  private struct Slot: Hashable {
    let weekVariant: WeekVariant?
    let weekday: Weekday
    let period: Int

    init(_ entry: TimetableEntry) {
      weekVariant = entry.weekVariant
      weekday = entry.weekday
      period = entry.period
    }
  }

  /// - Parameters:
  ///   - existing: Aktueller Stand.
  ///   - manuallyEdited: Einträge mit Herkunft „von Hand“ und Quell-Einträge, die von Hand geändert
  ///     wurden. Sie erscheinen nie in `removed` oder `changed`.
  ///   - imported: Neuer Stand aus der Quelle.
  public static func compare(
    existing: [TimetableEntry], manuallyEdited: Set<TimetableEntry>, imported: [TimetableEntry]
  ) -> ImportDiff {
    // 1. Doppelte Importeinträge streichen, die erste Fundstelle bleibt.
    var seen = Set<TimetableEntry>()
    let uniqueImported = imported.filter { seen.insert($0).inserted }

    // 2. Nach Platz gruppieren.
    let existingBySlot = Dictionary(grouping: existing, by: Slot.init)
    let importedBySlot = Dictionary(grouping: uniqueImported, by: Slot.init)
    let slots = Set(existingBySlot.keys).union(importedBySlot.keys)

    var diff = ImportDiff()
    for slot in slots {
      var oldRest = (existingBySlot[slot] ?? []).sorted(by: isOrderedBefore)
      var newRest = (importedBySlot[slot] ?? []).sorted(by: isOrderedBefore)

      // 3. Exakt gleiche Einträge paarweise streichen (Vergleich über normalisierte Namen).
      for old in oldRest {
        if let match = newRest.firstIndex(of: old) {
          newRest.remove(at: match)
          oldRest.remove(at: oldRest.firstIndex(of: old)!)
        }
      }

      // 4. Übrige der Reihe nach paaren.
      let pairCount = min(oldRest.count, newRest.count)
      for index in 0..<pairCount {
        if manuallyEdited.contains(oldRest[index]) {
          diff.manualConflicts.append((mine: oldRest[index], source: newRest[index]))
        } else {
          diff.changed.append((old: oldRest[index], new: newRest[index]))
        }
      }

      // 5. Rest: neu, entfernt (nur ohne Hand-Markierung) oder stillschweigend behalten.
      diff.added.append(contentsOf: newRest.dropFirst(pairCount))
      diff.removed.append(
        contentsOf: oldRest.dropFirst(pairCount).filter { !manuallyEdited.contains($0) })
    }

    // 6. Jede Liste deterministisch sortieren.
    diff.added.sort(by: isOrderedBefore)
    diff.removed.sort(by: isOrderedBefore)
    diff.changed.sort { isOrderedBefore($0.old, $1.old) }
    diff.manualConflicts.sort { isOrderedBefore($0.mine, $1.mine) }
    return diff
  }

  /// Reihenfolge: Wochentag, Stunde, Woche (`nil` vor A vor B), Klasse, Fach.
  private static func isOrderedBefore(_ lhs: TimetableEntry, _ rhs: TimetableEntry) -> Bool {
    func key(_ e: TimetableEntry) -> (Int, Int, Int, String, String) {
      let variantRank: Int
      switch e.weekVariant {
      case nil: variantRank = 0
      case .a?: variantRank = 1
      case .b?: variantRank = 2
      }
      return (e.weekday.rawValue, e.period, variantRank, e.schoolClass.normalized, e.subject.normalized)
    }
    return key(lhs) < key(rhs)
  }
}
