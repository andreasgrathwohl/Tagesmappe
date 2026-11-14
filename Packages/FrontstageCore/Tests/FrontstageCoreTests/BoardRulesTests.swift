import Testing

@testable import FrontstageCore

private func key(_ day: Int, _ schoolClass: String, _ subject: String = "Englisch", ordinal: Int = 1)
  -> LessonKey
{
  LessonKey(
    date: CalendarDay(year: 2026, month: 11, day: day), schoolClass: SchoolClass(schoolClass),
    subject: Subject(subject), ordinal: ordinal)
}

@Suite("BoardRules")
struct BoardRulesTests {
  @Test("AK-33: letztes Tafelbild der 8b, nicht das der 8a dazwischen")
  func previousBoardDrawingSameClassAndSubject() {
    let keys = [key(17, "8b"), key(17, "8a"), key(10, "8b")]
    #expect(BoardHistory.previousLessonKey(before: key(18, "8b"), among: keys) == key(17, "8b"))
  }

  @Test("Review Focus 3: Doppelstunde – zweite Stunde findet die erste desselben Tages")
  func previousBoardDrawingWithinSameDayUsesLowerOrdinal() {
    let keys = [key(17, "8b", ordinal: 1), key(17, "8b", ordinal: 2)]
    #expect(
      BoardHistory.previousLessonKey(before: key(17, "8b", ordinal: 2), among: keys)
        == key(17, "8b", ordinal: 1))
  }

  @Test("Anderes Fach derselben Klasse zählt nicht; ohne frühere Stunde nil")
  func previousBoardDrawingIgnoresOtherSubject() {
    let keys = [key(17, "8b", "Mathe"), key(19, "8b")]
    #expect(BoardHistory.previousLessonKey(before: key(18, "8b"), among: keys) == nil)
  }

  @Test("AK-39: Abdeckung von oben aufziehen, auf 0…1 begrenzt")
  func coverRevealsFromTop() {
    var cover = BoardCover()
    #expect(cover.revealedFraction == 0)
    cover.reveal(to: 0.34)
    #expect(cover.revealedFraction == 0.34)
    cover.reveal(to: 1.7)
    #expect(cover.revealedFraction == 1)
    cover.reveal(to: -0.2)
    #expect(cover.revealedFraction == 0)
  }

  @Test("AK-39: deckend am Zweitbildschirm, durchscheinend am Tablet")
  func coverOpacityPerAudience() {
    #expect(BoardCover.opacity(for: .secondScreen) == 1.0)
    #expect(BoardCover.opacity(for: .tablet) == 0.4)
  }
}
