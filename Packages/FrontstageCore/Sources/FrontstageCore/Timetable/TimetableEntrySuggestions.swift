import Foundation

/// Vorschläge für Klasse und Fach beim Eintragen einer Stunde von Hand (FR-1.3), aus dem vorhandenen Stundenplan.
/// Ein Vorschlag setzt nur das Feld; gesichert wird nie ohne ausdrücklichen Knopf.
public enum TimetableEntrySuggestions {
  /// Höchstzahl je Zeile, damit die Zeile überschaubar bleibt.
  public static let limit = 8

  /// Klassen nach Häufigkeit, bei Gleichstand alphabetisch (natürliche Zahlfolge: „9c“ vor „10a“). Gefiltert auf
  /// Klassen, deren normalisierter Name mit der normalisierten Eingabe beginnt; die genau getippte Klasse entfällt.
  public static func classes(in entries: [TimetableEntry], matching input: String) -> [SchoolClass] {
    let typed = SchoolClass(input).normalized
    var counts: [SchoolClass: Int] = [:]
    for entry in entries { counts[entry.schoolClass, default: 0] += 1 }
    return counts
      .filter { $0.key.normalized.hasPrefix(typed) && $0.key.normalized != typed }
      .sorted { lhs, rhs in
        lhs.value != rhs.value
          ? lhs.value > rhs.value
          : lhs.key.normalized.localizedStandardCompare(rhs.key.normalized) == .orderedAscending
      }
      .prefix(limit)
      .map(\.key)
  }

  /// Fächer: zuerst die der Klasse `schoolClass`, dann die übrigen, je nach Häufigkeit, bei Gleichstand
  /// alphabetisch. Gefiltert wie bei den Klassen; je Fach die häufigste Schreibweise.
  public static func subjects(
    in entries: [TimetableEntry], forClass schoolClass: SchoolClass?, matching input: String
  ) -> [Subject] {
    let typed = Subject(input).normalized
    var total: [String: Int] = [:]
    var inClass: [String: Int] = [:]
    var spellings: [String: [String: Int]] = [:]
    for entry in entries {
      let key = entry.subject.normalized
      total[key, default: 0] += 1
      if entry.schoolClass == schoolClass { inClass[key, default: 0] += 1 }
      spellings[key, default: [:]][entry.subject.display, default: 0] += 1
    }
    let keys = total.keys
      .filter { $0.hasPrefix(typed) && $0 != typed }
      .sorted { lhs, rhs in
        let l = (inClass[lhs] ?? 0, total[lhs] ?? 0)
        let r = (inClass[rhs] ?? 0, total[rhs] ?? 0)
        if (l.0 > 0) != (r.0 > 0) { return l.0 > 0 }
        if l.0 != r.0 { return l.0 > r.0 }
        if l.1 != r.1 { return l.1 > r.1 }
        return lhs.localizedStandardCompare(rhs) == .orderedAscending
      }
    return keys.prefix(limit).map { key in
      let spelling = (spellings[key] ?? [:])
        .max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }?.key ?? key
      return Subject(spelling)
    }
  }
}

/// Bewegung im Raster des Stundenplan-Editors (FR-1.3).
public enum TimetableGridNavigation {
  public struct Slot: Hashable, Sendable {
    public var weekday: Weekday
    public var period: Int

    public init(weekday: Weekday, period: Int) {
      self.weekday = weekday
      self.period = period
    }
  }

  /// Nächstes freies Feld nach (`weekday`, `period`) in Rasterreihenfolge: erst weiter unten am selben Tag, dann die
  /// folgenden Tage ab der ersten Stunde. `nil`, wenn bis zum letzten Tag nichts frei ist (kein Umlauf zum Montag).
  public static func nextFreeSlot(
    after weekday: Weekday, period: Int, weekdays: [Weekday], periods: [Int],
    isOccupied: (Weekday, Int) -> Bool
  ) -> Slot? {
    let sortedPeriods = periods.sorted()
    for day in weekdays where day.rawValue >= weekday.rawValue {
      for candidate in sortedPeriods where day != weekday || candidate > period {
        if !isOccupied(day, candidate) { return Slot(weekday: day, period: candidate) }
      }
    }
    return nil
  }
}

/// Eine Stunde auf andere Wochentage übernehmen (FR-1.3): gleiche Stunde, Klasse, Fach und Woche.
public enum TimetableEntryCopy {
  public struct Plan: Hashable, Sendable {
    /// Neu anzulegende Einträge, in Wochentag-Reihenfolge.
    public var additions: [TimetableEntry]
    /// Tage, an denen das Feld schon belegt ist; dort wird nichts angelegt.
    public var occupied: [Weekday]
  }

  /// Ein Feld gilt als belegt, wenn dort schon ein Eintrag steht, dessen Woche sich mit der des Eintrags
  /// überschneidet (ohne Woche überschneidet sich mit jeder). Der eigene Tag wird ignoriert.
  public static func plan(copying entry: TimetableEntry, to weekdays: Set<Weekday>, existing: [TimetableEntry])
    -> Plan
  {
    var additions: [TimetableEntry] = []
    var occupied: [Weekday] = []
    for day in Weekday.allCases where weekdays.contains(day) && day != entry.weekday {
      let taken = existing.contains { other in
        other.weekday == day && other.period == entry.period
          && (other.weekVariant == nil || entry.weekVariant == nil || other.weekVariant == entry.weekVariant)
      }
      if taken {
        occupied.append(day)
      } else {
        var copy = entry
        copy.weekday = day
        additions.append(copy)
      }
    }
    return Plan(additions: additions, occupied: occupied)
  }
}
