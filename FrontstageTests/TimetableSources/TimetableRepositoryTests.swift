import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@MainActor @Suite("TimetableRepository")
struct TimetableRepositoryTests {
  @Test("Quelle wird als Rohwert gespeichert und als TimetableSourceKind gelesen")
  func repositoryMapsSourceKind() throws {
    let store = try makeStore()
    let repository: any TimetableRepository = store
    #expect(try repository.timetableSourceKind() == .manual)
    try repository.setTimetableSourceKind(.schulmanager)
    #expect(try repository.timetableSourceRaw() == "schulmanager")
    #expect(try repository.timetableSourceKind() == .schulmanager)
  }

  @Test("Unbekannter Rohwert wird zu „von Hand“")
  func unknownRawValueMapsToManual() throws {
    let store = try makeStore()
    try store.setTimetableSourceRaw("webuntis-zukunft")
    #expect(try store.timetableSourceKind() == .manual)
  }
}
