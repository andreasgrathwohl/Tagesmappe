import Foundation
import Testing

@testable import Frontstage

@Suite struct HelpTipsConfigurationTests {
  private struct Boom: Error {}

  /// Protokolliert die Aufrufe in Reihenfolge; eine Klasse, damit die Closures sie mutieren dürfen.
  private final class CallLog {
    var calls: [String] = []
  }

  private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: UUID().uuidString)!
  }

  private func run(
    defaults: UserDefaults, underTest: Bool, resetFails: Bool = false
  ) -> [String] {
    let log = CallLog()
    HelpTipsConfiguration.configureAtLaunch(
      defaults: defaults, isUnderTest: underTest,
      reset: {
        log.calls.append("reset")
        if resetFails { throw Boom() }
      },
      configure: { log.calls.append("configure") })
    return log.calls
  }

  @Test("Im Testlauf weder reset noch configure")
  func skipsUnderTest() {
    let defaults = makeDefaults()
    HelpTipsConfiguration.requestReset(defaults: defaults)
    #expect(run(defaults: defaults, underTest: true).isEmpty)
    #expect(defaults.bool(forKey: HelpTipsConfiguration.resetKey))
  }

  @Test("Ohne Anforderung nur configure")
  func configuresWithoutReset() {
    #expect(run(defaults: makeDefaults(), underTest: false) == ["configure"])
  }

  @Test("AK-60: Anforderung → reset vor configure, Schlüssel gelöscht")
  func resetsBeforeConfigure() {
    let defaults = makeDefaults()
    HelpTipsConfiguration.requestReset(defaults: defaults)
    #expect(run(defaults: defaults, underTest: false) == ["reset", "configure"])
    #expect(!defaults.bool(forKey: HelpTipsConfiguration.resetKey))
  }

  @Test("Schlägt reset fehl, wird trotzdem konfiguriert")
  func configuresEvenIfResetFails() {
    let defaults = makeDefaults()
    HelpTipsConfiguration.requestReset(defaults: defaults)
    #expect(run(defaults: defaults, underTest: false, resetFails: true) == ["reset", "configure"])
  }
}
