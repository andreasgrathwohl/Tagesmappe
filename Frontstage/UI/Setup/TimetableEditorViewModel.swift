import Foundation
import FrontstageCore
import Observation

/// Fehler beim Eintragen einer festen Stunde von Hand.
enum TimetableEditError: Error, Equatable {
  case emptyClass
  case emptySubject
  case invalidPeriod
  case duplicate
  /// Das Speichern im `DataStore` ist gescheitert (kommt nicht aus dem Plan; Speichern kann immer scheitern).
  case saveFailed
}

/// Logik von „Einrichten › Stundenplan“ (FR-1, FR-1.1): Stunden von Hand anlegen, ändern, löschen,
/// Wochenrhythmus (eine oder zwei Wochen) und Bezugswoche.
///
/// Swift-Hinweis: `throws(TimetableEditError)` ist eine typisierte Fehlerdeklaration (Swift 6): Aufrufer
/// bekommen genau diesen Fehlertyp und können im `catch` ohne Typumwandlung darauf prüfen.
@MainActor @Observable final class TimetableEditorViewModel {
  private let environment: AppEnvironment

  /// 1 oder 2; ohne Stundenplan 1.
  private(set) var weekVariantCount: Int = 1
  /// Immer ein Montag. Ohne Stundenplan die laufende Woche.
  private(set) var referenceWeekA: CalendarDay
  /// Ansicht bei zwei Varianten.
  var shownVariant: WeekVariant = .a
  /// Letzter Fehler einer Aktion ohne eigenen `throws`-Weg (Löschen, Rhythmus, Bezugswoche); die Ansicht
  /// zeigt ihn an und setzt ihn zurück.
  var lastFailure: TimetableEditError?

  private(set) var allEntries: [TimetableEntry] = []
  private var bellSchedule = BellSchedule()

  init(environment: AppEnvironment) {
    self.environment = environment
    self.referenceWeekA = environment.today().mondayOfWeek
    reload()
  }

  /// Liest den Stand aus dem `DataStore` neu (auch nach Änderungen vom anderen Gerät).
  func reload() {
    guard let timetable = try? environment.store.timetable() else {
      weekVariantCount = 1
      allEntries = []
      bellSchedule = BellSchedule()
      shownVariant = .a
      return
    }
    weekVariantCount = timetable.weekVariantCount
    referenceWeekA = timetable.referenceWeekA.mondayOfWeek
    allEntries = timetable.entries
    bellSchedule = timetable.bellSchedule
    if weekVariantCount == 1 { shownVariant = .a }
  }

  /// Stundennummern der Zeilen im Raster: Schlüssel des Zeitrasters, ohne Zeitraster 1…10.
  var periodChoices: [Int] {
    let keys = bellSchedule.periods.keys.sorted()
    return keys.isEmpty ? Array(1...10) : keys
  }

  /// Zeilen des Rasters: die Auswahl plus Stunden, die Einträge belegen (etwa aus einem Import) und im
  /// Zeitraster fehlen – sonst wären sie im Raster unsichtbar.
  var gridPeriods: [Int] {
    Set(periodChoices).union(allEntries.map(\.period)).sorted()
  }

  /// Montag bis Freitag; Samstag und Sonntag nur, wenn dort Einträge stehen.
  var weekdays: [Weekday] {
    let used = Set(allEntries.map(\.weekday))
    return Weekday.allCases.filter { $0.rawValue <= 5 || used.contains($0) }
  }

  /// Einträge eines Feldes in der gezeigten Variante; Einträge ohne Variante gelten in beiden.
  func entries(weekday: Weekday, period: Int) -> [TimetableEntry] {
    allEntries
      .filter { $0.weekday == weekday && $0.period == period && isShown($0) }
      .sorted { ($0.schoolClass.normalized, $0.subject.normalized) < ($1.schoolClass.normalized, $1.subject.normalized) }
  }

  private func isShown(_ entry: TimetableEntry) -> Bool {
    guard weekVariantCount == 2, let variant = entry.weekVariant else { return true }
    return variant == shownVariant
  }

