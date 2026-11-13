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
  /// `<yyyy-MM-dd>|<Klasse>|<Fach>|<Nummer>`; Klasse und Fach normalisiert (NFC) und prozentkodiert,
  /// damit ein `|` im Namen das Format nicht bricht. Unkodiert bleiben nur `a`–`z` und `0`–`9`,
  /// alles andere wird als UTF-8-Bytes `%XX` (Großbuchstaben-Hex) geschrieben – unabhängig von
  /// Betriebssystem-Version und Unicode-Tabellen.
  public var storageText: String {
    [
      date.storageText,
      Self.encode(schoolClass.normalized),
      Self.encode(subject.normalized),
      String(ordinal),
    ].joined(separator: "|")
  }

  /// Liest den Speichertext; `nil` bei falschem Aufbau, ungültigem Datum, leerer Klasse oder
  /// leerem Fach (auch nach Normalisierung) oder Nummer unter 1.
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
    let schoolClass = SchoolClass(className)
    let subject = Subject(subjectName)
    guard !schoolClass.normalized.isEmpty, !subject.normalized.isEmpty else { return nil }
    self.init(date: date, schoolClass: schoolClass, subject: subject, ordinal: ordinal)
  }

  /// Prozentkodierung von Hand statt `addingPercentEncoding`: Die erlaubte Menge ist fest
  /// `a`–`z`, `0`–`9`; jedes andere UTF-8-Byte wird `%XX`.
  private static func encode(_ text: String) -> String {
    let hexDigits = Array("0123456789ABCDEF")
    var result = ""
    for byte in text.utf8 {
      switch byte {
      case UInt8(ascii: "a")...UInt8(ascii: "z"), UInt8(ascii: "0")...UInt8(ascii: "9"):
        result.append(Character(Unicode.Scalar(byte)))
      default:
        result.append("%")
        result.append(hexDigits[Int(byte >> 4)])
        result.append(hexDigits[Int(byte & 0x0F)])
      }
    }
    return result
  }
}
