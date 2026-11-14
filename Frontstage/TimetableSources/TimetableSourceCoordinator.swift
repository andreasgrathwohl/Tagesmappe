import Foundation
import FrontstageCore
import Observation

/// Was die Vorschau eines Imports zeigt: der Stand der Quelle und sein Abgleich mit dem vorhandenen Stundenplan.
struct ImportPreview: Equatable {
  var snapshot: SourceSnapshot
  var diff: ImportDiff
  var bellScheduleChanged: Bool

  // `ImportDiff` ist nicht `Equatable` (enthält Tupel-Arrays); deshalb von Hand.
  static func == (lhs: ImportPreview, rhs: ImportPreview) -> Bool {
    lhs.snapshot == rhs.snapshot && lhs.bellScheduleChanged == rhs.bellScheduleChanged
      && lhs.diff.added == rhs.diff.added && lhs.diff.removed == rhs.diff.removed
      && lhs.diff.changed.elementsEqual(rhs.diff.changed, by: { $0.old == $1.old && $0.new == $1.new })
      && lhs.diff.manualConflicts.elementsEqual(
        rhs.diff.manualConflicts, by: { $0.mine == $1.mine && $0.source == $1.source })
  }
}

/// Steuert die Abfrage der Stundenplan-Quelle: wann gefragt wird, was sofort gilt (Abweichungen, FR-2.2)
/// und was erst nach der Vorschau übernommen wird (Stundenplan, Zeitraster).
///
/// Grundsatz „kein Teilimport“ (Area stundenplan-quellen): Bis `fetch` und Auswertung vollständig vorliegen,
/// wird nichts geschrieben. Fehler landen in `status`, nie als Wurf bei `refresh`.
///
/// Swift-Hinweis: `@Observable` (Observation-Framework) macht gespeicherte Eigenschaften für SwiftUI
/// beobachtbar; `@MainActor` hält alle Zugriffe auf dem Haupt-Thread, wie es der SwiftData-Kontext des
/// `DataStore` verlangt. Der Netzzugriff selbst läuft in einem abgekoppelten Task außerhalb davon.
@MainActor @Observable final class TimetableSourceCoordinator {
  /// Lesend für Ansichten (Quelle, Stand) und Tests.
  let repository: any TimetableRepository

  private(set) var status: SourceStatus
  private(set) var pendingPreview: ImportPreview?
  private(set) var isFetching = false
  /// Steigt, wenn eine Ansicht Zugangsdaten gespeichert oder gelöscht hat. Andere Ansichten lesen den
  /// Schlüsselbund daraufhin neu, statt bei jedem Neuzeichnen.
  private(set) var credentialsRevision = 0

  private let makeSource: (TimetableSourceKind) -> any TimetableSource
  private let statusStore: SourceStatusStore
  private let pendingStore: PendingImportStore
  private let calendar: Calendar
  private let now: () -> Date

  /// Fragt die Quelle für heute und die folgenden 27 Tage (vier Wochen) ab.
  private static let fetchSpanDays = 27

  init(
    repository: any TimetableRepository,
    makeSource: @escaping (TimetableSourceKind) -> any TimetableSource,
    statusStore: SourceStatusStore, pendingStore: PendingImportStore,
    calendar: Calendar = .current, now: @escaping () -> Date = Date.init
  ) {
    self.repository = repository
    self.makeSource = makeSource
    self.statusStore = statusStore
    self.pendingStore = pendingStore
    self.calendar = calendar
    self.now = now
    status = statusStore.load()
    // Eine gemerkte Vorschau gilt nur noch, wenn sie gegen den heutigen Stand noch etwas zu zeigen hat.
    if let stored = pendingStore.load() {
      pendingPreview = try? Self.makePreview(from: stored, repository: repository)
    }
  }

  // MARK: - Abfrage

