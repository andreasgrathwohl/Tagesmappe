import Foundation
import Testing

@testable import FrontstageCore

@Suite("MorningRefreshPolicy")
struct MorningRefreshPolicyTests {
  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
  }()

  private func date(_ day: Int, _ hour: Int, _ minute: Int, second: Int = 0) -> Date {
    calendar.date(
      from: DateComponents(
        year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second))!
  }

  @Test("Erstes Aktivieren am neuen Tag fragt ab (AK-21)")
  func activationOnNewDayTriggersFetch() {
    var status = SourceStatus()
    status = status.recordingSuccess(at: date(16, 7, 28))
    #expect(
      MorningRefreshPolicy.shouldFetch(
        .appBecameActive, status: status, now: date(17, 7, 30), calendar: calendar))
  }

  @Test("Nach einem Erfolg heute keine zweite automatische Abfrage")
  func noSecondAutomaticFetchAfterSuccess() {
    let status = SourceStatus()
      .recordingAttempt(.appBecameActive, at: date(17, 7, 29), calendar: calendar)
      .recordingSuccess(at: date(17, 7, 30))
    #expect(
      !MorningRefreshPolicy.shouldFetch(
        .appBecameActive, status: status, now: date(17, 10, 0), calendar: calendar))
    #expect(
      !MorningRefreshPolicy.shouldFetch(
        .backgroundRefresh, status: status, now: date(17, 10, 0), calendar: calendar))
  }

  @Test("Automatischer Wiederholversuch erst nach 30 Minuten")
  func automaticRetryWaits30Minutes() {
    let status = SourceStatus()
      .recordingAttempt(.appBecameActive, at: date(17, 7, 30), calendar: calendar)
      .recordingFailure(.offline, at: date(17, 7, 30))
    #expect(
      !MorningRefreshPolicy.shouldFetch(
        .appBecameActive, status: status, now: date(17, 7, 45), calendar: calendar))
    #expect(
      MorningRefreshPolicy.shouldFetch(
        .appBecameActive, status: status, now: date(17, 8, 0), calendar: calendar))
  }

  @Test("Höchstens 3 automatische Versuche je Tag")
  func automaticAttemptsAreCappedPerDay() {
    var status = SourceStatus()
    for hour in [7, 8, 9] {
      status = status
        .recordingAttempt(.backgroundRefresh, at: date(17, hour, 0), calendar: calendar)
        .recordingFailure(.offline, at: date(17, hour, 0))
    }
    #expect(status.automaticAttemptsCount == 3)
    #expect(
      !MorningRefreshPolicy.shouldFetch(
        .appBecameActive, status: status, now: date(17, 12, 0), calendar: calendar))
    #expect(
      MorningRefreshPolicy.shouldFetch(
        .appBecameActive, status: status, now: date(18, 7, 0), calendar: calendar))
  }

  @Test("Knopfdruck wird entprellt, auch nach Erfolg heute")
  func userRequestIsDebounced() {
    let attempt = SourceStatus()
      .recordingAttempt(.userRequest, at: date(17, 7, 30), calendar: calendar)
    #expect(
      !MorningRefreshPolicy.shouldFetch(
        .userRequest, status: attempt, now: date(17, 7, 30, second: 30), calendar: calendar))
    #expect(
      MorningRefreshPolicy.shouldFetch(
        .userRequest, status: attempt, now: date(17, 7, 31, second: 1), calendar: calendar))
    let succeeded = attempt.recordingSuccess(at: date(17, 7, 30))
    #expect(
      MorningRefreshPolicy.shouldFetch(
        .userRequest, status: succeeded, now: date(17, 9, 0), calendar: calendar))
  }

  @Test("Knopfdruck zählt nicht zu den automatischen Versuchen")
  func userRequestDoesNotCountAsAutomatic() {
    let status = SourceStatus()
      .recordingAttempt(.userRequest, at: date(17, 7, 30), calendar: calendar)
    #expect(status.automaticAttemptsCount == 0)
  }

  @Test("Drei Fehler in Folge empfehlen Pflege von Hand")
  func threeFailuresSuggestManualMaintenance() {
    var status = SourceStatus()
    status = status.recordingFailure(.offline, at: date(17, 7, 0))
    status = status.recordingFailure(.offline, at: date(17, 8, 0))
    #expect(!status.suggestsManualMaintenance)
    status = status.recordingFailure(.server(status: 500), at: date(17, 9, 0))
    #expect(status.suggestsManualMaintenance)
    #expect(status.lastError == .server(status: 500))
    status = status.recordingSuccess(at: date(18, 7, 0))
    #expect(!status.suggestsManualMaintenance)
    #expect(status.lastError == nil)
  }

  @Test("Veraltet, wenn der letzte Erfolg nicht heute war")
  func staleWhenLastSuccessYesterday() {
    #expect(SourceStatus().isStale(now: date(17, 9, 0), calendar: calendar))
    let yesterday = SourceStatus().recordingSuccess(at: date(16, 7, 28))
    #expect(yesterday.isStale(now: date(17, 9, 0), calendar: calendar))
    let today = SourceStatus().recordingSuccess(at: date(17, 7, 28))
    #expect(!today.isStale(now: date(17, 9, 0), calendar: calendar))
  }

  @Test("Hintergrund-Beginn: nächster Tag 05:30 Ortszeit")
  func nextBackgroundBeginIsNextDayHalfPastFive() {
    let begin = MorningRefreshPolicy.nextBackgroundBeginDate(
      after: date(16, 21, 0), calendar: calendar)
    #expect(begin == date(17, 5, 30))
  }

  @Test("Status übersteht Kodieren und Dekodieren")
  func statusRoundTripsThroughJSON() throws {
    let status = SourceStatus()
      .recordingAttempt(.appBecameActive, at: date(17, 7, 30), calendar: calendar)
      .recordingFailure(.invalidCredentials, at: date(17, 7, 30))
    let data = try JSONEncoder().encode(status)
    #expect(try JSONDecoder().decode(SourceStatus.self, from: data) == status)
  }
}
