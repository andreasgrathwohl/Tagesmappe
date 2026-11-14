import FrontstageCore

/// Schmale Sicht auf die App-Daten (Übersicht, Abstimmung Punkt 4); Tests nutzen eine Attrappe.
@MainActor protocol MaterialReferenceStore: AnyObject {
  /// Schlüssel und Verweis aller Zuordnungen dieser Stunden.
  func linkedReferences(for keys: [LessonKey]) throws -> [(key: LessonKey, reference: MaterialReference)]
  /// Gespiegelte Freigabe-Namen aus allen Zuordnungen.
  func folderGrantNames() throws -> Set<String>
  /// Ersetzt an allen Zuordnungen mit diesem alten Ort den Verweis; Zuordnungen und Stiftnotizen bleiben.
  @discardableResult
  func replaceReferences(atLocation locationKey: String, with reference: MaterialReference) throws -> Int
}

/// Gleiche Signaturen wie `DataStore` (DataStore+MaterialLinks) – die Erweiterung braucht keinen eigenen Code.
extension DataStore: MaterialReferenceStore {}
