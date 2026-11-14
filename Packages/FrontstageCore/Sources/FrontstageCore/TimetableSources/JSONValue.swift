import Foundation

/// Roher JSON-Wert, damit etwa das Kontoobjekt der Quelle unverändert weitergereicht werden kann.
public enum JSONValue: Hashable, Codable, Sendable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case object([String: JSONValue])
  case array([JSONValue])
  case null

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    // Reihenfolge wichtig: Bool vor Zahl, damit `true` nicht als Zahl gelesen wird.
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else if let value = try? container.decode([String: JSONValue].self) {
      self = .object(value)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Kein gültiger JSON-Wert")
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let value): try container.encode(value)
    case .number(let value): try container.encode(value)
    case .bool(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    case .array(let value): try container.encode(value)
    case .null: try container.encodeNil()
    }
  }

  /// Objektpfad; `nil`, sobald ein Schlüssel fehlt oder ein Zwischenwert kein Objekt ist.
  /// Der leere Pfad liefert den Wert selbst.
  public subscript(path: [String]) -> JSONValue? {
    var current = self
    for key in path {
      guard case .object(let object) = current, let next = object[key] else { return nil }
      current = next
    }
    return current
  }
}
