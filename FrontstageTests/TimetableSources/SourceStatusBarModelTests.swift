import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@Suite("Statusleiste der Stundenplan-Quelle")
struct SourceStatusBarModelTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }

  private func date(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
    calendar.date(
      from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
  }

  private func model(
    kind: TimetableSourceKind = .schulmanager, fetchedAt: Date?, status: SourceStatus = SourceStatus(),
    hasPendingPreview: Bool = false, hasCredentials: Bool = true, now: Date
  ) -> SourceStatusBarModel {
    SourceStatusBarModel(
      kind: kind, fetchedAt: fetchedAt, status: status, hasPendingPreview: hasPendingPreview,
      hasCredentials: hasCredentials, now: now, calendar: calendar)
  }

  @Test("Tagesansicht zeigt, von wann der Stand ist (AK-21)")
  func showsFetchedAt() {
    let result = model(fetchedAt: date(17, 7, 30), now: date(17, 7, 31))
    #expect(result.fetchedAt == date(17, 7, 30))
    #expect(result.notice == .none)
    #expect(result.isVisible)
  }

  @Test("Stand von gestern gilt als veraltet")
  func yesterdayIsStale() {
    let result = model(fetchedAt: date(16, 7, 28), now: date(17, 7, 35))
    #expect(result.notice == .stale)
  }

  @Test("Noch nie abgefragt gilt als veraltet")
  func neverFetchedIsStale() {
    #expect(model(fetchedAt: nil, now: date(17, 7, 35)).notice == .stale)
  }

  @Test("Drei Fehler in Folge schlagen jeden einzelnen Fehler")
  func threeFailuresWin() {
    var status = SourceStatus()
    status.consecutiveFailures = 3
    status.lastError = .offline
    let result = model(fetchedAt: date(17, 7, 30), status: status, now: date(17, 7, 31))
    #expect(result.notice == .suggestManualMaintenance)
  }

  @Test("Ein einzelner Fehler wird als Fehler gezeigt")
  func singleFailureIsShown() {
    var status = SourceStatus()
    status.consecutiveFailures = 1
    status.lastError = .offline
    let result = model(fetchedAt: date(17, 7, 30), status: status, now: date(17, 7, 31))
    #expect(result.notice == .failed(.offline))
  }

  @Test("Wartende Vorschau wird gemeldet")
  func pendingPreviewIsShown() {
    let result = model(fetchedAt: date(17, 7, 30), hasPendingPreview: true, now: date(17, 7, 31))
    #expect(result.notice == .previewPending)
  }

  @Test("Fehlende Zugangsdaten haben Vorrang vor allem anderen")
  func notSignedInWins() {
    var status = SourceStatus()
    status.consecutiveFailures = 5
    status.lastError = .invalidCredentials
    let result = model(
      fetchedAt: nil, status: status, hasPendingPreview: true, hasCredentials: false,
      now: date(17, 7, 31))
    #expect(result.notice == .notSignedIn)
  }

  @Test("Ohne Zugangsdaten, aber mit gespiegeltem Stand: ruhiger Hinweis, Stand bleibt sichtbar (Nachtrag 4)")
  func signInOnThisDeviceWithMirroredStand() {
    let result = model(fetchedAt: date(17, 7, 30), hasCredentials: false, now: date(17, 9, 0))
    #expect(result.notice == .signInOnThisDevice)
    #expect(result.fetchedAt == date(17, 7, 30))
    #expect(!result.canRefresh)
  }

  @Test("Mehrere Schulen bleibt nach dem Löschen der Zugangsdaten als Meldung stehen (Nachtrag 1)")
  func multipleSchoolsStaysVisibleWithoutCredentials() {
    var status = SourceStatus()
    status.consecutiveFailures = 1
    status.lastError = .multipleSchoolsUnsupported
    let result = model(
      fetchedAt: date(16, 7, 30), status: status, hasCredentials: false, now: date(17, 7, 31))
    #expect(result.notice == .failed(.multipleSchoolsUnsupported))
    #expect(!result.canRefresh)
  }

  @Test("Nach falschen Zugangsdaten heißt es „nicht angemeldet“, auch mit älterem Stand")
  func invalidCredentialsWithStandIsNotSignedIn() {
    var status = SourceStatus()
    status.consecutiveFailures = 1
    status.lastError = .invalidCredentials
    let result = model(
      fetchedAt: date(16, 7, 30), status: status, hasCredentials: false, now: date(17, 7, 31))
    #expect(result.notice == .notSignedIn)
  }

  @Test("Mit Zugangsdaten lässt sich aktualisieren")
  func canRefreshWithCredentials() {
    #expect(model(fetchedAt: nil, now: date(17, 7, 31)).canRefresh)
  }

  @Test("Quelle von Hand blendet die Leiste aus")
  func manualSourceHidesBar() {
    let result = model(kind: .manual, fetchedAt: nil, hasCredentials: false, now: date(17, 7, 31))
    #expect(!result.isVisible)
  }
}
