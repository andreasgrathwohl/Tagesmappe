/// Tafelseiten speichern, dünne Hülle über dem `DataStore` (FR-12.1).
///
/// PLATZHALTER aus Aufgabe 4, damit `ClassroomServices` übersetzt; Aufgabe 8 ersetzt die Datei.
@MainActor struct BoardStore {
  let store: DataStore

  init(store: DataStore) {
    self.store = store
  }
}
