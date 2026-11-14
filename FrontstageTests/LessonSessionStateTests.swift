import AVFoundation
import FrontstageCore
import Foundation
import Testing

@testable import Frontstage

@MainActor @Suite struct LessonSessionStateTests {
  let a = LessonKey(
    date: CalendarDay(year: 2026, month: 11, day: 17), schoolClass: SchoolClass("8b"),
    subject: Subject("Englisch"), ordinal: 1)
  let b = LessonKey(
    date: CalendarDay(year: 2026, month: 11, day: 17), schoolClass: SchoolClass("9c"),
    subject: Subject("Mathe"), ordinal: 1)

  @Test("Arbeitsform gilt nur für die laufende Unterrichtsstunde (FR-11.3)")
  func workModeResetsOnLessonChange() {
    let s = LessonSessionState(signal: nil)
    s.lessonDidChange(to: a)
    s.workMode = .pairs
    s.lessonDidChange(to: a)
    #expect(s.workMode == .pairs)
    s.lessonDidChange(to: b)
    #expect(s.workMode == nil)
  }

  @Test("Arbeitsform bleibt, wenn sie vor dem ersten Melden der Stunde gewählt wurde (FR-11.3)")
  func workModeChosenBeforeReportSurvives() {
    let s = LessonSessionState(signal: nil)
    s.lessonDidChange(to: a)
    // Stundenwechsel, während Material am Zweitbildschirm steht: die neue Stunde wurde noch nicht gemeldet.
    s.selectWorkMode(.pairs, for: b)
    s.lessonDidChange(to: b)
    #expect(s.workMode == .pairs)
    #expect(s.lessonKey == b)
  }

  @Test("Zuletzt verwendete Timerdauer ist geteilt, Vorgabe 5 Minuten (FR-11.2)")
  func timerMinutesDefault() {
    let s = LessonSessionState(signal: nil)
    #expect(s.timerMinutes == 5)
  }

  @Test("Laufender Timer überdauert den Stundenwechsel (FR-11.2)")
  func timerSurvivesLessonChange() {
    let s = LessonSessionState(signal: nil)
    let now = Date()
    s.lessonDidChange(to: a)
    s.startTimer(minutes: 5, now: now)
    s.lessonDidChange(to: b)
    #expect(s.timer.remaining(at: now) == 300)
  }

  @Test("Pause und Fortsetzen rechnen aus dem Endzeitpunkt")
  func pauseAndResume() {
    let s = LessonSessionState(signal: nil)
    let now = Date()
    s.startTimer(minutes: 5, now: now)
    s.pauseTimer(now: now.addingTimeInterval(60))
    #expect(s.timer.remaining(at: now.addingTimeInterval(600)) == 240)
    s.resumeTimer(now: now.addingTimeInterval(600))
    #expect(s.timer.remaining(at: now.addingTimeInterval(660)) == 180)
    s.stopTimer()
    #expect(s.timer.remaining(at: now) == nil)
  }

  @Test("Signalpuffer hat drei Töne mit zwei Pausen")
  func signalBufferLength() throws {
    let buffer = try #require(TimerSignalPlayer.makeSignalBuffer())
    #expect(buffer.frameLength == AVAudioFrameCount(3 * 13_230 + 2 * 8_820))
  }
}
