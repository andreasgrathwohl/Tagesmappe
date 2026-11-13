import Foundation

/// Schlüssel einer Unterrichtsstunde (ADR-0005): Tag, Klasse, Fach und laufende Nummer der Stunde
/// dieses Fachs an diesem Tag. Gleichheit läuft über die normalisierten Namen.
public struct LessonKey: Hashable, Codable, Sendable {
  public let date: CalendarDay
  public let schoolClass: SchoolClass
  public let subject: Subject
  /// Laufende Nummer ab 1, wenn dasselbe Fach am Tag mehrfach stattfindet.
  public let ordinal: Int

  public init(date: CalendarDay, schoolClass: SchoolClass, subject: Subject, ordinal: Int) {
    self.date = date
    self.schoolClass = schoolClass
    self.subject = subject
    self.ordinal = ordinal
  }

  /// Dauerhaftes Textformat (steht in jeder gespeicherten Zuordnung, nie ändern):
  /// `<yyyy-MM-dd>|<Klasse>|<Fach>|<Nummer>`; Klasse und Fach normalisiert und prozentkodiert,
  /// damit ein `|` im Namen das Format nicht bricht.
  public var storageText: String {
    [
      date.storageText,
      Self.encode(schoolClass.normalized),
      Self.encode(subject.normalized),
      String(ordinal),
    ].joined(separator: "|")
  }

  /// Liest den Speichertext; `nil` bei falschem Aufbau, ungültigem Datum oder Nummer unter 1.
  /// Das Fach entsteht aus dem normalisierten Text, `display` ist danach klein geschrieben:
  /// Die Anzeige des Fachs kommt aus der berechneten `Lesson`, nicht aus dem Schlüssel.
  public init?(storageText: String) {
    let parts = storageText.split(separator: "|", omittingEmptySubsequences: false)
    guard parts.count == 4,
      let date = CalendarDay(storageText: String(parts[0])),
      let className = String(parts[1]).removingPercentEncoding,
      let subjectName = String(parts[2]).removingPercentEncoding,
      parts[3].allSatisfy({ $0.isASCII && $0.isNumber }),
      let ordinal = Int(parts[3]), ordinal >= 1
    else { return nil }
    self.init(
      date: date, schoolClass: SchoolClass(className), subject: Subject(subjectName),
      ordinal: ordinal)
  }

  private static func encode(_ text: String) -> String {
    // Mit `.alphanumerics` ist die Kodierung nie `nil`; der Rückfall bleibt nur für den Compiler.
    text.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? text
  }
}
