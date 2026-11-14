import Foundation

/// Abgleich der Ersatz-Notizen im Datenort (`PenNoteRecord`) mit der Notiz-Datei beim Öffnen einer Anzeige
/// (ADR-0011, Nachtrag zu Teilplan 06). Ersatz-Seiten entstehen, wenn der Ordner nicht beschreibbar ist oder
/// das Schreiben der Notiz-Datei beim Schließen scheitert; sie sollen so bald wie möglich in die Datei.
///
/// Reine Entscheidung über Zeitstempel je Seite – Lesen, Schreiben und Löschen macht die App.
public enum PenNoteFallbackReconciliation {
  public struct Plan: Equatable, Sendable {
    /// Ersatz-Seiten, die in der Datei fehlen oder dort älter sind: sie gewinnen und werden in die Datei geschrieben.
    public var pagesToWrite: Set<Int>
    /// Ersatz-Seiten, die die Datei gleich alt oder neuer hat: überholt, ihre Datensätze werden gelöscht.
    public var obsoleteFallbackPages: Set<Int>

    public init(pagesToWrite: Set<Int>, obsoleteFallbackPages: Set<Int>) {
      self.pagesToWrite = pagesToWrite
      self.obsoleteFallbackPages = obsoleteFallbackPages
    }

    /// Nach erfolgreichem Schreiben steht jede Ersatz-Seite gleich alt oder neuer in der Datei: alle löschbar.
    public var removableAfterSuccessfulWrite: Set<Int> { pagesToWrite.union(obsoleteFallbackPages) }
  }

  /// - Parameters:
  ///   - fileUpdatedAt: `updatedAt` je Seite der Notiz-Datei.
  ///   - fallbackUpdatedAt: `updatedAt` des jüngsten Ersatz-Datensatzes je Seite.
  /// - Returns: Je Seite gewinnt der neuere Stand; bei Gleichstand die Datei (sie ist maßgeblich).
  public static func plan(fileUpdatedAt: [Int: Date], fallbackUpdatedAt: [Int: Date]) -> Plan {
    var write: Set<Int> = []
    var obsolete: Set<Int> = []
    for (index, fallbackStamp) in fallbackUpdatedAt {
      if let fileStamp = fileUpdatedAt[index], fileStamp >= fallbackStamp {
        obsolete.insert(index)
      } else {
        write.insert(index)
      }
    }
    return Plan(pagesToWrite: write, obsoleteFallbackPages: obsolete)
  }
}
