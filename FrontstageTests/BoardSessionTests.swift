import Foundation
import FrontstageCore
import PencilKit
import Testing

@testable import Frontstage

@MainActor @Suite struct BoardSessionTests {
  @Test("AK-30: ein Tipp öffnet die Tafel und schaltet den Zweitbildschirm auf Tafel")
  func openShowsBoardOnSecondScreen() throws {
    let (session, screen) = try makeSession()
    try session.open(tue8b)
    #expect(screen.content == .board)
    #expect(session.pages.count == 1)
    #expect(session.pages[0].background == .blank)
    try session.close()
    #expect(screen.content == .classScreen)
    #expect(session.mode == .closed)
  }

  @Test("AK-33: letztes Tafelbild zeigt Di 8b, nur ansehen")
  func previousBoardDrawingIsReadOnly() throws {
    let (session, _) = try makeSession()
    try session.open(tue8b)
    try session.open(tue8a)
    try session.open(wed8b)
    try session.showPreviousBoardDrawing()
    #expect(session.mode == .previous(own: wed8b, shown: tue8b))
    // Nur ansehen: Zeichnen und Löschen sind gesperrt.
    session.drawingChanged(PKDrawing())
    #expect(throws: BoardSessionError.readOnly) { try session.deleteBoardDrawing() }
    try session.returnToOwnBoard()
    #expect(session.mode == .own(wed8b))
  }

  @Test("AK-33: ohne frühere Stunde derselben Klasse und desselben Fachs ein Fehler")
  func noPreviousBoardDrawingThrows() throws {
    let (session, _) = try makeSession()
    try session.open(tue8a)
    try session.open(tue8b)
    #expect(throws: BoardSessionError.noPreviousBoardDrawing) { try session.showPreviousBoardDrawing() }
    #expect(session.mode == .own(tue8b))
  }

  @Test("AK-32: Tafelbild löschen hinterlässt leere Tafel")
  func deleteLeavesEmptyFirstPage() throws {
    let (session, _) = try makeSession()
    try session.open(tue8b)
    try session.addPage(background: .grid)
    #expect(session.pages.count == 2)
    try session.deleteBoardDrawing()
    #expect(session.pages.count == 1)
    #expect(session.pageIndex == 0)
    #expect(session.pages[0].drawingData == nil)
    #expect(session.pages[0].background == .blank)
  }

  @Test("AK-31: neue Seite wird gezeigt, Hintergrund lässt sich ändern")
  func addPageAndChangeBackground() throws {
    let (session, _) = try makeSession()
    try session.open(tue8b)
    try session.addPage(background: .grid)
    #expect(session.pageIndex == 1)
    #expect(session.pages[1].background == .grid)
    try session.setBackground(.lined)
    #expect(session.pages[1].background == .lined)
    #expect(session.pages[0].background == .blank)
  }

  @Test("Seitenwechsel hebt die Abdeckung auf")
  func pageChangeClearsCover() throws {
    let (session, _) = try makeSession()
    try session.open(tue8b)
    session.cover = BoardCover(revealedFraction: 0.3)
    session.goToPage(0)
    #expect(session.cover == nil)
  }

  @Test("Flush speichert die Zeichnung; sie überlebt Schließen und erneutes Öffnen")
  func flushPersistsDrawing() throws {
    let (session, _) = try makeSession()
    try session.open(tue8b)
    session.drawingChanged(PKDrawing())
    #expect(session.liveDrawing == PKDrawing())
    try session.flush()
    #expect(session.pages[0].drawingData != nil)
    try session.close()
    try session.open(tue8b)
    #expect(session.pages[0].drawingData != nil)
    #expect(session.saveFailed == false)
  }

  @Test("Export enthält die noch nicht gespeicherte Zeichnung der gezeigten Seite")
  func exportPagesIncludeUnflushedDrawing() throws {
    let (session, _) = try makeSession()
    try session.open(tue8b)
    #expect(session.exportPages[0].drawingData == nil)
    session.drawingChanged(PKDrawing())
    // Noch nicht gespeichert, im Export aber schon enthalten.
    #expect(session.pages[0].drawingData == nil)
    #expect(session.exportPages[0].drawingData != nil)
  }

  @Test("Seitenwechsel speichert die verlassene Seite")
  func pageChangeSavesLeftPage() throws {
    let (session, _) = try makeSession()
    try session.open(tue8b)
    try session.addPage(background: .blank)
    session.drawingChanged(PKDrawing())
    session.goToPage(0)
    #expect(session.pageIndex == 0)
    #expect(session.pages[1].drawingData != nil)
  }
}
