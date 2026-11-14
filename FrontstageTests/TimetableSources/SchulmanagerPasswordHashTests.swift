import Testing

@testable import Frontstage

@Suite struct SchulmanagerPasswordHashTests {
  @Test("Referenzwert, mit .NET und Node unabhängig gerechnet")
  func passwordHashMatchesReferenceVector() {
    let hash = SchulmanagerPasswordHash.make(password: "Beispiel-Passwort-1", salt: "beispielsalz")
    #expect(hash.count == 1024)
    #expect(hash.hasPrefix("f82673fd3caf5e8cb13026c51bd8746d"))
    #expect(hash.hasSuffix("ae384c7d9538d1bf999d4da7acd0ff1d"))
  }

  @Test("Gleiche Eingabe ergibt denselben Hash, anderes Salz einen anderen")
  func hashIsDeterministicAndSaltDependent() {
    let a = SchulmanagerPasswordHash.make(password: "x", salt: "s1")
    #expect(a == SchulmanagerPasswordHash.make(password: "x", salt: "s1"))
    #expect(a != SchulmanagerPasswordHash.make(password: "x", salt: "s2"))
  }
}
