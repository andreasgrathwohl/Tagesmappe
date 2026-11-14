import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// Quelle mit vorbereitetem (austauschbarem) Ergebnis; zählt die Aufrufe.
private final class FakeSource: TimetableSource, @unchecked Sendable {
  private let lock = NSLock()
  private var _calls = 0
  private var _result: Result<SourceSnapshot?, TimetableSourceError>

  init(_ result: Result<SourceSnapshot?, TimetableSourceError>) { _result = result }

  var kind: TimetableSourceKind { .schulmanager }
  var calls: Int { lock.withLock { _calls } }

  func setResult(_ result: Result<SourceSnapshot?, TimetableSourceError>) {
    lock.withLock { _result = result }
  }

  func fetch(range: ClosedRange<CalendarDay>, existing: Timetable?, now: Date) async throws
    -> SourceSnapshot?
  {
    let result = lock.withLock {
      _calls += 1
      return _result
    }
    return try result.get()
  }
}

/// Reicht an den echten `DataStore` weiter und zählt die Schreibaufrufe.
@MainActor private final class CountingRepository: TimetableRepository {
  let inner: DataStore
  private(set) var writes = 0
  init(_ inner: DataStore) { self.inner = inner }

  var revision: Int { inner.revision }
  func timetable() throws -> Timetable? { try inner.timetable() }
  func manuallyEditedEntries() throws -> Set<TimetableEntry> { try inner.manuallyEditedEntries() }
  func nonTeachingPeriods() throws -> [NonTeachingPeriod] { try inner.nonTeachingPeriods() }
  func scheduleChanges() throws -> [ScheduleChange] { try inner.scheduleChanges() }
  func timetableSourceRaw() throws -> String { try inner.timetableSourceRaw() }
  func sourceFetchedAt() throws -> Date? { try inner.sourceFetchedAt() }
  func setTimetableSourceRaw(_ raw: String) throws {
    writes += 1
    try inner.setTimetableSourceRaw(raw)
  }
  func replaceTimetable(
    entries: [TimetableEntry], manuallyEdited: Set<TimetableEntry>, weekVariantCount: Int,
    referenceWeekA: CalendarDay?, bellSchedule: BellSchedule?
  ) throws {
    writes += 1
    try inner.replaceTimetable(
      entries: entries, manuallyEdited: manuallyEdited, weekVariantCount: weekVariantCount,
      referenceWeekA: referenceWeekA, bellSchedule: bellSchedule)
  }
  func replaceScheduleChanges(_ changes: [ScheduleChange], sourceFetchedAt: Date?) throws {
    writes += 1
    try inner.replaceScheduleChanges(changes, sourceFetchedAt: sourceFetchedAt)
  }
}

/// Steuerbare Uhr (Test-Host, nur Haupt-Thread).
@MainActor private final class TestClock {
  var value: Date
  init(_ value: Date) { self.value = value }
}

