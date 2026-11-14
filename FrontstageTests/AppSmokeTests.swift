import Foundation
import Testing

@testable import Frontstage

// Im gehosteten Test läuft der Test im Prozess der App, daher ist Bundle.main das App-Bündel.
@Test("App-Ziel baut und findet die deutsche Übersetzungstabelle")
func sectionTitleIsLocalized() {
  #expect(String(localized: "app.section.dayView", bundle: .main) == "Heute")
}
