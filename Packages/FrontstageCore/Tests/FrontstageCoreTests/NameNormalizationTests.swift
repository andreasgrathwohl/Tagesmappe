import Foundation
import Testing
@testable import FrontstageCore

@Suite("NameNormalization")
struct NameNormalizationTests {
  @Test(
    "Klassennamen werden normalisiert (ADR-0005, AK-1)",
    arguments: ["8 b", "08B", "8b", " 8b ", "8\u{00A0}b", "008b"])
  func schoolClassNormalizesSpellings(raw: String) {
    #expect(SchoolClass(raw).normalized == "8b")
  }

  @Test("Sinnvolle Nullen und Leerraum bleiben korrekt (ADR-0005, AK-1)")
  func schoolClassKeepsMeaningfulZeros() {
    #expect(SchoolClass("10a").normalized == "10a")
    #expect(SchoolClass("Q 11").normalized == "q11")
    #expect(SchoolClass("0").normalized == "0")
  }

  @Test("Klassen sind nach Normalisierung gleich (ADR-0005, AK-1)")
  func schoolClassEqualityAfterNormalization() {
    #expect(SchoolClass("8 b") == SchoolClass("08B"))
    #expect(SchoolClass("8b") != SchoolClass("8a"))
  }

  @Test("Fächer vergleichen normalisiert und behalten die Anzeige (ADR-0005, AK-1)")
  func subjectComparesNormalizedKeepsDisplay() {
    #expect(Subject("Englisch") == Subject(" englisch "))
    #expect(Subject(" Englisch ").display == "Englisch")
    #expect(Subject("Bildende  Kunst").normalized == "bildende kunst")
    #expect(Set([Subject("Englisch"), Subject("ENGLISCH")]).count == 1)
  }
}