  func refresh(_ trigger: RefreshTrigger) async {
    guard !isFetching else { return }

    // 0. Von Hand: nichts abfragen, nichts zählen, nichts schreiben.
    let kind: TimetableSourceKind
    let existing: Timetable?
    do {
      kind = try repository.timetableSourceKind()
      existing = try repository.timetable()
    } catch {
      return recordFailure(.unexpectedResponse("Datenspeicher nicht lesbar"))
    }
    guard kind != .manual else { return }
    guard MorningRefreshPolicy.shouldFetch(trigger, status: status, now: now(), calendar: calendar)
    else { return }

    // 1. Versuch vermerken, dann abfragen – bis hierhin ist nichts außer dem Zähler geschrieben.
    updateStatus(status.recordingAttempt(trigger, at: now(), calendar: calendar))
    isFetching = true
    defer { isFetching = false }

    let source = makeSource(kind)
    let fetchTime = now()
    let today = CalendarDay(fetchTime, calendar: calendar)
    let range = today...today.adding(days: Self.fetchSpanDays)
    let snapshot: SourceSnapshot?
    do {
      // Abgekoppelt vom Haupt-Thread: Passwort-Hash (99 999 Runden) und Netz dürfen die Oberfläche nicht halten.
      snapshot = try await Task.detached {
        try await source.fetch(range: range, existing: existing, now: fetchTime)
      }.value
    } catch let error as TimetableSourceError {
      return recordFailure(error)
    } catch {
      return recordFailure(.unexpectedResponse("Unbekannter Fehler"))
    }
    guard let snapshot else { return }

    // Wurde die Quelle während der Abfrage gewechselt, ist das Ergebnis überholt.
    guard (try? repository.timetableSourceKind()) == kind else { return }

    do {
      // 2. Abweichungen gelten sofort (FR-2.2), gegen den aktuellen Stundenplan. Zuerst, damit ein
      //    Fehler beim Speichern keine Vorschau zu einem nicht gespeicherten Stand hinterlässt.
      try storeChanges(of: snapshot, stampFetchedAt: true)

      // 3. Stundenplan-Teil: nur eine Vorschau vorbereiten, nichts übernehmen.
      let preview = try Self.makePreview(from: snapshot, repository: repository)
      try pendingStore.save(preview == nil ? nil : snapshot)
      pendingPreview = preview
    } catch {
      return recordFailure(.unexpectedResponse("Datenspeicher nicht schreibbar"))
    }
    updateStatus(status.recordingSuccess(at: now()))
  }

  // MARK: - Vorschau

  /// Übernimmt die Vorschau: Stundenplan und Zeitraster, danach die Abweichungen gegen den neuen Plan.
  /// `acceptedFromSource`: Quell-Fassungen, die eine von Hand bearbeitete Fassung ersetzen sollen.
  ///
  /// Zwei Speichervorgänge (Stundenplan, dann Abweichungen): Scheitert der zweite, ist der Stundenplan schon
  /// übernommen und die Vorschau bleibt stehen; der Fehlertext der Oberfläche sagt das so.
  func applyPendingPreview(acceptedFromSource: Set<TimetableEntry>) throws {
    guard let preview = pendingPreview,
      case .derived(let derived) = preview.snapshot.timetable
    else { return }
    // Gegen den heutigen Stand neu abgleichen: Zwischenzeitliche Handarbeit bleibt geschützt.
    let existing = try repository.timetable()?.entries ?? []
    let manuallyEdited = try repository.manuallyEditedEntries()
    let diff = ImportDiffer.compare(
      existing: existing, manuallyEdited: manuallyEdited, imported: derived.entries)
    let applied = ImportApplier.apply(
      diff, existing: existing, manuallyEdited: manuallyEdited,
      acceptedFromSource: acceptedFromSource)
    try repository.replaceTimetable(
      entries: applied.entries, manuallyEdited: applied.manuallyEdited,
      weekVariantCount: derived.weekVariantCount, referenceWeekA: derived.referenceWeekA,
      bellSchedule: Self.deliveredBellSchedule(of: preview.snapshot))
    // Die Vorschau liegt nur auf diesem Gerät und kann tagelang stehen. Ist der gespiegelte Stand neuer
    // (Abfrage auf dem anderen Gerät), gelten dessen Abweichungen: unverändert lassen statt mit dem alten
    // Stand zu überschreiben (veraltete Ausfälle kämen zurück, neue Vertretungen verschwänden).
    let storedFetchedAt = try repository.sourceFetchedAt()
    if storedFetchedAt.map({ preview.snapshot.fetchedAt >= $0 }) ?? true {
      try storeChanges(of: preview.snapshot, stampFetchedAt: false)
    }
    clearPreview()
  }

  func discardPendingPreview() {
    clearPreview()
  }

  /// Von Ansichten nach Speichern oder Löschen der Zugangsdaten aufzurufen.
  func noteCredentialsChanged() {
    credentialsRevision += 1
  }

