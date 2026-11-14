import FrontstageCore
import Foundation
import Observation
import OSLog

/// Logik der Tagesansicht (FR-4, FR-7, FR-8, FR-9, FR-11.1): baut aus Stundenplan, Abweichungen und
/// Zuordnungen die Zeilen eines Tages. Kennt die Stundenplan-Quelle nicht (dafür `SourceStatusBar`).
///
/// Swift-Hinweis: `@Observable` macht jede gespeicherte Eigenschaft beobachtbar; SwiftUI zeichnet eine
/// Ansicht neu, die beim Lesen von `content` o. Ä. in ihrem `body` steht. `private(set)` hält das
/// Schreiben beim View-Modell.
@MainActor @Observable final class DayViewModel {
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "DayViewModel")

  private let environment: AppEnvironment

  var day: CalendarDay
  private(set) var content: DayContent = .noLessons
  /// Zuordnungen des Tages, deren Stunde es heute nicht gibt (z. B. Ferien, Plan geändert).
  private(set) var materialsWithoutLesson: [MaterialLinkItem] = []
  /// Zuordnungen, deren Öffnen gerade läuft (`StorageService.open` wartet bis 120 s auf das
  /// Herunterladen) – Ladezustand der Zeile.
  private(set) var openingLinkIDs: Set<UUID> = []
  let actions: LessonActions

  init(environment: AppEnvironment) {
    self.environment = environment
    self.day = environment.today()
    self.actions = LessonActions(
      store: environment.store, storage: environment.storage, penNotes: environment.penNotes)
    reload()
  }

  // MARK: Tageswechsel

  func showPreviousDay() {
    day = day.adding(days: -1)
    reload()
  }

  func showNextDay() {
    day = day.adding(days: 1)
    reload()
  }

  func showToday() {
    day = environment.today()
    reload()
  }

  /// Unterrichtsstunden der nächsten `days` Tage ab dem angezeigten Tag (ohne Ausfälle) – Auswahl für
  /// „Material ohne Stunde zuordnen“ (FR-7); es gibt kein automatisches Ziel.
  func assignableLessons(days: Int = 14) -> [Lesson] {
    var result: [Lesson] = []
    for offset in 0..<days {
      let lessons = (try? environment.store.lessons(on: day.adding(days: offset))) ?? []
      result += lessons.filter { !$0.isCancelled }
    }
    return result
  }

  // MARK: Zeilenbau

  /// Baut `content` und `materialsWithoutLesson` neu und liest die Verfügbarkeit des Materials dieses Tages.
  func reload() {
    let result = Self.content(for: day, store: environment.store, storage: environment.storage)
    content = result.content
    materialsWithoutLesson = result.orphans
  }

  /// Zeilenbau eines Tages – gemeinsam für Tagesansicht und Vorbereiten-Woche (kein doppelter Bau).
  /// Liest dabei die Verfügbarkeit des Materials (`storage.refreshAvailability`). Bei einem Datenfehler:
  /// `.noLessons` und keine Zuordnungen ohne Stunde.
  static func content(
    for day: CalendarDay, store: any PreparationStore, storage: any MaterialStorage
  ) -> (content: DayContent, orphans: [MaterialLinkItem]) {
    do {
      let orphans = try store.orphanedLinkItems(on: day)

      if let period = try store.nonTeachingPeriods().first(where: { $0.contains(day) }) {
        storage.refreshAvailability(for: orphans.map(\.reference))
        return (.nonTeachingDay(title: period.title), orphans)
      }

      let lessons = try store.lessons(on: day)
      guard !lessons.isEmpty else {
        storage.refreshAvailability(for: orphans.map(\.reference))
        return (.noLessons, orphans)
      }

      let bell = try store.timetable()?.bellSchedule.periods ?? [:]
      var itemsByLesson: [String: [MaterialLinkItem]] = [:]
      var references = orphans.map(\.reference)
      for lesson in lessons {
        let items = try store.materialLinkItems(for: lesson.key)
        itemsByLesson[lesson.key.storageText] = items
        references += items.map(\.reference)
      }
      // Erst lesen lassen, dann `availability` auswerten: Die Zeilen zeigen den frischen Stand.
      storage.refreshAvailability(for: references)

      var rows: [DayRow] = []
      let byPeriod = Dictionary(grouping: lessons, by: \.period)
      guard let first = byPeriod.keys.min(), let last = byPeriod.keys.max() else {
        return (.noLessons, orphans)
      }
      for period in first...last {
        // Gruppierung behält die Reihenfolge von `lessons(on:)` (Kern-Reihenfolge).
        guard let inPeriod = byPeriod[period] else {
          rows.append(.noLesson(period: period, time: bell[period]))
          continue
        }
        for lesson in inPeriod {
          let materials = (itemsByLesson[lesson.key.storageText] ?? []).map {
            MaterialRow(item: $0, availability: storage.availability[$0.reference.locationKey])
          }
          rows.append(
            .lesson(
              LessonRow(
                lesson: lesson, status: status(of: lesson), materials: materials,
                info: try store.lessonInfo(for: lesson.key))))
        }
      }
      return (.rows(rows), orphans)
    } catch {
      logger.error("Tag laden gescheitert: \(String(describing: error), privacy: .public)")
      return (.noLessons, [])
    }
  }

  private static func status(of lesson: Lesson) -> LessonStatus {
    if lesson.isCancelled { return .cancelled(lesson.cancellationOrigin ?? .manual) }
    return lesson.isSubstituteLesson ? .substitute : .regular
  }

  // MARK: Öffnen

  /// Was ein Tipp auf die Zeile auslöst.
  func openAction(for row: MaterialRow) -> MaterialOpenAction {
    if case .unavailable? = row.availability { return .unavailable(row.item.reference) }
    if environment.viewerAvailable && row.item.reference.fileKind.opensInViewer {
      return .viewer(row.item)
    }
    return .open(row.item.reference)
  }

  /// Nur für `.open`: übergibt an `StorageService.open`; die Ansicht zeigt das Ergebnis an. Während des
  /// Wartens steht die Zuordnung in `openingLinkIDs`. Ein zweiter Tipp ruft `open` erneut (03 liefert dann
  /// sofort `.waitingForDownload`) und entfernt den Ladezustand des ersten nicht.
  func open(_ row: MaterialRow, anchor: HandOffAnchor) async -> OpenOutcome {
    let inserted = openingLinkIDs.insert(row.id).inserted
    let outcome = await environment.storage.open(row.item.reference, anchor: anchor)
    if inserted { openingLinkIDs.remove(row.id) }
    return outcome
  }
}
