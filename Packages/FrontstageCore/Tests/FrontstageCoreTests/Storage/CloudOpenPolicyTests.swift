import Testing
@testable import FrontstageCore

@Suite("CloudOpenPolicy")
struct CloudOpenPolicyTests {
  @Test("Vorbereitung: 4,9 s weiter warten, 5 s Rückfall")
  func preparationLimit() {
    #expect(CloudOpenPolicy.afterPreparation(addressReady: false, elapsed: .milliseconds(4900)) == .keepWaiting)
    #expect(CloudOpenPolicy.afterPreparation(addressReady: false, elapsed: .seconds(5)) == .fallBackToHandOff)
    #expect(CloudOpenPolicy.afterPreparation(addressReady: true, elapsed: .seconds(6)) == .done)
  }

  @Test("Übergabe: abgelehnt sofort Rückfall, keine Antwort nach 10 s Rückfall")
  func handOverLimit() {
    #expect(CloudOpenPolicy.afterHandOver(accepted: false, elapsed: .seconds(1)) == .fallBackToHandOff)
    #expect(CloudOpenPolicy.afterHandOver(accepted: nil, elapsed: .seconds(9)) == .keepWaiting)
    #expect(CloudOpenPolicy.afterHandOver(accepted: nil, elapsed: .seconds(10)) == .fallBackToHandOff)
    #expect(CloudOpenPolicy.afterHandOver(accepted: true, elapsed: .seconds(3)) == .done)
  }

  @Test("Rückkehr binnen 60 s bietet Öffnen ohne AutoSpeichern an")
  func returnWindow() {
    #expect(CloudOpenPolicy.offersOpenWithoutAutoSave(returnedAfter: .seconds(60)))
    #expect(!CloudOpenPolicy.offersOpenWithoutAutoSave(returnedAfter: .seconds(61)))
  }
}
