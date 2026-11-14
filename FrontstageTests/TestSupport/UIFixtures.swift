import Foundation
import FrontstageCore

@testable import Frontstage

/// Erfundene Beispieldaten für die Oberflächen-Tests. Die globalen `tue17`, `wed18`, `thu19`,
/// `reference(_:)` und `makeStore()` stehen in `Data/Fixtures.swift` (Teilplan 02).
enum Fixtures {
  static let tue17 = CalendarDay(year: 2026, month: 11, day: 17)
  static let wed18 = CalendarDay(year: 2026, month: 11, day: 18)
  static let thu19 = CalendarDay(year: 2026, month: 11, day: 19)
  static let tue24 = CalendarDay(year: 2026, month: 11, day: 24)
  static let wed25 = CalendarDay(year: 2026, month: 11, day: 25)
  static let nov3 = CalendarDay(year: 2026, month: 11, day: 3)

  /// Montag der Bezugswoche A.
  static let referenceWeekA = CalendarDay(year: 2026, month: 11, day: 16)

  static let bellSchedule = BellSchedule(periods: [
    1: TimeOfDay(hour: 7, minute: 45)...TimeOfDay(hour: 8, minute: 30),
    2: TimeOfDay(hour: 8, minute: 35)...TimeOfDay(hour: 9, minute: 20),
    3: TimeOfDay(hour: 9, minute: 40)...TimeOfDay(hour: 10, minute: 25),
    4: TimeOfDay(hour: 10, minute: 30)...TimeOfDay(hour: 11, minute: 15),
    5: TimeOfDay(hour: 11, minute: 35)...TimeOfDay(hour: 12, minute: 20),
    6: TimeOfDay(hour: 12, minute: 25)...TimeOfDay(hour: 13, minute: 10),
  ])

  /// Legt im `DataStore` einen Stundenplan an; Bezugswoche A ist der 16.11.2026.
  @MainActor static func seed(
    _ store: DataStore, _ entries: [TimetableEntry], variants: Int = 1,
    bell: BellSchedule = bellSchedule
  ) throws {
    try store.setWeekVariants(count: variants, referenceWeekA: referenceWeekA)
    try store.setBellSchedule(bell)
    for entry in entries {
      try store.addEntry(entry)
    }
  }

  static func entry(
    _ weekday: Weekday, _ period: Int, _ cls: String, _ subject: String, _ variant: WeekVariant? = nil
  ) -> TimetableEntry {
    TimetableEntry(
      weekVariant: variant, weekday: weekday, period: period, schoolClass: SchoolClass(cls),
      subject: Subject(subject))
  }

  /// Verweis in der Freigabe „Unterricht“; der Pfad ist der Dateiname.
  static func reference(_ name: String, _ kind: MaterialFileKind) -> MaterialReference {
    MaterialReference(
      folderGrantName: "Unterricht", relativePath: name, displayName: name, fileKind: kind)
  }

  static func key(
    _ day: CalendarDay, _ cls: String, _ subject: String, _ ordinal: Int = 1
  ) -> LessonKey {
    LessonKey(
      date: day, schoolClass: SchoolClass(cls), subject: Subject(subject), ordinal: ordinal)
  }
}

/// Damit `.tue17` als implizites Glied (`Fixtures.key(.tue17, …)`, `date: .wed18`) übersetzt:
/// Swift sucht den Namen in `CalendarDay`.
extension CalendarDay {
  static let tue17 = Fixtures.tue17
  static let wed18 = Fixtures.wed18
  static let thu19 = Fixtures.thu19
  static let tue24 = Fixtures.tue24
  static let wed25 = Fixtures.wed25
  static let nov3 = Fixtures.nov3
}
