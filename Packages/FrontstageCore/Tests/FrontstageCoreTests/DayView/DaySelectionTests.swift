import Foundation
import Testing

@testable import FrontstageCore

@Suite("DayView Selection")
struct DaySelectionTests {
  private let l1 = CoreFixtures.lesson("8b", "Englisch", period: 1, from: (7, 45), to: (8, 30))
  private let l2 = CoreFixtures.lesson("9c", "Deutsch", period: 2, from: (8, 35), to: (9, 20))
  private let l3 = CoreFixtures.lesson("7a", "Mathe", period: 3, from: (9, 40), to: (10, 25))
  private var all: [Lesson] { [l1, l2, l3] }
  private var key8b: LessonKey { l1.key }
  private var key9c: LessonKey { l2.key }
  private var key7a: LessonKey { l3.key }

  @Test("UI-3: laufende Stunde gewählt")
  func selectsRunningLesson() {
    #expect(DaySelection.automaticTarget(lessons: all, now: t(8, 40)) == key9c)
  }

  @Test("In der Pause die nächste")
  func selectsNextDuringBreak() {
    #expect(DaySelection.automaticTarget(lessons: all, now: t(9, 25)) == key7a)
  }

  @Test("Ausgefallene laufende Stunde wird übersprungen")
  func skipsCancelledRunningLesson() {
    let cancelled = CoreFixtures.lesson(
      "9c", "Deutsch", period: 2, from: (8, 35), to: (9, 20), cancelled: true)
    #expect(
      DaySelection.automaticTarget(lessons: [l1, cancelled, l3], now: t(8, 40)) == key7a)
  }

  @Test("Nach der letzten Stunde die letzte")
  func selectsLastAfterDayEnds() {
    #expect(DaySelection.automaticTarget(lessons: all, now: t(14, 0)) == key7a)
  }

  @Test("Anderer Tag: erste Stunde")
  func otherDaySelectsFirst() {
    #expect(DaySelection.automaticTarget(lessons: all, now: nil) == key8b)
  }

  @Test("Ohne Zeitraster: erste Stunde")
  func withoutTimesSelectsFirst() {
    let untimed = [l1, l2].map {
      Lesson(
        key: $0.key, period: $0.period, time: nil, isSubstituteLesson: false,
        isCancelled: false, cancellationOrigin: nil)
    }
    #expect(DaySelection.automaticTarget(lessons: untimed, now: t(8, 40)) == key8b)
  }

  @Test("Nur Ausfälle: erste Stunde")
  func allCancelledSelectsFirstLesson() {
    let cancelled = all.map {
      Lesson(
        key: $0.key, period: $0.period, time: $0.time, isSubstituteLesson: false,
        isCancelled: true, cancellationOrigin: .manual)
    }
    #expect(DaySelection.automaticTarget(lessons: cancelled, now: t(8, 40)) == key8b)
    #expect(DaySelection.automaticTarget(lessons: [], now: t(8, 40)) == nil)
  }

  @Test("Handauswahl bleibt beim Stundenwechsel")
  func manualSelectionSurvivesLessonChange() {
    var s = DaySelection()
    s.update(lessons: all, now: t(8, 40))
    s.select(key8b, lessons: all, now: t(8, 40))
    #expect(s.isManual)
    s.update(lessons: all, now: t(9, 45))
    #expect(s.selected == key8b)
  }

  @Test("Wahl der automatischen Stunde bleibt automatisch")
  func selectingAutomaticTargetStaysAutomatic() {
    var s = DaySelection()
    s.update(lessons: all, now: t(8, 40))
    s.select(key9c, lessons: all, now: t(8, 40))
    #expect(!s.isManual)
    s.update(lessons: all, now: t(9, 45))
    #expect(s.selected == key7a)
  }

  @Test("Zurück in schmaler Breite: keine Auswahl bleibt")
  func manualDeselectStaysNil() {
    var s = DaySelection()
    s.update(lessons: all, now: t(8, 40))
    s.select(nil, lessons: all, now: t(8, 40))
    #expect(s.selected == nil)
    #expect(s.isManual)
    s.update(lessons: all, now: t(9, 45))
    #expect(s.selected == nil)
  }

  @Test("Verschwundene Handauswahl fällt auf die Automatik")
  func vanishedManualFallsBackToAutomatic() {
    var s = DaySelection()
    s.update(lessons: all, now: t(8, 40))
    s.select(key8b, lessons: all, now: t(8, 40))
    s.update(lessons: [l2, l3], now: t(8, 40))
    #expect(s.selected == key9c)
    #expect(!s.isManual)
  }

  @Test("reset kehrt zur Automatik zurück")
  func resetReturnsToAutomatic() {
    var s = DaySelection()
    s.update(lessons: all, now: t(8, 40))
    s.select(key8b, lessons: all, now: t(8, 40))
    s.reset()
    #expect(s.selected == nil)
    #expect(!s.isManual)
    s.update(lessons: all, now: t(8, 40))
    #expect(s.selected == key9c)
  }

  @Test("UI-12: Jetzt nur während einer Stunde")
  func runningLessonOnlyWhileRunning() {
    #expect(DaySelection.runningLesson(lessons: all, now: t(8, 40)) == key9c)
    #expect(DaySelection.runningLesson(lessons: all, now: t(9, 25)) == nil)
    #expect(DaySelection.runningLesson(lessons: all, now: t(7, 0)) == nil)
    let cancelled = CoreFixtures.lesson(
      "9c", "Deutsch", period: 2, from: (8, 35), to: (9, 20), cancelled: true)
    #expect(DaySelection.runningLesson(lessons: [l1, cancelled, l3], now: t(8, 40)) == nil)
  }
}