  // MARK: Einträge

  /// Legt eine Stunde an (`old == nil`, Herkunft `.manual`) oder ändert eine vorhandene.
  func save(_ entry: TimetableEntry, replacing old: TimetableEntry?) throws(TimetableEditError) {
    guard !entry.schoolClass.normalized.isEmpty else { throw .emptyClass }
    guard !entry.subject.normalized.isEmpty else { throw .emptySubject }
    guard entry.period >= 1 else { throw .invalidPeriod }
    reload()
    var entry = entry
    // Bei einer Variante gibt es keine A-/B-Zuordnung.
    if weekVariantCount == 1 { entry.weekVariant = nil }
    // Unverändert gesichert: nichts schreiben. Sonst würde `replaceEntry` einen Eintrag aus der Quelle als
    // „von Hand geändert“ markieren, und die nächste Import-Vorschau zeigte einen Konflikt (AK-3).
    if let old, entry == old { return }
    if entry != old, allEntries.contains(entry) { throw .duplicate }
    do {
      if let old {
        try environment.store.replaceEntry(old, with: entry)
      } else {
        try environment.store.addEntry(entry, origin: .manual)
      }
    } catch {
      throw .saveFailed
    }
    reload()
  }

  func delete(_ entry: TimetableEntry) {
    do {
      try environment.store.removeEntry(entry)
    } catch {
      lastFailure = .saveFailed
    }
    reload()
  }

  // MARK: Wochenrhythmus

  /// Setzt die Bezugswoche auf die Woche, die `day` enthält.
  func setReferenceWeek(containing day: CalendarDay) {
    write(count: weekVariantCount, reference: day.mondayOfWeek)
  }

  /// Wechselt zwischen einer und zwei Wochenvarianten.
  ///
  /// 2 → 1 mit B-Einträgen: liefert deren Zahl und ändert nichts, bis `confirmed == true` (Regel aus
  /// Teilplan 01: B-Einträge fallen weg). Dann werden sie gelöscht und die A-Einträge zu Einträgen ohne
  /// Variante. Sonst `nil`.
  func setWeekVariantCount(_ count: Int, confirmed: Bool) -> Int? {
    guard count == 1 || count == 2, count != weekVariantCount else { return nil }
    reload()
    if count == 1 {
      let bEntries = allEntries.filter { $0.weekVariant == .b }
      if !bEntries.isEmpty && !confirmed { return bEntries.count }
      do {
        for entry in bEntries { try environment.store.removeEntry(entry) }
        var plainEntries = Set(allEntries.filter { $0.weekVariant == nil })
        for entry in allEntries where entry.weekVariant == .a {
          var plain = entry
          plain.weekVariant = nil
          if plainEntries.contains(plain) {
            // Dieselbe Stunde gibt es schon ohne Variante: A-Eintrag löschen statt doppeln (sonst doppelte
            // Unterrichtsstunden).
            try environment.store.removeEntry(entry)
          } else {
            try environment.store.replaceEntry(entry, with: plain)
            plainEntries.insert(plain)
          }
        }
      } catch {
        lastFailure = .saveFailed
        reload()
        return nil
      }
    }
    write(count: count, reference: referenceWeekA)
    return nil
  }

  private func write(count: Int, reference: CalendarDay) {
    do {
      try environment.store.setWeekVariants(count: count, referenceWeekA: reference)
    } catch {
      lastFailure = .saveFailed
    }
    reload()
  }

  /// Vorbelegung „gilt für“ im Eintragsblatt. Nur ein neuer Eintrag bekommt die gezeigte Variante;
  /// ein bestehender behält seine eigene – auch „beide Wochen“ (nil), sonst würde Speichern ihn still zu A-only.
  func initialVariant(editing: TimetableEntry?) -> WeekVariant? {
    if let editing { return editing.weekVariant }
    return weekVariantCount == 2 ? shownVariant : nil
  }
}

