import Testing

@testable import Frontstage

@MainActor @Suite struct ClassroomServicesTests {
  @Test("Übersicht Abstimmung 15: Wechsel des Datenorts bindet die Tafel an den neuen DataStore")
  func bindReplacesBoardOnNewStore() throws {
    let services = ClassroomServices(unlock: Unlock(listenForUpdates: false))
    let a = try makeStore()
    let b = try makeStore()
    #expect(services.board == nil)
    services.bind(store: a)
    let boardA = services.board
    #expect(boardA != nil)
    services.bind(store: a)
    #expect(services.board === boardA)
    services.bind(store: b)
    #expect(services.board !== boardA)
    #expect(services.store === b)
  }
}