  // MARK: - Quelle wechseln

  /// Setzt die Quelle. Beim Wechsel auf „von Hand“ fallen die Quell-Abweichungen ab heute weg (Annahme A4);
  /// Zugangsdaten bleiben bis „Abmelden“. Fehlerfolge und letzter Fehler beginnen neu; Versuchszeit und
  /// Tageszähler bleiben, damit Umschalten die Abfrage-Sperre nicht umgeht (ADR-0004, RISK-1).
  func switchSource(to kind: TimetableSourceKind) throws {
    guard try repository.timetableSourceKind() != kind else { return }
    try repository.setTimetableSourceKind(kind)
    clearPreview()
    updateStatus(status.resettingForSourceSwitch())
    if kind == .manual {
      let today = CalendarDay(now(), calendar: calendar)
      let kept = try repository.scheduleChanges().filter { change in
        !(Self.origin(of: change) == .source && Self.date(of: change) >= today)
      }
      try repository.replaceScheduleChanges(kept, sourceFetchedAt: nil)
    }
  }

  // MARK: - Hilfen

  /// Ordnet die Abweichungen des Stands gegen den aktuellen Stundenplan zu und ersetzt die der Quelle im Zeitraum.
  private func storeChanges(of snapshot: SourceSnapshot, stampFetchedAt: Bool) throws {
    let timetable =
      try repository.timetable()
      ?? Timetable(referenceWeekA: snapshot.range.lowerBound.mondayOfWeek)
    let resolved = SourceChangeResolver.resolve(
      snapshot.changes, timetable: timetable,
      nonTeachingPeriods: try repository.nonTeachingPeriods()
    ).resolved
    let merged = ScheduleChangeMerger.replacingSourceChanges(
      in: try repository.scheduleChanges(), with: resolved, range: snapshot.range)
    try repository.replaceScheduleChanges(
      merged, sourceFetchedAt: stampFetchedAt ? snapshot.fetchedAt : nil)
  }

  /// `nil`, wenn der Stundenplan-Teil nichts zu zeigen hat: kein Unterschied und gleiches Zeitraster,
  /// oder die Ableitung war nicht möglich (`.noLessonsInRange`, `.weekVariantsUndetermined`).
  private static func makePreview(from snapshot: SourceSnapshot, repository: any TimetableRepository)
    throws -> ImportPreview?
  {
    guard case .derived(let derived) = snapshot.timetable else { return nil }
    let existingTimetable = try repository.timetable()
    let diff = ImportDiffer.compare(
      existing: existingTimetable?.entries ?? [],
      manuallyEdited: try repository.manuallyEditedEntries(), imported: derived.entries)
    let bellChanged =
      deliveredBellSchedule(of: snapshot).map {
        $0 != (existingTimetable?.bellSchedule ?? BellSchedule())
      } ?? false
    let nothingToShow =
      diff.added.isEmpty && diff.changed.isEmpty && diff.manualConflicts.isEmpty
      && diff.removed.isEmpty && !bellChanged
    return nothingToShow
      ? nil : ImportPreview(snapshot: snapshot, diff: diff, bellScheduleChanged: bellChanged)
  }

  /// Zeitraster nur, wenn die Quelle eines geliefert hat: Ein leeres zählt nicht und darf das von Hand
  /// gepflegte nie ersetzen (Plan: „Zeitraster aus dem Stand, wenn geliefert“).
  private static func deliveredBellSchedule(of snapshot: SourceSnapshot) -> BellSchedule? {
    guard let bell = snapshot.bellSchedule, !bell.periods.isEmpty else { return nil }
    return bell
  }

  private func clearPreview() {
    pendingPreview = nil
    try? pendingStore.save(nil)
  }

  private func recordFailure(_ error: TimetableSourceError) {
    updateStatus(status.recordingFailure(error, at: now()))
  }

  private func updateStatus(_ new: SourceStatus) {
    status = new
    statusStore.save(new)
  }

  private static func origin(of change: ScheduleChange) -> Origin {
    switch change {
    case let .cancellation(_, origin): return origin
    case let .substituteLesson(_, _, _, _, origin): return origin
    }
  }

  private static func date(of change: ScheduleChange) -> CalendarDay {
    switch change {
    case let .cancellation(key, _): return key.date
    case let .substituteLesson(date, _, _, _, _): return date
    }
  }
}
