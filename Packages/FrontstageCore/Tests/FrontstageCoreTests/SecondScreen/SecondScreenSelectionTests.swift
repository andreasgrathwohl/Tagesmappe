import Testing
@testable import FrontstageCore

struct SecondScreenSelectionTests {
  @Test("Startzustand ist Klassenbildschirm (FR-11)")
  func startsWithClassScreen() {
    let s = SecondScreenSelection()
    #expect(s.mode == .classScreen)
    #expect(s.availableModes == [.classScreen, .dark])
  }

  @Test("Öffnen zeigt Material, Schließen den Klassenbildschirm – nie die Tagesansicht (AK-23)")
  func openAndCloseMaterial() {
    var s = SecondScreenSelection()
    s.materialOpened();  #expect(s.mode == .material)
    s.materialClosed();  #expect(s.mode == .classScreen)
    #expect(!s.availableModes.contains(.material))
  }

  @Test("Dunkel und zurück zeigt wieder dasselbe Material (AK-28)")
  func darkRestoresPreviousMode() {
    var s = SecondScreenSelection()
    s.materialOpened()
    s.toggleDark();  #expect(s.mode == .dark)
    s.toggleDark();  #expect(s.mode == .material)
  }

  @Test("Umschalten Klassenbildschirm, Material, Tafel, Dunkel (AK-29)")
  func switchesThroughAllFourModes() {
    var s = SecondScreenSelection()
    s.materialOpened(); s.setBoardAvailable(true)
    for m in [SecondScreenContent.classScreen, .material, .board, .dark] {
      let accepted = s.select(m)
      #expect(accepted); #expect(s.mode == m)
    }
  }

  @Test("Nicht verfügbare Modi lassen den Zustand unverändert")
  func unavailableSelectionIsRejected() {
    var s = SecondScreenSelection()
    let material = s.select(.material)
    #expect(material == false); #expect(s.mode == .classScreen)
    let board = s.select(.board)
    #expect(board == false);    #expect(s.mode == .classScreen)
  }

  @Test("Material schließen während Dunkel: Dunkel bleibt, Rückweg führt zum Klassenbildschirm")
  func closeMaterialWhileDark() {
    var s = SecondScreenSelection()
    s.materialOpened(); s.toggleDark(); s.materialClosed()
    #expect(s.mode == .dark)
    s.toggleDark(); #expect(s.mode == .classScreen)
  }

  @Test("Material öffnen während Dunkel: bleibt dunkel, Rückweg zeigt das Material")
  func openMaterialWhileDark() {
    var s = SecondScreenSelection()
    s.toggleDark(); s.materialOpened()
    #expect(s.mode == .dark)
    s.toggleDark(); #expect(s.mode == .material)
  }

  @Test("Tafel nicht mehr verfügbar → Klassenbildschirm")
  func boardUnavailableFallsBack() {
    var s = SecondScreenSelection()
    s.setBoardAvailable(true); s.select(.board); s.setBoardAvailable(false)
    #expect(s.mode == .classScreen)
  }

  @Test("Verbinden hebt Dunkel auf, damit der Inhalt ohne Handgriff erscheint (AK-35)")
  func connectingClearsDark() {
    var s = SecondScreenSelection()
    s.toggleDark(); s.displayConnected()
    #expect(s.mode == .classScreen)
  }

  @Test("Verbinden lässt einen sichtbaren Modus unverändert (Review Focus 1)")
  func connectingKeepsVisibleMode() {
    var s = SecondScreenSelection()
    s.materialOpened(); s.displayConnected()
    #expect(s.mode == .material)
  }
}
