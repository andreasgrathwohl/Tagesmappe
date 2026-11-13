import Foundation

/// Eines der drei Felder der Stundenangaben.
public enum LessonInfoField: String, CaseIterable, Codable, Sendable {
  case topic, toPrepare, homework
}

/// Stundenangaben: leere oder nur aus Leerraum bestehende Felder sind `nil`.
public struct LessonInfo: Hashable, Codable, Sendable {
  public var topic: String?
  public var toPrepare: String?
  public var homework: String?

  /// Normalisiert die Eingaben (Leerraum an den Rändern entfernt, leer wird `nil`).
  public init(topic: String? = nil, toPrepare: String? = nil, homework: String? = nil) {
    self.topic = Self.normalize(topic)
    self.toPrepare = Self.normalize(toPrepare)
    self.homework = Self.normalize(homework)
  }

  /// Kopie mit normalisierten Feldern.
  public func normalized() -> LessonInfo {
    LessonInfo(topic: topic, toPrepare: toPrepare, homework: homework)
  }

  /// Alle Felder fehlen (nach Normalisierung).
  public var isEmpty: Bool {
    let n = normalized()
    return n.topic == nil && n.toPrepare == nil && n.homework == nil
  }

  /// Zugriff auf ein Feld; Schreiben setzt den Wert unverändert, `normalized()` bereinigt später.
  public subscript(field: LessonInfoField) -> String? {
    get {
      switch field {
      case .topic: topic
      case .toPrepare: toPrepare
      case .homework: homework
      }
    }
    set {
      switch field {
      case .topic: topic = newValue
      case .toPrepare: toPrepare = newValue
      case .homework: homework = newValue
      }
    }
  }

  private static func normalize(_ text: String?) -> String? {
    guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
    return trimmed
  }
}
