import Foundation
import FrontstageCore
import OSLog

/// Fehler beim Zuordnen aus der Ablage; Datenfehler werden protokolliert und als `.saveFailed` gemeldet.
enum AssignError: Error, Equatable {
  /// Die Datei liegt in keinem freigegebenen Ordner dieses Geräts.
  case outsideGrantedFolders
  /// Speichern gescheitert; beim Neu verknüpfen ist nichts geändert.
  case saveFailed
}

/// Aktionen an den Zuordnungen einer Unterrichtsstunde: zuordnen, ordnen, neu verknüpfen, entfernen.
/// Die Struktur hält keinen Zustand; die Ansichten lesen nach jeder Aktion über `store.revision` neu.
@MainActor struct LessonActions {
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "LessonActions")

  let store: any PreparationStore
  let storage: any MaterialStorage
  let penNotes: any PenNoteFileRelocating

  init(
    store: any PreparationStore, storage: any MaterialStorage,
    penNotes: any PenNoteFileRelocating = NoPenNoteFileRelocation()
  ) {
    self.store = store
    self.storage = storage
    self.penNotes = penNotes
  }

  /// Je URL ein Verweis, hinten angehängt; bricht bei der ersten ungültigen URL ab, ohne vorher
  /// Angelegtes zurückzunehmen. Danach `storage.didAssign` (Bereithalten, Teilplan 03) für alles,
  /// was angelegt wurde.
  ///
  /// Swift-Hinweis: `throws(AssignError)` ist ein typisierter Fehler; der Aufrufer kennt den
  /// genauen Typ, und `catch` braucht kein Casting.
  @discardableResult
  func assign(fileURLs: [URL], to key: LessonKey) async throws(AssignError) -> [MaterialLinkItem] {
    var created: [MaterialLinkItem] = []
    var failure: AssignError?
    for url in fileURLs {
      guard let reference = storage.reference(forPickedFile: url) else {
        failure = .outsideGrantedFolders
        break
      }
      do {
        created.append(try store.assignItem(reference, to: key, at: nil))
      } catch {
        Self.logger.error("Zuordnen gescheitert: \(String(describing: error), privacy: .public)")
        failure = .saveFailed
        break
      }
    }
    if !created.isEmpty {
      await storage.didAssign(created.map(\.reference))
    }
    if let failure { throw failure }
    return created
  }

  /// Ordnet die Zuordnungen einer Stunde um; Semantik wie `Array.move(fromOffsets:toOffset:)`.
  func reorder(_ key: LessonKey, fromOffsets: IndexSet, toOffset: Int) {
    do {
      try store.moveLinks(in: key, fromOffsets: fromOffsets, toOffset: toOffset)
    } catch {
      Self.logger.error("Umordnen gescheitert: \(String(describing: error), privacy: .public)")
    }
  }

  /// Neu verknüpfen (ADR-0003): ersetzt den Ort an allen Zuordnungen mit demselben alten Ort
  /// (`StorageService.relink`). Liefert den neuen Verweis.
  @discardableResult
  func relink(_ item: MaterialLinkItem, fileURL: URL) throws(AssignError) -> MaterialReference {
    switch storage.relink(item.reference, toPickedFile: fileURL) {
    case .relinked(let new): return new
    case .outsideGrants: throw .outsideGrantedFolders
    case .saveFailed: throw .saveFailed
    }
  }

  /// ADR-0011: Zahl der Stunden mit Notizen am alten Ort (0 = kein Angebot).
  func notesToCarry(from old: MaterialReference) async -> Int {
    await penNotes.notesCount(beside: old)
  }

  /// ADR-0011: Notizen vom alten Ort neben die neue Datei mitnehmen.
  func carryNotes(from old: MaterialReference, to new: MaterialReference) async throws {
    try await penNotes.moveNotes(from: old, to: new)
  }

  /// Entfernt eine Zuordnung (die Datei selbst bleibt unberührt).
  func remove(linkID: UUID) {
    do {
      try store.removeLink(id: linkID)
    } catch {
      Self.logger.error("Entfernen gescheitert: \(String(describing: error), privacy: .public)")
    }
  }
}

// MARK: - Übernehmen, Schieben, Weiterreichen (FR-3.2, FR-3.3, FR-8)

extension LessonActions {
  /// FR-3.2: Klassen zur Wahl – alle Klassen im Stundenplan außer der eigenen.
  func copyTargetClasses(for key: LessonKey) -> [SchoolClass] {
    do {
      return try store.selectableClasses(excluding: key.schoolClass)
    } catch {
      Self.logger.error("Klassenliste gescheitert: \(String(describing: error), privacy: .public)")
      return []
    }
  }

  /// FR-3.2: Unterrichtsstunden der gewählten Klasse ab dem Tag von `key`, höchstens 28 Tage, ohne
  /// Ausfälle – die Lehrkraft wählt daraus; es gibt kein automatisches Ziel.
  func copyTargetLessons(for schoolClass: SchoolClass, from key: LessonKey) -> [Lesson] {
    do {
      return try store.candidateLessons(for: schoolClass, from: key.date, maxDays: 28)
    } catch {
      Self.logger.error("Zielstunden gescheitert: \(String(describing: error), privacy: .public)")
      return []
    }
  }

