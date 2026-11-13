/// Fassung des Klassenbildschirms: welche Unterrichtsstunde in welcher Form gezeigt wird.
/// Thema, Bereitlegen und Hausaufgabe gehören nicht hierher, sie kommen aus der Stundeninfo.
public enum ClassScreenPhase: Hashable, Sendable {
  /// Die nächste Stunde hat noch nicht begonnen.
  case upcoming(Lesson)
  /// Die Stunde läuft.
  case inLesson(Lesson)
  /// Die Stunde läuft und endet in wenigen Minuten.
  case finalMinutes(Lesson)
  /// Heute findet keine weitere Stunde statt.
  case noMoreLessons
}
