import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// Aussagen an einer Stunde und die zweite Zeile der Liste (UI-3, UI-4, UI-11).
@Suite struct LessonStatementTests {
  private func row(
    status: LessonStatus = .regular, materials: [MaterialRow] = [], topic: String? = nil
  ) -> LessonRow {
    let key = Fixtures.key(.tue17, "8b", "Englisch")
    var isCancelled = false
    if case .cancelled = status { isCancelled = true }
    let lesson = Lesson(
      key: key, period: 2, time: Fixtures.bellSchedule.periods[2],
      isSubstituteLesson: status == .substitute, isCancelled: isCancelled,
      cancellationOrigin: isCancelled ? .manual : nil)
    return LessonRow(
      lesson: lesson, status: status, materials: materials, info: LessonInfo(topic: topic))
  }

  private func material(_ availability: MaterialAvailability? = nil) -> MaterialRow {
    MaterialRow(
      item: MaterialLinkItem(
        id: UUID(), lessonKey: nil, position: 0,
        reference: Fixtures.reference("Blatt", .pdf)),
      availability: availability)
  }

  private let stored: (MaterialRow) -> MaterialAvailability? = { $0.availability }

  @Test("UI-11: nur Entfällt und nicht verfügbar tragen eine Signalfarbe")
  func onlyTwoStatementsCarrySignal() {
    #expect(LessonStatement.cancellation.signal == .cancellation)
    #expect(LessonStatement.materialUnavailable.signal == .unavailable)
    #expect(LessonStatement.substitute.signal == nil)
    #expect(LessonStatement.lessonWithoutMaterial.signal == nil)
    #expect(LessonStatement.substitute.symbolName == "arrow.triangle.swap")
    #expect(LessonStatement.substitute.labelKey == "dayView.substitute")
  }

  @Test("Liste: Ausfall vor Vertretung vor Material vor Thema")
  func listLinePriority() {
    let unavailable = material(.unavailable(.fileMissing))
    #expect(
      row(status: .cancelled(.manual), materials: [unavailable], topic: "T")
        .listLine(availability: stored) == .statement(.cancellation))
    #expect(
      row(status: .substitute, materials: [unavailable], topic: "T")
        .listLine(availability: stored) == .statement(.substitute))
    #expect(
      row(materials: [unavailable], topic: "T").listLine(availability: stored)
        == .statement(.materialUnavailable))
    #expect(
      row(materials: [material()], topic: "Unit 4").listLine(availability: stored)
        == .topic("Unit 4"))
  }

  @Test("Detail: Vertretung und Ohne Material zusammen")
  func detailListsAllStatements() {
    #expect(
      row(status: .substitute).statements(availability: stored)
        == [.substitute, .lessonWithoutMaterial])
    // Der Zustand zur Renderzeit gilt, nicht der gespeicherte.
    let live: (MaterialRow) -> MaterialAvailability? = { _ in .unavailable(.downloadFailed) }
    #expect(
      row(status: .substitute, materials: [material()]).statements(availability: live)
        == [.substitute, .materialUnavailable])
  }

  @Test("Ohne Aussage und ohne Thema bleibt die zweite Zeile leer")
  func listLineNone() {
    #expect(row(materials: [material()]).listLine(availability: stored) == .none)
  }
}
