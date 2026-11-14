import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@Suite("Texte der Stundenplan-Quelle")
struct SourceStringsTests {
  private func text(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: nil, table: nil)
  }

  @Test("Anbindung als inoffiziell und ohne Gewähr bezeichnet (FR-13.1, AK-41)")
  func unofficialNoticeNamesBoth() {
    let notice = text("timetableSource.unofficialNotice")
    #expect(notice.contains("inoffiziell") || notice.contains("Inoffiziell"))
    #expect(notice.contains("ohne Gewähr"))
  }

  @Test("Jeder Fehler der Quelle hat einen übersetzten Text")
  func everyErrorHasAText() {
    let errors: [TimetableSourceError] = [
      .notConfigured, .invalidCredentials, .multipleSchoolsUnsupported, .offline,
      .unexpectedResponse("x"),
    ]
    for error in errors {
      let key = error.settingsMessageKey
      #expect(text(key) != key, "Schlüssel \(key) fehlt im Katalog")
    }
    // Mit Zahl im Schlüssel, deshalb getrennt.
    #expect(TimetableSourceError.server(status: 500).settingsMessageKey == "timetableSource.error.server")
    #expect(text("timetableSource.error.server %lld") != "timetableSource.error.server %lld")
  }
}
