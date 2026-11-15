import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// Leere Zustände der Tagesansicht (UI-13).
@Suite struct DayEmptyStateTests {
  @Test("UI-13: Ferien mit Namen")
  func nonTeachingDayKeepsTitle() {
    let state = DayEmptyState.make(
      content: .nonTeachingDay(title: "Herbstferien"), sourceKind: .manual, fetchedAt: nil,
      lastError: nil)
    #expect(state == .nonTeachingDay(title: "Herbstferien"))
  }

  @Test("UI-13: Fehler ohne jeden Stand nur bei Quelle mit Fehler")
  func sourceFailedOnlyWithoutAnyState() {
    func make(_ kind: TimetableSourceKind, _ fetched: Date?, _ error: TimetableSourceError?)
      -> DayEmptyState?
    {
      DayEmptyState.make(content: .noLessons, sourceKind: kind, fetchedAt: fetched, lastError: error)
    }
    #expect(make(.schulmanager, nil, .offline) == .sourceFailed(.offline))
    #expect(make(.schulmanager, nil, nil) == .noLessons)
    #expect(make(.schulmanager, Date(), .offline) == .noLessons)
    #expect(make(.manual, nil, .offline) == .noLessons)
  }

  @Test("Zeilen vorhanden: kein leerer Zustand")
  func rowsHaveNoEmptyState() {
    #expect(
      DayEmptyState.make(
        content: .rows([.noLesson(period: 1, time: nil)]), sourceKind: .schulmanager, fetchedAt: nil,
        lastError: .offline) == nil)
  }
}