  /// FR-3.2: kopiert alle Zuordnungen in die **gewählte** Zielstunde (ohne Stiftnotizen, FR-6.1);
  /// liefert die Zahl der neuen Zuordnungen. Meldet nichts an die Notiz-Naht: Es zieht keine Datei um.
  @discardableResult
  func copyLinks(from key: LessonKey, to target: LessonKey) -> Int {
    do {
      return try store.copyMaterialLinks(from: key, to: target)
    } catch {
      Self.logger.error("Übernehmen gescheitert: \(String(describing: error), privacy: .public)")
      return 0
    }
  }

  /// FR-3.3 für ein Material (gleiche Klasse, gleiches Fach); nil → keine nächste Stunde oder
  /// Fehler, nichts geändert und nichts gemeldet. Dieselbe Zuordnung wandert, Stiftnotizen mit.
  @discardableResult
  func moveToNextLesson(linkID: UUID) -> LessonKey? {
    do {
      // Vorher lesen: Nach dem Schieben ist der alte Schlüssel weg.
      let before = try store.materialLinkItem(id: linkID)
      guard let target = try store.moveLinkToNextLesson(id: linkID) else { return nil }
      if let before, let old = before.lessonKey {
        penNotes.linksMoved([PenNoteMove(reference: before.reference, from: old, to: target)])
      }
      return target
    } catch {
      Self.logger.error("Schieben gescheitert: \(String(describing: error), privacy: .public)")
      return nil
    }
  }

  /// FR-8: alles Material der Stunde in die nächste (Ausfälle übersprungen); Reihenfolge bleibt,
  /// hinten an das Ziel angehängt. nil → keine nächste Stunde oder Fehler.
  @discardableResult
  func passOnAll(from key: LessonKey) -> LessonKey? {
    do {
      let items = try store.materialLinkItems(for: key)
      guard let target = try store.moveAllLinksToNextLesson(from: key) else { return nil }
      penNotes.linksMoved(items.map { PenNoteMove(reference: $0.reference, from: key, to: target) })
      return target
    } catch {
      Self.logger.error("Weiterreichen gescheitert: \(String(describing: error), privacy: .public)")
      return nil
    }
  }

  /// Material ohne Stunde einer gewählten Unterrichtsstunde zuordnen (FR-7). Gemeldet wird nur, wenn
  /// die Zuordnung einen gültigen alten Schlüssel hatte.
  func move(linkID: UUID, to key: LessonKey) {
    do {
      let before = try store.materialLinkItem(id: linkID)
      try store.moveLink(id: linkID, to: key)
      if let before, let old = before.lessonKey, old != key {
        penNotes.linksMoved([PenNoteMove(reference: before.reference, from: old, to: key)])
      }
    } catch {
      Self.logger.error("Zuordnen gescheitert: \(String(describing: error), privacy: .public)")
    }
  }
}

// MARK: - Ausfall und Vertretungsstunde (FR-8, FR-9)

/// Ergebnis von `LessonActions.setCancelled`.
enum CancellationResult: Equatable {
  /// Die Abweichung wurde angelegt bzw. aufgehoben.
  case changed
  /// Es war nichts zu tun (schon markiert bzw. kein Ausfall vorhanden) oder ein Fehler trat auf.
  case unchanged
  /// Der Ausfall stammt aus der Stundenplan-Quelle und lässt sich nicht von Hand aufheben.
  case blockedBySource
}

extension LessonActions {
  /// Markiert eine Stunde als ausgefallen bzw. hebt die Markierung auf. Ein Ausfall aus der Quelle
  /// (`Origin.source`) bleibt unberührt; `DataStore.removeCancellation` hebt nur `.manual` auf.
  func setCancelled(_ cancelled: Bool, key: LessonKey) -> CancellationResult {
    do {
      let existing = try store.scheduleChanges().compactMap { change -> Origin? in
        if case .cancellation(let k, let origin) = change, k == key { return origin }
        return nil
      }
      if cancelled {
        if !existing.isEmpty { return .unchanged }
        try store.markCancelled(key)
        return .changed
      }
      if existing.isEmpty { return .unchanged }
      if try store.removeCancellation(key) { return .changed }
      return .blockedBySource
    } catch {
      Self.logger.error("Ausfall ändern gescheitert: \(String(describing: error), privacy: .public)")
      return .unchanged
    }
  }

  /// FR-9: legt eine Vertretungsstunde von Hand an (Herkunft `.manual`).
  func addSubstituteLesson(
    date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject
  ) {
    do {
      try store.addSubstituteLesson(
        date: date, period: period, schoolClass: schoolClass, subject: subject)
    } catch {
      Self.logger.error("Vertretung anlegen gescheitert: \(String(describing: error), privacy: .public)")
    }
  }

  /// Entfernt eine von Hand angelegte Vertretungsstunde; `false` bei Herkunft `.source`, wenn keine
  /// besteht oder bei einem Fehler.
  @discardableResult
  func removeSubstituteLesson(
    date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject
  ) -> Bool {
    do {
      return try store.removeSubstituteLesson(
        date: date, period: period, schoolClass: schoolClass, subject: subject)
    } catch {
      Self.logger.error("Vertretung entfernen gescheitert: \(String(describing: error), privacy: .public)")
      return false
    }
  }
}
