/// Leitet aus der Uhrzeit und den Stunden des Tages die Phase des Klassenbildschirms ab; liest nie die Uhr.
public enum ClassScreenCalculator {
  /// Berücksichtigt nur Stunden, die stattfinden und eine Zeit haben. Das Ende einer Stunde gehört
  /// nicht mehr dazu (9:20 ist nicht mehr in der Stunde 8:35 bis 9:20).
  /// - Parameter finalMinutes: Anzahl Minuten vor dem Ende, ab der `.finalMinutes` gilt.
  public static func phase(
    now: TimeOfDay, lessons: [Lesson], finalMinutes: Int = 5
  ) -> ClassScreenPhase {
    let timed: [(lesson: Lesson, time: ClosedRange<TimeOfDay>)] =
      lessons
      .filter { !$0.isCancelled }
      .compactMap { lesson in lesson.time.map { (lesson, $0) } }
      .sorted { $0.time.lowerBound < $1.time.lowerBound }

    if let running = timed.first(where: { $0.time.lowerBound <= now && now < $0.time.upperBound }) {
      let threshold = running.time.upperBound.minutesSinceMidnight - finalMinutes
      return now.minutesSinceMidnight >= threshold
        ? .finalMinutes(running.lesson) : .inLesson(running.lesson)
    }
    if let next = timed.first(where: { $0.time.lowerBound > now }) {
      return .upcoming(next.lesson)
    }
    return .noMoreLessons
  }
}
