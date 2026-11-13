import Testing
@testable import FrontstageCore

@Suite("LessonKey")
struct LessonKeyTests {
  @Test("Speichertext hat das feste Format (ADR-0005, AK-1)")
  func storageTextFormat() {
    let key = LessonKey(
      date: d(2026, 11, 17), schoolClass: SchoolClass("8 b"), subject: Subject("Englisch"), ordinal: 1)
    #expect(key.storageText == "2026-11-17|8b|englisch|1")
  }

  @Test("Fach mit Leerzeichen wird prozentkodiert (ADR-0005, AK-1)")
  func storageTextEncodesSpaces() {
    let key = LessonKey(
      date: d(2026, 11, 17), schoolClass: SchoolClass("8b"), subject: Subject("Bildende Kunst"),
      ordinal: 1)
    #expect(key.storageText == "2026-11-17|8b|bildende%20kunst|1")
  }

  @Test("Speichertext ergibt dieselbe Schlüssel-Rundreise (ADR-0005, AK-1)")
  func storageTextRoundTrip() {
    let keys = [
      LessonKey(
        date: d(2026, 11, 17), schoolClass: SchoolClass("8b"), subject: Subject("Bildende Kunst"),
        ordinal: 2),
      LessonKey(
        date: d(2026, 11, 3), schoolClass: SchoolClass("10a"), subject: Subject("Mathe|Info"),
        ordinal: 1),
    ]
    for k in keys {
      #expect(LessonKey(storageText: k.storageText) == k)
    }
  }

  @Test(
    "Ungültiger Speichertext ergibt nil (ADR-0005, AK-1)",
    arguments: [
      "", "2026-11-17|8b|englisch", "2026-13-01|8b|englisch|1", "2026-11-17|8b|englisch|0",
      "2026-11-17|8b|englisch|x", "2026-11-17|8b|englisch|1|extra",
      "2026-11-17||englisch|1", "2026-11-17|8b||1", "2026-11-17|%20|englisch|1",
    ])
  func storageTextRejectsGarbage(text: String) {
    #expect(LessonKey(storageText: text) == nil)
  }

  @Test("NFC und NFD ergeben denselben Speichertext, nur ASCII (ADR-0005, AK-1)")
  func storageTextIsCanonicalAcrossUnicodeForms() {
    let nfc = "Franz\u{00F6}sisch"
    let nfd = "Franzo\u{0308}sisch"
    for raw in [nfc, nfd] {
      let key = LessonKey(
        date: d(2026, 11, 17), schoolClass: SchoolClass("9c"), subject: Subject(raw), ordinal: 1)
      #expect(key.storageText == "2026-11-17|9c|franz%C3%B6sisch|1")
      #expect(LessonKey(storageText: key.storageText) == key)
    }
    #expect(Array(Subject(nfd).normalized.unicodeScalars) == Array("franz\u{00F6}sisch".unicodeScalars))
    #expect(
      Array(SchoolClass("A\u{0308}g").normalized.unicodeScalars)
        == Array("\u{00E4}g".unicodeScalars))
  }

  @Test("Schlüsselvergleich nutzt normalisierte Namen (ADR-0005, AK-1)")
  func keyEqualityUsesNormalizedNames() {
    let a = LessonKey(
      date: d(2026, 11, 17), schoolClass: SchoolClass("08B"), subject: Subject("ENGLISCH"), ordinal: 1)
    let b = LessonKey(
      date: d(2026, 11, 17), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
    #expect(a == b)
    #expect(a.hashValue == b.hashValue)
  }
}
