import Testing

@testable import Frontstage

@Test("Startbereich: ohne Stundenplan Einrichten, sonst iPad Tagesansicht, Mac Vorbereiten")
func initialSection() {
  #expect(AppSection.initial(isMac: false, hasTimetable: false) == .setup)
  #expect(AppSection.initial(isMac: true, hasTimetable: false) == .setup)
  #expect(AppSection.initial(isMac: false, hasTimetable: true) == .dayView)
  #expect(AppSection.initial(isMac: true, hasTimetable: true) == .preparation)
}
