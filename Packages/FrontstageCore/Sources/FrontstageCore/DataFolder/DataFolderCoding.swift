import Foundation

public enum DataFolderCodingError: Error, Equatable {
  case unsupportedFormatVersion(Int)
  case payloadMissing
  case modelMismatch
}

/// Festes Dateiformat der Datensätze im Datenordner (ADR-0012). Änderungen am Format brechen ältere Stände.
public enum DataFolderCoding {
  /// Nur zum Vorab-Lesen der Formatversion, bevor der Rest interpretiert wird.
  private struct VersionProbe: Decodable { var formatVersion: Int }

  /// Schlüssel sortiert, eingerückt, Datum als ISO 8601 in UTC mit Millisekunden.
  static var encoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    encoder.dateEncodingStrategy = dateEncoding
    return encoder
  }

  static var decoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = dateDecoding
    return decoder
  }

  private static var dateEncoding: JSONEncoder.DateEncodingStrategy {
    .custom { date, encoder in
      var container = encoder.singleValueContainer()
      try container.encode(date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
    }
  }

  private static var dateDecoding: JSONDecoder.DateDecodingStrategy {
    .custom { decoder in
      let text = try decoder.singleValueContainer().decode(String.self)
      do {
        return try Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text)
      } catch {
        throw DecodingError.dataCorrupted(
          .init(codingPath: decoder.codingPath, debugDescription: "Kein ISO-8601-Datum: \(text)"))
      }
    }
  }

  public static func encode(_ envelope: RecordEnvelope) throws -> Data {
    try encoder.encode(envelope)
  }

  public static func decode(_ data: Data) throws -> RecordEnvelope {
    let version = try decoder.decode(VersionProbe.self, from: data).formatVersion
    guard version <= RecordEnvelope.currentFormatVersion else {
      throw DataFolderCodingError.unsupportedFormatVersion(version)
    }
    return try decoder.decode(RecordEnvelope.self, from: data)
  }

  /// Kanonische Form des Inhalts (sortiert, ohne Einrückung) als Grundlage der Prüfsumme.
  public static func encodePayload(_ payload: RecordPayload) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = dateEncoding
    return try encoder.encode(payload)
  }

  public static func payloadHash(_ payload: RecordPayload) throws -> String {
    ContentHash.fnv1a64(try encodePayload(payload))
  }
}
