import FrontstageCore
import Foundation
import Observation

/// Ein Tag der Vorbereiten-Woche: dieselben Zeilen wie in der Tagesansicht.
struct PreparationDay: Identifiable, Hashable {
  let date: CalendarDay
  let content: DayContent
  /// Zuordnungen dieses Tages, deren Stunde es nicht (mehr) gibt.
  let materialsWithoutLesson: [MaterialLinkItem]
  var id: CalendarDay { date }
}

/// Logik der Vorbereiten-Ansicht (FR-3, FR-7): eine Woche Montag bis Freitag, Samstag und Sonntag nur
/// bei Einträgen. Den Zeilenbau teilt sie sich mit der Tagesansicht (`DayViewModel.content`).
@MainActor @Observable final class PreparationViewModel {
  private let environment: AppEnvironment

  /// Immer ein Montag.
  private(set) var weekStart: CalendarDay
  private(set) var days: [PreparationDay] = []
  /// Leistungsnachweise der Woche aus den Jahresplänen (FR-15.6).
  private(set) var weekAssessments: [PlannedAssessment] = []
  /// Die gerade zum Bearbeiten gewählte Stunde (Stundenangaben, Zuordnungen).
  var selection: LessonKey?
  let actions: LessonActions

  init(environment: AppEnvironment) {
    self.environment = environment
    self.weekStart = environment.today().mondayOfWeek
    self.actions = LessonActions(environment: environment)
    reload()
  }

  // MARK: Wochenwechsel

  func showPreviousWeek() {
    weekStart = weekStart.adding(days: -7)
    reload()
  }

  func showNextWeek() {
    weekStart = weekStart.adding(days: 7)
    reload()
  }

  func showThisWeek() {
    weekStart = environment.today().mondayOfWeek
    reload()
  }

  /// Baut die Tage der Woche neu. Samstag und Sonntag erscheinen nur, wenn sie Stunden oder
  /// Zuordnungen ohne Stunde tragen; ein bloßer Ferieneintrag am Wochenende genügt nicht.
  func reload() {
    var result: [PreparationDay] = []
    for offset in 0..<7 {
      let date = weekStart.adding(days: offset)
      let built = DayViewModel.content(
        for: date, store: environment.store, storage: environment.storage)
      if offset >= 5 {
        var hasEntries = !built.orphans.isEmpty
        if case .rows = built.content { hasEntries = true }
        if !hasEntries { continue }
      }
      result.append(
        PreparationDay(date: date, content: built.content, materialsWithoutLesson: built.orphans))
    }
    days = result
    weekAssessments = (try? environment.store.plannedAssessments(inWeekOf: weekStart)) ?? []
  }

  /// Unterrichtsstunden der nächsten `days` Tage ab heute (ohne Ausfälle) – Ziele für „Material ohne
  /// Stunde zuordnen“ (FR-7); es gibt kein automatisches Ziel.
  func upcomingLessons(days: Int) -> [Lesson] {
    let today = environment.today()
    var result: [Lesson] = []
    for offset in 0..<max(days, 0) {
      let lessons = (try? environment.store.lessons(on: today.adding(days: offset))) ?? []
      result += lessons.filter { !$0.isCancelled }
    }
    return result
  }
}