@MainActor @Suite("TimetableSourceCoordinator")
struct TimetableSourceCoordinatorTests {
  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }()

  private let mo5_8a = TimetableEntry(
    weekday: .monday, period: 5, schoolClass: SchoolClass("8a"), subject: Subject("Englisch"))
  private let di2_8b = TimetableEntry(
    weekday: .tuesday, period: 2, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"))
  private let mi3_8b = TimetableEntry(
    weekday: .wednesday, period: 3, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"))
  private let fr4_9c = TimetableEntry(
    weekday: .friday, period: 4, schoolClass: SchoolClass("9c"), subject: Subject("Deutsch"))

  private var morning: Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 7))!
  }

  private func snapshot(
    entries: [TimetableEntry], changes: [SourceChange] = [], bell: BellSchedule? = nil, at: Date
  ) -> SourceSnapshot {
    SourceSnapshot(
      kind: .schulmanager, fetchedAt: at, range: tue17...tue17.adding(days: 27),
      timetable: .derived(
        DerivedTimetable(
          entries: entries, weekVariantCount: 1,
          referenceWeekA: CalendarDay(year: 2026, month: 11, day: 16))),
      bellSchedule: bell, changes: changes)
  }

  /// Gemeinsamer Aufbau: Koordinator mit eigener Ablage je Test.
  private struct Env {
    let coordinator: TimetableSourceCoordinator
    let credentials: InMemoryCredentialStore
    let defaults: UserDefaults
    let directory: URL
    let suite: String

    func cleanUp() {
      defaults.removePersistentDomain(forName: suite)
      try? FileManager.default.removeItem(at: directory)
    }
  }

  /// Standard: Zugangsdaten liegen auf diesem Gerät (wie am iPad nach der Anmeldung).
  private func makeEnv(
    repository: any TimetableRepository, source: any TimetableSource, clock: TestClock,
    credentials: InMemoryCredentialStore = InMemoryCredentialStore()
  ) -> Env {
    let suite = "coordinator-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "coordinator-tests-\(UUID().uuidString)", isDirectory: true)
    let coordinator = TimetableSourceCoordinator(
      repository: repository, makeSource: { _ in source }, credentials: credentials,
      statusStore: SourceStatusStore(defaults: defaults), pendingStore: PendingImportStore(directory: directory),
      calendar: calendar, now: { clock.value })
    return Env(
      coordinator: coordinator, credentials: credentials, defaults: defaults, directory: directory,
      suite: suite)
  }

  /// Neuer Koordinator auf derselben Ablage wie `env` (Neustart der App).
  private func restart(_ env: Env, repository: any TimetableRepository, source: any TimetableSource)
    -> TimetableSourceCoordinator
  {
    TimetableSourceCoordinator(
      repository: repository, makeSource: { _ in source }, credentials: env.credentials,
      statusStore: SourceStatusStore(defaults: env.defaults),
      pendingStore: PendingImportStore(directory: env.directory), calendar: calendar,
      now: { morning })
  }

  @Test("Kein Teilimport: Fehler lässt alles unberührt (Area stundenplan-quellen)")
  func failedFetchLeavesEverythingUntouched() async throws {
    let store = try makeStore()
    try store.setTimetableSourceKind(.schulmanager)
    let earlier = morning.addingTimeInterval(-86_400)
    try store.replaceScheduleChanges([], sourceFetchedAt: earlier)
    let repository = CountingRepository(store)
    let env = makeEnv(
      repository: repository, source: FakeSource(.failure(.offline)), clock: TestClock(morning))
    defer { env.cleanUp() }

    await env.coordinator.refresh(.userRequest)

    #expect(repository.writes == 0)
    #expect(env.coordinator.status.consecutiveFailures == 1)
    #expect(env.coordinator.status.lastError == .offline)
    #expect(try store.sourceFetchedAt() == earlier)
  }

  @Test("Dreimal Fehler empfiehlt die Pflege von Hand")
  func threeFailuresSuggestManualMaintenance() async throws {
    let store = try makeStore()
    try store.setTimetableSourceKind(.schulmanager)
    let clock = TestClock(morning)
    let env = makeEnv(repository: store, source: FakeSource(.failure(.offline)), clock: clock)
    defer { env.cleanUp() }

    for _ in 0..<3 {
      await env.coordinator.refresh(.userRequest)
      clock.value = clock.value.addingTimeInterval(61)
    }

    #expect(env.coordinator.status.suggestsManualMaintenance)
  }

  @Test("Vertretung steht ohne Rückfrage in der 3. Stunde (AK-21)")
  func sourceChangesAreAppliedWithoutPreview() async throws {
    let store = try makeStore()
    try store.addEntry(mo5_8a, origin: .source)
    try store.setTimetableSourceKind(.schulmanager)
    let change = SourceChange.substitute(
      date: tue17, period: 3, schoolClass: SchoolClass("6c"), subject: Subject("Mathematik"))
    let source = FakeSource(.success(snapshot(entries: [mo5_8a], changes: [change], at: morning)))
    let env = makeEnv(repository: store, source: source, clock: TestClock(morning))
    defer { env.cleanUp() }

    await env.coordinator.refresh(.appBecameActive)

    #expect(env.coordinator.pendingPreview == nil)
    let lessons = try store.lessons(on: tue17)
    #expect(
      lessons.contains {
        $0.period == 3 && $0.key.schoolClass == SchoolClass("6c") && $0.isSubstituteLesson
      })
    #expect(try store.sourceFetchedAt() == morning)
    #expect(env.coordinator.status.lastSuccessAt == morning)
  }

  @Test("Unterschiede im Stundenplan warten auf die Vorschau")
  func timetableDifferencesWaitForPreview() async throws {
    let store = try makeStore()
    try store.setTimetableSourceKind(.schulmanager)
    let before = try store.timetable()?.entries
    let source = FakeSource(.success(snapshot(entries: [di2_8b, mi3_8b, fr4_9c], at: morning)))
    let env = makeEnv(repository: store, source: source, clock: TestClock(morning))
    defer { env.cleanUp() }

    await env.coordinator.refresh(.appBecameActive)

    #expect(env.coordinator.pendingPreview?.diff.added.count == 3)
    #expect(try store.timetable()?.entries == before)
    // Die Vorschau überlebt einen Neustart: gleicher Speicherort, neuer Koordinator.
    let restarted = restart(env, repository: store, source: source)
    #expect(restarted.pendingPreview != nil)
  }

  @Test("AK-3: Übernahme behält den von Hand angelegten Eintrag")
  func applyingPreviewKeepsManualEntry() async throws {
    let store = try makeStore()
    try store.addEntry(mo5_8a, origin: .manual)
    try store.setTimetableSourceKind(.schulmanager)
    let source = FakeSource(.success(snapshot(entries: [di2_8b, mi3_8b, fr4_9c], at: morning)))
    let env = makeEnv(repository: store, source: source, clock: TestClock(morning))
    defer { env.cleanUp() }
    await env.coordinator.refresh(.appBecameActive)

    try env.coordinator.applyPendingPreview(acceptedFromSource: [])

    #expect(try store.timetable()?.entries.count == 4)
    #expect(try store.manuallyEditedEntries() == [mo5_8a])
    #expect(env.coordinator.pendingPreview == nil)
    #expect(PendingImportStore(directory: env.directory).load() == nil)
  }

  @Test("Von Hand: es wird nie abgefragt")
  func manualSourceNeverFetches() async throws {
    let store = try makeStore()
    let source = FakeSource(.success(snapshot(entries: [di2_8b], at: morning)))
    let env = makeEnv(repository: store, source: source, clock: TestClock(morning))
    defer { env.cleanUp() }

    await env.coordinator.refresh(.appBecameActive)
    await env.coordinator.refresh(.userRequest)

    #expect(source.calls == 0)
    #expect(env.coordinator.status == SourceStatus())
    #expect(try store.timetable()?.entries ?? [] == [])
  }

  @Test("Erstes Aktivieren am Tag fragt ab, ein zweites nach Erfolg nicht (AK-21)")
  func activationTriggersFetchOncePerDay() async throws {
    let store = try makeStore()
    try store.setTimetableSourceKind(.schulmanager)
    let clock = TestClock(morning)
    let source = FakeSource(.success(snapshot(entries: [], at: morning)))
    let env = makeEnv(repository: store, source: source, clock: clock)
    defer { env.cleanUp() }

    await env.coordinator.refresh(.appBecameActive)
    clock.value = clock.value.addingTimeInterval(3 * 3600)
    await env.coordinator.refresh(.appBecameActive)

    #expect(source.calls == 1)
  }

  @Test("Weder Passwort noch Token landen in Datei oder UserDefaults")
  func persistedStateNeverContainsSecrets() async throws {
    let store = try makeStore()
    try store.setTimetableSourceKind(.schulmanager)
    let source = FakeSource(.success(snapshot(entries: [di2_8b], at: morning)))
    let env = makeEnv(repository: store, source: source, clock: TestClock(morning))
    defer { env.cleanUp() }

    await env.coordinator.refresh(.appBecameActive)

    let file = try Data(contentsOf: env.directory.appendingPathComponent("pending-import.json"))
    let fileText = String(decoding: file, as: UTF8.self)
    let defaultsText = "\(env.defaults.dictionaryRepresentation())"
    for secret in ["Beispiel-Passwort-1", "jwt-beispiel"] {
      #expect(!fileText.contains(secret))
      #expect(!defaultsText.contains(secret))
    }
  }

  @Test("Wechsel auf „von Hand“ entfernt Quell-Abweichungen ab heute")
  func switchingToManualDropsFutureSourceChanges() async throws {
    let store = try makeStore()
    try store.setTimetableSourceKind(.schulmanager)
    func cancellation(_ day: CalendarDay) -> ScheduleChange {
      .cancellation(
        LessonKey(date: day, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1),
        .source)
    }
    let past = CalendarDay(year: 2026, month: 11, day: 10)
    try store.replaceScheduleChanges([cancellation(past), cancellation(wed18)], sourceFetchedAt: nil)
    let env = makeEnv(
      repository: store, source: FakeSource(.success(nil)), clock: TestClock(morning))
    defer { env.cleanUp() }

    try env.coordinator.switchSource(to: .manual)

    #expect(try store.scheduleChanges() == [cancellation(past)])
    #expect(try store.timetableSourceKind() == .manual)
  }

  @Test("Leeres Zeitraster der Quelle ersetzt das von Hand gepflegte nicht (Q-16)")
  func emptyClassHoursKeepsBellSchedule() async throws {
    let store = try makeStore()
    let manualBell = BellSchedule(periods: [
      1: TimeOfDay(hour: 7, minute: 45)...TimeOfDay(hour: 8, minute: 30)
    ])
    try store.setBellSchedule(manualBell)
    try store.setTimetableSourceKind(.schulmanager)
    let source = FakeSource(
      .success(snapshot(entries: [di2_8b], bell: BellSchedule(), at: morning)))
    let env = makeEnv(repository: store, source: source, clock: TestClock(morning))
    defer { env.cleanUp() }
    await env.coordinator.refresh(.appBecameActive)
    #expect(env.coordinator.pendingPreview?.bellScheduleChanged == false)

    try env.coordinator.applyPendingPreview(acceptedFromSource: [])

    #expect(try store.timetable()?.bellSchedule == manualBell)
    #expect(try store.timetable()?.entries == [di2_8b])
  }

  @Test("Umschalten der Quelle umgeht die Abfrage-Sperre nicht (ADR-0004, RISK-1)")
  func switchingSourceDoesNotBypassRateLimit() async throws {
    let store = try makeStore()
    try store.setTimetableSourceKind(.schulmanager)
    let clock = TestClock(morning)
    let source = FakeSource(.failure(.offline))
    let env = makeEnv(repository: store, source: source, clock: clock)
    defer { env.cleanUp() }
    await env.coordinator.refresh(.userRequest)

    try env.coordinator.switchSource(to: .manual)
    try env.coordinator.switchSource(to: .schulmanager)
    clock.value = clock.value.addingTimeInterval(10)
    await env.coordinator.refresh(.userRequest)

    #expect(source.calls == 1)
    #expect(env.coordinator.status.lastAttemptAt == morning)
    #expect(env.coordinator.status.consecutiveFailures == 0)
    #expect(env.coordinator.status.lastError == nil)
  }

  @Test("Überholte Vorschau wird beim Übernehmen verworfen, nichts überschrieben (Nachtrag 3)")
  func supersededPreviewIsDiscardedOnApply() async throws {
    let store = try makeStore()
    try store.setTimetableSourceKind(.schulmanager)
    let oldChange = SourceChange.substitute(
      date: tue17, period: 3, schoolClass: SchoolClass("6c"), subject: Subject("Mathematik"))
    let source = FakeSource(
      .success(snapshot(entries: [di2_8b, mi3_8b], changes: [oldChange], at: morning)))
    let env = makeEnv(repository: store, source: source, clock: TestClock(morning))
    defer { env.cleanUp() }
    await env.coordinator.refresh(.appBecameActive)
    #expect(env.coordinator.pendingPreview != nil)
    let timetableBefore = try store.timetable()?.entries

    // Das andere Gerät fragt später ab; sein Stand und seine Abweichungen kommen per Spiegelung.
    let newer = ScheduleChange.cancellation(
      LessonKey(date: wed18, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1),
      .source)
    let laterFetch = morning.addingTimeInterval(86_400)
    try store.replaceScheduleChanges([newer], sourceFetchedAt: laterFetch)

    try env.coordinator.applyPendingPreview(acceptedFromSource: [])

    #expect(try store.scheduleChanges() == [newer])
    #expect(try store.sourceFetchedAt() == laterFetch)
    #expect(try store.timetable()?.entries == timetableBefore)
    #expect(env.coordinator.pendingPreview == nil)
    #expect(PendingImportStore(directory: env.directory).load() == nil)
  }

  @Test("Überholte Vorschau wird beim Laden verworfen (Nachtrag 3)")
  func supersededPreviewIsDiscardedOnLoad() async throws {
    let store = try makeStore()
    try store.setTimetableSourceKind(.schulmanager)
    let source = FakeSource(.success(snapshot(entries: [di2_8b, mi3_8b], at: morning)))
    let env = makeEnv(repository: store, source: source, clock: TestClock(morning))
    defer { env.cleanUp() }
    await env.coordinator.refresh(.appBecameActive)
    #expect(env.coordinator.pendingPreview != nil)

    // Gleicher Stand wie die Vorschau: Sie bleibt nach dem Neustart.
    #expect(restart(env, repository: store, source: source).pendingPreview != nil)

    // Neuerer Stand vom anderen Gerät: Sie fällt beim Neustart weg, auch die Datei.
    try store.replaceScheduleChanges([], sourceFetchedAt: morning.addingTimeInterval(3600))
    #expect(restart(env, repository: store, source: source).pendingPreview == nil)
    #expect(PendingImportStore(directory: env.directory).load() == nil)
  }

  // MARK: - Zugangsdaten (Nachtrag 1, 4)

  @Test("Mehrere Schulen: Zugangsdaten gelöscht, keine automatische Abfrage mehr (Nachtrag 1)")
  func multipleSchoolsDiscardsCredentialsAndStopsRefreshes() async throws {
    let store = try makeStore()
    try store.setTimetableSourceKind(.schulmanager)
    let clock = TestClock(morning)
    let source = FakeSource(.failure(.multipleSchoolsUnsupported))
    let env = makeEnv(repository: store, source: source, clock: clock)
    defer { env.cleanUp() }
    let revisionBefore = env.coordinator.credentialsRevision

    await env.coordinator.refresh(.appBecameActive)

    #expect(try env.credentials.load() == nil)
    #expect(env.coordinator.credentialsRevision > revisionBefore)
    #expect(env.coordinator.status.lastError == .multipleSchoolsUnsupported)
    #expect(env.coordinator.refreshGate() == .signInRequired)

    clock.value = clock.value.addingTimeInterval(86_400)
    await env.coordinator.refresh(.appBecameActive)
    await env.coordinator.refresh(.backgroundRefresh)
    #expect(source.calls == 1)
    // Die Meldung bleibt stehen, es wird nichts weiter gezählt.
    #expect(env.coordinator.status.lastError == .multipleSchoolsUnsupported)
    #expect(env.coordinator.status.consecutiveFailures == 1)
  }

  @Test("Falsche Zugangsdaten werden gelöscht")
  func invalidCredentialsAreDiscarded() async throws {
    let store = try makeStore()
    try store.setTimetableSourceKind(.schulmanager)
    let env = makeEnv(
      repository: store, source: FakeSource(.failure(.invalidCredentials)), clock: TestClock(morning))
    defer { env.cleanUp() }

    await env.coordinator.refresh(.userRequest)

    #expect(try env.credentials.load() == nil)
    #expect(env.credentials.deletions == 1)
  }

  @Test(
    "Netz-, Server- und Formfehler behalten die Zugangsdaten (Nachtrag 1)",
    arguments: [
      TimetableSourceError.offline, .server(status: 503), .unexpectedResponse("Form"),
    ])
  func transientErrorsKeepCredentials(_ error: TimetableSourceError) async throws {
    let store = try makeStore()
    try store.setTimetableSourceKind(.schulmanager)
    let env = makeEnv(
      repository: store, source: FakeSource(.failure(error)), clock: TestClock(morning))
    defer { env.cleanUp() }

    await env.coordinator.refresh(.userRequest)

    #expect(try env.credentials.load() == InMemoryCredentialStore.sample)
    #expect(env.credentials.deletions == 0)
    #expect(env.coordinator.status.lastError == error)
  }

  @Test("Ohne Zugangsdaten auf diesem Gerät: keine Abfrage, kein Fehler, Stand bleibt (Nachtrag 4)")
  func noCredentialsOnThisDeviceNeverFetches() async throws {
    let store = try makeStore()
    try store.setTimetableSourceKind(.schulmanager)
    // Stand vom anderen Gerät, per Spiegelung angekommen.
    let otherDeviceFetch = morning.addingTimeInterval(-600)
    try store.replaceScheduleChanges([], sourceFetchedAt: otherDeviceFetch)
    let source = FakeSource(.success(snapshot(entries: [di2_8b], at: morning)))
    let env = makeEnv(
      repository: store, source: source, clock: TestClock(morning),
      credentials: InMemoryCredentialStore(nil))
    defer { env.cleanUp() }

    await env.coordinator.refresh(.appBecameActive)
    await env.coordinator.refresh(.backgroundRefresh)
    await env.coordinator.refresh(.userRequest)

    #expect(source.calls == 0)
    #expect(env.coordinator.status == SourceStatus())
    #expect(env.coordinator.refreshGate() == .signInRequired)
    #expect(try store.sourceFetchedAt() == otherDeviceFetch)
    #expect(env.coordinator.pendingPreview == nil)
  }

  // MARK: - Gemerkte Vorschau (Nachtrag 2)

  @Test("Verworfene Vorschau kommt beim gleichen Stand nicht wieder, ein neuer Unterschied schon")
  func dismissedPreviewIsRemembered() async throws {
    let store = try makeStore()
    try store.setTimetableSourceKind(.schulmanager)
    let clock = TestClock(morning)
    let source = FakeSource(.success(snapshot(entries: [di2_8b], at: morning)))
    let env = makeEnv(repository: store, source: source, clock: clock)
    defer { env.cleanUp() }
    await env.coordinator.refresh(.userRequest)
    #expect(env.coordinator.pendingPreview != nil)

    env.coordinator.discardPendingPreview()
    clock.value = clock.value.addingTimeInterval(61)
    source.setResult(.success(snapshot(entries: [di2_8b], at: clock.value)))
    await env.coordinator.refresh(.userRequest)

    #expect(source.calls == 2)
    #expect(env.coordinator.pendingPreview == nil)
    #expect(PendingImportStore(directory: env.directory).load() == nil)
    // Die Statusleiste meldet keine wartende Vorschau.
    let model = SourceStatusBarModel(
      kind: .schulmanager, fetchedAt: try store.sourceFetchedAt(), status: env.coordinator.status,
      hasPendingPreview: env.coordinator.pendingPreview != nil, hasCredentials: true,
      now: clock.value, calendar: calendar)
    #expect(model.notice == .none)

    clock.value = clock.value.addingTimeInterval(61)
    source.setResult(.success(snapshot(entries: [di2_8b, mi3_8b], at: clock.value)))
    await env.coordinator.refresh(.userRequest)
    #expect(env.coordinator.pendingPreview?.diff.added.count == 2)
  }

  @Test("„Meine Fassung behalten“ merkt den Stand: derselbe Konflikt kommt nicht wieder")
  func keepMineIsRemembered() async throws {
    let store = try makeStore()
    try store.addEntry(mo5_8a, origin: .manual)
    try store.setTimetableSourceKind(.schulmanager)
    let mo5_8aSource = TimetableEntry(
      weekday: .monday, period: 5, schoolClass: SchoolClass("8a"), subject: Subject("Mathematik"))
    let clock = TestClock(morning)
    let source = FakeSource(.success(snapshot(entries: [mo5_8aSource, di2_8b], at: morning)))
    let env = makeEnv(repository: store, source: source, clock: clock)
    defer { env.cleanUp() }
    await env.coordinator.refresh(.userRequest)
    #expect(env.coordinator.pendingPreview?.diff.manualConflicts.count == 1)

    try env.coordinator.applyPendingPreview(acceptedFromSource: [])
    #expect(Set(try store.timetable()?.entries ?? []) == [mo5_8a, di2_8b])

    clock.value = clock.value.addingTimeInterval(61)
    await env.coordinator.refresh(.userRequest)
    #expect(source.calls == 2)
    #expect(env.coordinator.pendingPreview == nil)
  }
}
