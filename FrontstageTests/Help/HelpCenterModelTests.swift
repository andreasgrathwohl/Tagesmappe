import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@MainActor @Suite struct HelpCenterModelTests {
  @Test("Ohne Suche alle Gruppen in Reihenfolge, 21 Artikel") func sectionsCoverAllTopics() {
    let model = HelpCenterModel(catalog: HelpLibrary.shared)
    #expect(model.sections.map { $0.group } == HelpGroup.allCases)
    #expect(model.sections.flatMap { $0.articles }.count == 21)
    #expect(!model.isSearching)
  }

  @Test("AK-57: AirPlay → Smartboard verbinden zuerst") func searchRanksRealContent() {
    let model = HelpCenterModel(catalog: HelpLibrary.shared)
    model.query = "AirPlay"
    #expect(model.isSearching)
    #expect(model.results.first?.topic == .secondScreen)
  }

  @Test("Nur Leerraum gilt nicht als Suche") func whitespaceIsNotSearching() {
    let model = HelpCenterModel(catalog: HelpLibrary.shared)
    model.query = "   \n "
    #expect(!model.isSearching)
    #expect(model.results.isEmpty)
  }
}
