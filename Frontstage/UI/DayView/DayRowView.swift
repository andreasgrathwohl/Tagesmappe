import FrontstageCore
import SwiftUI

/// Was die Zeilen der Tagesansicht auslösen können. Die Ansicht `DayView` besitzt den Zustand
/// (Dialoge, Dateiauswahl) und reicht diese Closures nach unten – die Zeilen selbst halten keinen.
struct DayRowActions {
  var open: (MaterialRow, HandOffAnchor) -> Void
  var relink: (MaterialRow) -> Void
  var moveToNext: (MaterialRow) -> Void
  var assign: (MaterialLinkItem) -> Void
  var setCancelled: (LessonKey, Bool) -> Void
  var passOn: (LessonKey) -> Void
  /// Öffnet die Tafel der Stunde (Teilplan 07, FR-12).
  var openBoard: (LessonKey) -> Void
}

/// Eine Zeile der Tagesansicht: Unterrichtsstunde oder Lücke. Systemstandard ohne eigene Palette oder
/// Schrift; Gestaltung ist offen (DESIGN.md).
struct DayRowView: View {
  let row: DayRow
  let openingIDs: Set<UUID>
  let actions: DayRowActions

  var body: some View {
    switch row {
    case .noLesson(let period, let time):
      HStack(spacing: 16) {
        PeriodHeader(period: period, time: time)
        StatementLabel(statement: .noLesson)
          .foregroundStyle(.secondary)
        Spacer(minLength: 0)
      }
      .accessibilityElement(children: .combine)
    case .lesson(let lesson):
      LessonRowView(lesson: lesson, openingIDs: openingIDs, actions: actions)
    }
  }
}

/// Stunde und Uhrzeit.
private struct PeriodHeader: View {
  let period: Int
  let time: ClosedRange<TimeOfDay>?

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("dayView.period \(period)")
        .font(.headline)
      if let time {
        Text(verbatim: "\(Self.text(time.lowerBound))–\(Self.text(time.upperBound))")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
    }
    .frame(minWidth: 88, alignment: .leading)
  }

  private static func text(_ time: TimeOfDay) -> String {
    String(format: "%d:%02d", time.hour, time.minute)
  }
}

/// Eine der vier Aussagen: Symbol **und** Text, nie nur Farbe.
private struct StatementLabel: View {
  let statement: DayStatement

  var body: some View {
    Label(LocalizedStringKey(statement.labelKey), systemImage: statement.symbolName)
  }
}

