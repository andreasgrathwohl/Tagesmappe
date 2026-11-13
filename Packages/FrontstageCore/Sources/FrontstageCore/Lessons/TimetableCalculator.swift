/// Reine Berechnungen auf dem Stundenplan; liest nie die Uhr.
public enum TimetableCalculator {
  /// Wochenvariante der Woche, die `day` enthält; `nil` bei nur einer Variante.
  public static func weekVariant(for day: CalendarDay, timetable: Timetable) -> WeekVariant? {
    guard timetable.weekVariantCount == 2 else { return nil }
    let days = day.mondayOfWeek.dayNumber - timetable.referenceWeekA.mondayOfWeek.dayNumber
    // Abrunden statt Abschneiden, damit Wochen vor der Bezugswoche richtig wechseln.
    let weeks = floorDiv(days, 7)
    return weeks % 2 == 0 ? .a : .b
  }
}
