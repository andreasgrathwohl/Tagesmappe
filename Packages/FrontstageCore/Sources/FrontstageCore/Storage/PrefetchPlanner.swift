import Foundation

/// Bestimmt, welche Stunden und Dateien für den Offline-Betrieb bereitgehalten werden (NFR-1).
public enum PrefetchPlanner {
  /// Unterrichtsstunden von heute (alle, auch vergangene) und vom nächsten Tag mit mindestens einer
  /// nicht ausgefallenen Unterrichtsstunde, höchstens `lookaheadDays` Tage voraus. Ausfälle zählen nicht.
  public static func lessonKeys(
    today: CalendarDay, timetable: Timetable, nonTeachingPeriods: [NonTeachingPeriod],
    changes: [ScheduleChange], lookaheadDays: Int = 14
  ) -> [LessonKey] {
    func activeKeys(on day: CalendarDay) -> [LessonKey] {
      TimetableCalculator.lessons(
        on: day, timetable: timetable, nonTeachingPeriods: nonTeachingPeriods, changes: changes
      )
      .filter { !$0.isCancelled }
      .map(\.key)
    }

    var result = activeKeys(on: today)
    // `1...n` ist bei n < 1 ungültig; deshalb über `stride` laufen.
    for offset in stride(from: 1, through: lookaheadDays, by: 1) {
      let next = activeKeys(on: today.adding(days: offset))
      if !next.isEmpty {
        result += next
        break
      }
    }
    return result
  }

  /// Verweise dieser Stunden, ohne Doppelte (gleicher locationKey), in Reihenfolge des ersten Auftretens.
  public static func references(
    for keys: [LessonKey], links: [(key: LessonKey, reference: MaterialReference)]
  ) -> [MaterialReference] {
    let wanted = Set(keys)
    var seen = Set<String>()
    var result: [MaterialReference] = []
    for link in links where wanted.contains(link.key) {
      if seen.insert(link.reference.locationKey).inserted {
        result.append(link.reference)
      }
    }
    return result
  }
}
