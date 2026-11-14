import Foundation

/// Regeln für das „letzte Tafelbild“ (FR-12.3).
public enum BoardHistory {
  /// Schlüssel der letzten früheren Stunde derselben Klasse und desselben Fachs, von der es
  /// Tafelseiten gibt. „Früher“ ist streng früher nach (Tag, laufende Nummer): In einer
  /// Doppelstunde findet die zweite Stunde die erste desselben Tages. `nil`, wenn es keine gibt.
  public static func previousLessonKey(before key: LessonKey, among keysWithPages: [LessonKey])
    -> LessonKey?
  {
    keysWithPages
      .filter {
        $0.schoolClass == key.schoolClass && $0.subject == key.subject
          && ($0.date, $0.ordinal) < (key.date, key.ordinal)
      }
      .max { ($0.date, $0.ordinal) < ($1.date, $1.ordinal) }
  }
}
