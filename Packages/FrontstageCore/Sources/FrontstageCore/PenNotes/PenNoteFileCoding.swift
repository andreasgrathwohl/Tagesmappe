import Foundation

/// Fehler beim Lesen einer Notiz-Datei.
public enum PenNoteFileDecodeError: Error, Equatable {
  /// Kein gültiges JSON oder Aufbau nicht erkennbar.
  case unreadable
  /// Format neuer als dieses Programm kennt (Review Focus 4) – nie als leer lesen, nie überschreiben.
  case newerFormat(Int)
}

/// JSON-Format der Notiz-Datei (ADR-0011): Schlüssel sortiert, eingerückt, Datum als ISO 8601 in UTC
/// mit Millisekunden, Zeichnung als Base64 (Standard des Encoders).
public enum PenNoteFileCoding {
  /// Nur zum Vorab-Lesen des Formats, bevor der Rest gedeutet wird.
  private struct FormatProbe: Decodable { var format: Int }

  public static func encode(_ file: PenNoteFile) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    // Formatstil statt geteiltem ISO8601DateFormatter: Sendable unter Swift 6 (Vorbild `DataFolderCoding`).
    encoder.dateEncodingStrategy = .custom { date, encoder in
      var container = encoder.singleValueContainer()
      try container.encode(date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
    }
    return try encoder.encode(file)
  }

  public static func decode(_ data: Data) throws(PenNoteFileDecodeError) -> PenNoteFile {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let text = try decoder.singleValueContainer().decode(String.self)
      do {
        return try Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text)
      } catch {
        throw DecodingError.dataCorrupted(
          .init(codingPath: decoder.codingPath, debugDescription: "Kein ISO-8601-Datum: \(text)"))
      }
    }
    let format: Int
    do {
      format = try decoder.decode(FormatProbe.self, from: data).format
    } catch {
      throw .unreadable
    }
    if format > PenNoteFile.currentFormat { throw .newerFormat(format) }
    do {
      return try decoder.decode(PenNoteFile.self, from: data)
    } catch {
      throw .unreadable
    }
  }
}
