import Foundation

/// Einfache, stabile Prüfsumme (FNV-1a, 64 Bit) zum Erkennen geänderter Inhalte; keine Sicherheitsfunktion.
public enum ContentHash {
  /// 16 Hexziffern, klein geschrieben.
  public static func fnv1a64(_ data: Data) -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in data {
      hash ^= UInt64(byte)
      hash = hash &* 0x0000_0100_0000_01b3  // &* = Multiplikation mit Überlauf (sonst bricht Swift ab)
    }
    let hex = String(hash, radix: 16)
    return String(repeating: "0", count: 16 - hex.count) + hex
  }
}
