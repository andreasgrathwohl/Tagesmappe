import Foundation
import Testing

@testable import FrontstageCore

@Suite("TimetableSource")
struct TimetableSourceTests {
  @Test("Quelle „von Hand“ liefert nichts (Area stundenplan-quellen)")
  func manualSourceReturnsNil() async throws {
    let source = ManualTimetableSource()
    #expect(source.kind == .manual)
    let result = try await source.fetch(
      range: d(2026, 11, 16)...d(2026, 12, 13), existing: nil, now: Date(timeIntervalSince1970: 0))
    #expect(result == nil)
  }

  @Test("Stand übersteht Speichern und Laden")
  func snapshotRoundTripsThroughJSON() throws {
    let derived = DerivedTimetable(
      entries: [entry(.monday, 1, "8b", "Mathe", variant: .a)], weekVariantCount: 2,
      referenceWeekA: d(2026, 11, 16))
    let snapshot = SourceSnapshot(
      kind: .schulmanager, fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
      range: d(2026, 11, 16)...d(2026, 12, 13), timetable: .derived(derived),
      bellSchedule: BellSchedule(periods: [1: t(7, 45)...t(8, 30)]),
      changes: [
        .substitute(
          date: d(2026, 11, 17), period: 2, schoolClass: SchoolClass("9c"), subject: Subject("Deutsch"))
      ])
    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(SourceSnapshot.self, from: data)
    #expect(decoded == snapshot)
  }

  @Test("Fehler und Ergebnisarten übersteht Speichern und Laden")
  func errorsAndOutcomesRoundTrip() throws {
    for error in [
      TimetableSourceError.notConfigured, .server(status: 503), .unexpectedResponse("x"),
    ] {
      let decoded = try JSONDecoder().decode(
        TimetableSourceError.self, from: JSONEncoder().encode(error))
      #expect(decoded == error)
    }
    for outcome in [
      TimetableDerivationOutcome.noLessonsInRange, .weekVariantsUndetermined,
    ] {
      let decoded = try JSONDecoder().decode(
        TimetableDerivationOutcome.self, from: JSONEncoder().encode(outcome))
      #expect(decoded == outcome)
    }
  }

  @Test("Pfadzugriff auf JSON-Werte")
  func jsonValuePathLookup() throws {
    let json = #"{"user":{"associatedTeacher":{"id":"T-100"}},"n":1.5,"ok":true,"l":[null,"a"]}"#
    let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    #expect(value[["user", "associatedTeacher", "id"]] == .string("T-100"))
    #expect(value[["user", "missing"]] == nil)
    #expect(value[["user", "associatedTeacher", "id", "deeper"]] == nil)
    #expect(value[["n"]] == .number(1.5))
    #expect(value[["ok"]] == .bool(true))
    #expect(value[["l"]] == .array([.null, .string("a")]))
    #expect(value[[]] == value)
  }

  @Test("Gespeicherte Rohwerte der Quellenart")
  func sourceKindRawValues() {
    #expect(TimetableSourceKind.allCases.map(\.rawValue) == ["manual", "schulmanager"])
  }
}
