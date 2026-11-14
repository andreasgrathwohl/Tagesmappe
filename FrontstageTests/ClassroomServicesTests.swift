import FrontstageCore
import PencilKit
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

  @Test("Wechsel des Datenorts speichert ungesicherte Striche der offenen Tafel in den alten Datenort")
  func bindFlushesOpenBoard() throws {
    let services = ClassroomServices(unlock: Unlock(listenForUpdates: false))
    let a = try makeStore()
    let b = try makeStore()
    services.bind(store: a)
    let boardA = try #require(services.board)
    try boardA.open(tue8b)
    // Innerhalb der Speicherverzögerung (1 s): noch nicht gespeichert.
    boardA.drawingChanged(PKDrawing())
    services.bind(store: b)
    #expect(try a.boardPages(for: tue8b).first?.drawingData != nil)
    #expect(boardA.mode == .closed)
  }
}
