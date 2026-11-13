import Foundation
import Testing
@testable import Frontstage

// Im gehosteten Test läuft der Test im Prozess der App, daher ist Bundle.main das App-Bündel.
@Test("App-Ziel baut und findet die deutsche Übersetzungstabelle")
func placeholderStringIsLocalized() {
  #expect(String(localized: "app.placeholder.title", bundle: .main) == "Frontstage")
}