private struct LessonRowView: View {
  @Environment(AppEnvironment.self) private var environment
  let lesson: LessonRow
  let openingIDs: Set<UUID>
  let actions: DayRowActions

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      header
        // Ein Element für VoiceOver: Stunde, Zeit, Klasse, Fach und die Aussage in Worten.
        .accessibilityElement(children: .combine)
        .contextMenu { lessonMenu }
      Spacer(minLength: 8)
      materials
      if !isCancelled {
        Button("board.title", systemImage: "pencil.and.scribble") {
          actions.openBoard(lesson.lesson.key)
        }
        .buttonStyle(.bordered)
        .frame(minHeight: 44)
      }
    }
    .padding(.vertical, 4)
  }

  // MARK: Kopf

  private var header: some View {
    HStack(alignment: .center, spacing: 16) {
      PeriodHeader(period: lesson.lesson.period, time: lesson.lesson.time)
      VStack(alignment: .leading, spacing: 2) {
        Text(verbatim: "\(lesson.lesson.key.schoolClass.normalized) · \(lesson.lesson.key.subject.display)")
          .font(.title3)
          .strikethrough(isCancelled)
        statusLabel
        info
        // Nur Leistungsnachweise; das geplante Thema zählt im Unterricht nicht, dort gilt das eingetragene.
        if let hint = lesson.planHint {
          PlanHintLabel(markers: hint.markers)
        }
      }
    }
  }

  private var isCancelled: Bool {
    if case .cancelled = lesson.status { return true }
    return false
  }

  /// Ausfall und Vertretung; sonst die Aussage zum Material (ohne Material, nicht verfügbar).
  @ViewBuilder private var statusLabel: some View {
    switch lesson.status {
    case .cancelled:
      StatementLabel(statement: .cancellation).font(.subheadline)
    case .substitute:
      Label("dayView.substitute", systemImage: "arrow.triangle.swap").font(.subheadline)
      materialStatement
    case .regular:
      materialStatement
    }
  }

  @ViewBuilder private var materialStatement: some View {
    if lesson.materials.isEmpty {
      StatementLabel(statement: .lessonWithoutMaterial)
        .font(.subheadline).foregroundStyle(.secondary)
    } else if lesson.materials.contains(where: { liveAvailability($0).isUnavailable }) {
      StatementLabel(statement: .materialUnavailable).font(.subheadline)
    }
  }

  /// Zustand zur Renderzeit aus der Ablage (beobachtet); die Zeile selbst trägt nur den Stand des letzten Lesens.
  private func liveAvailability(_ row: MaterialRow) -> MaterialAvailability? {
    environment.storage.availability[row.item.reference.locationKey] ?? row.availability
  }

  /// Thema, Bereitlegen und Hausaufgabe, wenn nicht leer (FR-13).
  @ViewBuilder private var info: some View {
    if let topic = lesson.info.topic {
      Text("dayView.info.topic \(topic)").lineLimit(1)
    }
    if let toPrepare = lesson.info.toPrepare {
      Text("dayView.info.toPrepare \(toPrepare)").lineLimit(1)
    }
    if let homework = lesson.info.homework {
      Text("dayView.info.homework \(homework)").lineLimit(1)
    }
  }

  // MARK: Material

  /// Material als Knöpfe in Reihenfolge. `ViewThatFits` nimmt die erste Fassung, die in die Breite passt:
  /// alle Namen → gekürzte Namen → erster Name plus Anzahl.
  @ViewBuilder private var materials: some View {
    if !lesson.materials.isEmpty {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 8) { buttons(style: .full) }
        HStack(spacing: 8) { buttons(style: .short) }
        HStack(spacing: 8) {
          if let first = lesson.materials.first {
            MaterialButton(row: first, isOpening: openingIDs.contains(first.id), style: .short, inLesson: true, actions: actions)
          }
          if lesson.materials.count > 1 {
            Text("dayView.materialMore \(lesson.materials.count - 1)")
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private func buttons(style: MaterialButton.Style) -> some View {
    ForEach(lesson.materials) { material in
      MaterialButton(
        row: material, isOpening: openingIDs.contains(material.id), style: style, inLesson: true,
        actions: actions)
    }
  }

  // MARK: Menü

  @ViewBuilder private var lessonMenu: some View {
    switch lesson.status {
    case .cancelled(let origin):
      // Ein Ausfall aus der Stundenplan-Quelle lässt sich nicht von Hand aufheben (FR-8).
      if origin == .manual {
        Button("dayView.uncancel", systemImage: "arrow.uturn.backward") {
          actions.setCancelled(lesson.lesson.key, false)
        }
      }
    case .regular, .substitute:
      Button("dayView.cancel", systemImage: DayStatement.cancellation.symbolName) {
        actions.setCancelled(lesson.lesson.key, true)
      }
    }
    if !lesson.materials.isEmpty {
      Button("dayView.passOn", systemImage: "arrow.right.circle") {
        actions.passOn(lesson.lesson.key)
      }
    }
  }
}

/// Ein Material als Knopf. Zustand immer als Symbol plus Text; beim Laden `ProgressView`.
struct MaterialButton: View {
  enum Style { case full, short }

  /// Die übergebene Zeile ist nur der Stand des letzten Lesens; der Zustand kommt live aus der Ablage.
  let passedRow: MaterialRow
  let isOpening: Bool
  let style: Style
  /// `true`: Teil einer Stunde (Menüpunkt „In die nächste Stunde“); `false`: Material ohne Stunde.
  let inLesson: Bool
  let actions: DayRowActions

  /// Ort des „Öffnen in …“-Menüs: der Knopf selbst (liefert `HandOffAnchorReader`).
  @State private var anchor = HandOffAnchor()
  @Environment(AppEnvironment.self) private var environment

  init(row: MaterialRow, isOpening: Bool, style: Style, inLesson: Bool, actions: DayRowActions) {
    self.passedRow = row
    self.isOpening = isOpening
    self.style = style
    self.inLesson = inLesson
    self.actions = actions
  }

  /// Zeile mit dem Zustand zur Renderzeit: Laden, Fortschritt und Rückkehr der Datei folgen `availability`.
  private var row: MaterialRow {
    MaterialRow(
      item: passedRow.item,
      availability: environment.storage.availability[passedRow.item.reference.locationKey]
        ?? passedRow.availability)
  }

  var body: some View {
    Button {
      actions.open(row, anchor)
    } label: {
      label
        // Zielgröße mindestens 44 pt.
        .frame(minHeight: 44)
    }
    .buttonStyle(.bordered)
    .background(HandOffAnchorReader { resolved, _ in anchor = resolved })
    .contextMenu {
      if inLesson {
        Button("dayView.moveToNext", systemImage: "arrow.right") { actions.moveToNext(row) }
      } else {
        Button("dayView.assign", systemImage: "calendar.badge.plus") { actions.assign(row.item) }
      }
      if row.availability.isUnavailable {
        Button("dayView.relink", systemImage: "link") { actions.relink(row) }
      }
    }
    .accessibilityLabel(Text(verbatim: row.item.reference.displayName))
    .accessibilityValue(accessibilityValue)
  }

  private var label: some View {
    HStack(spacing: 6) {
      stateIcon
      Text(verbatim: row.item.reference.displayName)
        .lineLimit(1)
        .truncationMode(.middle)
        .frame(maxWidth: style == .short ? 140 : nil)
      if isLoading && style == .full {
        Text("dayView.loading").foregroundStyle(.secondary)
      }
    }
  }

  private var isLoading: Bool {
    if isOpening { return true }
    if case .downloading? = row.availability { return true }
    return false
  }

  /// Ladezustand: `open` wartet bis 120 s auf das Herunterladen; mit Fortschritt, wenn das System ihn liefert.
  @ViewBuilder private var stateIcon: some View {
    if case .downloading(let progress)? = row.availability {
      if let progress {
        ProgressView(value: progress).progressViewStyle(.circular)
      } else {
        ProgressView()
      }
    } else if isOpening {
      ProgressView()
    } else if row.availability.isUnavailable {
      Image(systemName: DayStatement.materialUnavailable.symbolName)
    }
  }

  private var accessibilityValue: Text {
    if isOpening { return Text("dayView.loading") }
    switch row.availability {
    case .downloading?: return Text("dayView.loading")
    case .unavailable?: return Text(LocalizedStringKey(DayStatement.materialUnavailable.labelKey))
    default: return Text(verbatim: "")
    }
  }
}

extension Optional where Wrapped == MaterialAvailability {
  /// `nil` (noch nicht gelesen) gilt nicht als nicht verfügbar.
  var isUnavailable: Bool {
    if case .unavailable? = self { return true }
    return false
  }
}
