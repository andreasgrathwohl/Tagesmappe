import Foundation

/// Auswahl der Stunde in der Tagesansicht (UI-3, UI-12): folgt der Automatik, bis die Lehrkraft
/// von Hand eine andere Stunde wählt.
/// `now == nil` bedeutet: der angezeigte Tag ist nicht heute.
public struct DaySelection: Hashable, Sendable {
  public private(set) var selected: LessonKey?
  public private(set) var isManual: Bool

  public init() {
    selected = nil
    isManual = false
  }

  /// Neuer Stand oder Minutentakt: Eine Handauswahl bleibt, solange es die Stunde gibt (eine
  /// Handauswahl `nil` bleibt `nil`); sonst gilt das automatische Ziel.
  public mutating func update(lessons: [Lesson], now: TimeOfDay?) {
    if isManual {
      guard let current = selected else { return }
      if lessons.contains(where: { $0.key == current }) { return }
    }
    selected = Self.automaticTarget(lessons: lessons, now: now)
    isManual = false
  }

  /// Von Hand gewählt: manuell ist die Wahl nur, wenn sie vom automatischen Ziel abweicht.
  public mutating func select(_ key: LessonKey?, lessons: [Lesson], now: TimeOfDay?) {
    selected = key
    isManual = key != Self.automaticTarget(lessons: lessons, now: now)
  }

  /// Tageswechsel, „Heute“, neuer Kalendertag: zurück zur Automatik (danach `update`).
  public mutating func reset() {
    selected = nil
    isManual = false
  }

  /// Laufende, sonst nächste Stunde ohne Ausfall; nach der letzten die letzte ohne Ausfall; ohne Zeiten
  /// oder an einem anderen Tag die erste ohne Ausfall; nur Ausfälle → die erste; keine Stunden → `nil`.
  public static func automaticTarget(lessons: [Lesson], now: TimeOfDay?) -> LessonKey? {
    let active = lessons.filter { !$0.isCancelled }
    guard !active.isEmpty else { return lessons.first?.key }
    guard let now else { return active.first?.key }

    switch ClassScreenCalculator.phase(now: now, lessons: lessons) {
    case .inLesson(let lesson), .finalMinutes(let lesson), .upcoming(let lesson):
      return lesson.key
    case .noMoreLessons:
      let timed = active.compactMap { lesson in lesson.time.map { (lesson, $0.lowerBound) } }
      return timed.max { $0.1 < $1.1 }?.0.key ?? active.first?.key
    }
  }

  /// Nur während einer Stunde ohne Ausfall (Pause, vor der ersten, nach der letzten: `nil`).
  public static func runningLesson(lessons: [Lesson], now: TimeOfDay) -> LessonKey? {
    ClassScreenCalculator.phase(now: now, lessons: lessons).runningLessonKey
  }
}
