import Foundation

/// Beitreten: Wechsel auf einen (OneDrive-)Datenordner mit vorhandenem lokalem Bestand.
public enum DataFolderJoin {
  /// Frisches Buch beim Wechsel auf OneDrive: jeder lokale Datensatz ausstehend seit `.distantPast` →
  /// im nächsten Durchgang gewinnt jeder Stand, der schon im Datenordner liegt (Entscheidung 4).
  /// Nur lokal Vorhandenes bleibt ausstehend und wird geschrieben.
  public static func ledger(local: [LocalRecordState], deviceID: String, appFolderID: String) -> SyncLedger {
    var result = SyncLedger(deviceID: deviceID, appFolderID: appFolderID)
    for state in local {
      result.entries[state.id] = LedgerEntry(
        model: state.model, payloadHash: nil, updatedAt: .distantPast, deviceID: deviceID,
        deleted: false, dirtySince: .distantPast)
    }
    return result
  }
}
