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
  private let credentials: any CredentialStore
  private let statusStore: SourceStatusStore
  private let pendingStore: PendingImportStore
  private let calendar: Calendar
  private let now: () -> Date

  /// Fragt die Quelle für heute und die folgenden 27 Tage (vier Wochen) ab.
  private static let fetchSpanDays = 27

  /// `credentials`: derselbe Schlüsselbund-Eintrag, den auch die Quelle liest. Der Koordinator prüft damit,
  /// ob dieses Gerät überhaupt abfragen darf, und löscht ihn nach Fehlern, die sich nicht von selbst geben.
  init(
    repository: any TimetableRepository,
    makeSource: @escaping (TimetableSourceKind) -> any TimetableSource,
    credentials: any CredentialStore,
    statusStore: SourceStatusStore, pendingStore: PendingImportStore,
    calendar: Calendar = .current, now: @escaping () -> Date = Date.init
  ) {
    self.repository = repository
    self.makeSource = makeSource
    self.credentials = credentials
    self.statusStore = statusStore
    self.pendingStore = pendingStore
    self.calendar = calendar
    self.now = now
    status = statusStore.load()
    // Eine gemerkte Vorschau gilt nur noch, wenn das andere Gerät nicht schon neuer abgefragt hat und sie
    // gegen den heutigen Stand noch etwas zu zeigen hat.
    if let stored = pendingStore.load() {
      if Self.isSuperseded(stored, repository: repository) {
        try? pendingStore.save(nil)
      } else {
        pendingPreview = try? Self.makePreview(from: stored, repository: repository)
      }
    }
  }

  // MARK: - Abfrage

  /// Ob dieses Gerät die Quelle abfragen darf; Ansichten zeigen daraus den Hinweis „Anmeldung auf diesem
  /// Gerät nötig“. Ein unlesbarer Schlüsselbund-Eintrag zählt wie keiner.
  func refreshGate() -> SourceRefreshGate {
    let kind = (try? repository.timetableSourceKind()) ?? .manual
    return SourceRefreshGate.evaluate(kind: kind, hasCredentials: hasStoredCredentials())
  }

  func refresh(_ trigger: RefreshTrigger) async {
    guard !isFetching else { return }

    // 0. Von Hand oder ohne Zugangsdaten auf diesem Gerät: nichts abfragen, nichts zählen, nichts schreiben.
    let kind: TimetableSourceKind
    let existing: Timetable?
    do {
      kind = try repository.timetableSourceKind()
      existing = try repository.timetable()
    } catch {
      return recordFailure(.unexpectedResponse("Datenspeicher nicht lesbar"))
    }
    guard SourceRefreshGate.evaluate(kind: kind, hasCredentials: hasStoredCredentials()) == .ready
    else { return }
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

      // 3. Stundenplan-Teil: nur eine Vorschau vorbereiten, nichts übernehmen. Eine verworfene Vorschau
      //    desselben Stundenplan-Teils kommt nicht wieder (Nachtrag 2).
      let candidate = try Self.makePreview(from: snapshot, repository: repository)
      let offer = PendingPreviewRules.offer(
        hasDifferences: candidate != nil, checksum: TimetablePartChecksum.of(snapshot),
        remembered: pendingStore.loadDismissedChecksum())
      let preview = offer.showsPreview ? candidate : nil
      // Scheitert nur das Merken, erscheint die Vorschau eben noch einmal: kein Grund für einen Fehler.
      try? pendingStore.saveDismissedChecksum(offer.rememberedChecksum)
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
  ///
  /// Ist der gespiegelte Stand neuer als die Vorschau (Abfrage auf dem anderen Gerät, Nachtrag 3), wird
  /// nichts übernommen und die Vorschau verworfen – sonst käme ein älterer Stundenplan über einen neueren.
  func applyPendingPreview(acceptedFromSource: Set<TimetableEntry>) throws {
    guard let preview = pendingPreview,
      case .derived(let derived) = preview.snapshot.timetable
    else { return }
    if Self.isSuperseded(preview.snapshot, repository: repository) {
      return clearPreview()
    }
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
    // Der Stand ist nicht neuer als die Vorschau (oben geprüft): Abweichungen gegen den neuen Plan zuordnen.
    try storeChanges(of: preview.snapshot, stampFetchedAt: false)
    // Bei „Meine Fassung behalten“ würde dieselbe Quelle den Konflikt bei jeder Abfrage neu zeigen (Nachtrag 2).
    try? pendingStore.saveDismissedChecksum(
      PendingPreviewRules.rememberedAfterApply(
        checksum: TimetablePartChecksum.of(preview.snapshot),
        conflictSources: diff.manualConflicts.map { $0.source },
        acceptedFromSource: acceptedFromSource))
    clearPreview()
  }

  /// Verwirft die Vorschau und merkt sich ihren Stundenplan-Teil: Dieselbe Vorschau kommt nach der nächsten
  /// Abfrage nicht wieder, erst ein neuer Unterschied (Nachtrag 2).
  func discardPendingPreview() {
    if let preview = pendingPreview {
      try? pendingStore.saveDismissedChecksum(TimetablePartChecksum.of(preview.snapshot))
    }
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
    // Wer die Quelle neu wählt, beginnt neu: Auch eine früher verworfene Vorschau darf wieder erscheinen.
    try? pendingStore.saveDismissedChecksum(nil)
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

  /// Nach falschen Zugangsdaten oder mehreren Schulen werden die Zugangsdaten gelöscht (Nachtrag 1); ohne
  /// sie fragt dieses Gerät nicht mehr ab, bis sich die Lehrkraft neu anmeldet. Der Fehler bleibt im Status
  /// stehen, damit die Oberfläche die Meldung dazu zeigt.
  private func recordFailure(_ error: TimetableSourceError) {
    updateStatus(status.recordingFailure(error, at: now()))
    if error.discardsCredentials {
      try? credentials.delete()
      noteCredentialsChanged()
    }
  }

  private func hasStoredCredentials() -> Bool {
    (try? credentials.load()) != nil
  }

  private static func isSuperseded(_ snapshot: SourceSnapshot, repository: any TimetableRepository)
    -> Bool
  {
    PendingPreviewRules.isSuperseded(
      previewFetchedAt: snapshot.fetchedAt, storedFetchedAt: try? repository.sourceFetchedAt())
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
