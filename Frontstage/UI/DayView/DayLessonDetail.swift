import FrontstageCore
import SwiftUI
import TipKit

/// Was die Ansichten der Tagesansicht auslösen können. Die Ansicht `DayView` besitzt den Zustand
/// (Dialoge, Dateiauswahl) und reicht diese Closures nach unten – Liste und Detail selbst halten keinen.
struct DayRowActions {
  var open: (MaterialRow, HandOffAnchor) -> Void
  var relink: (MaterialRow) -> Void
  var moveToNext: (MaterialRow) -> Void
  var assign: (MaterialLinkItem) -> Void
  var setCancelled: (LessonKey, Bool) -> Void
  var passOn: (LessonKey) -> Void
  /// Öffnet die Tafel der Stunde (Teilplan 07, FR-12).
  var openBoard: (LessonKey) -> Void
  /// Lösung hinzufügen oder ersetzen (FR-6.3).
  var editSolution: (MaterialRow) -> Void
  /// Lösung entfernen (FR-6.3).
  var removeSolution: (MaterialRow) -> Void
}

/// Detail der gewählten Unterrichtsstunde (UI-3, UI-4, UI-5): Titel, Stunde und Uhrzeit, alle Aussagen,
/// Thema, Hinweise, das Material in Reihenfolge als Kacheln, die Tafel und die Aktionen der Stunde als Kapseln.
///
/// Swift-Hinweis: `Namespace.ID` verbindet die Kachel (Quelle) mit dem Betrachter (Ziel) für den Zoom-Übergang
/// (UI-14); den Namespace besitzt `DayView`, weil dort auch der Betrachter erscheint.
struct DayLessonDetail: View {
  let row: LessonRow
  let day: CalendarDay
  let openingIDs: Set<UUID>
  let shownLinkID: UUID?
  let isBoardShown: Bool
  let actions: DayRowActions
  let zoomNamespace: Namespace.ID

  @Environment(AppEnvironment.self) private var environment
  @Environment(\.themeStyle) private var style

  init(
    row: LessonRow, day: CalendarDay, openingIDs: Set<UUID>, shownLinkID: UUID?, isBoardShown: Bool,
    actions: DayRowActions, zoomNamespace: Namespace.ID
  ) {
    self.row = row
    self.day = day
    self.openingIDs = openingIDs
    self.shownLinkID = shownLinkID
    self.isBoardShown = isBoardShown
    self.actions = actions
    self.zoomNamespace = zoomNamespace
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DayViewLayout.sectionSpacing) {
        header
        notes
        tiles
        capsules
      }
      .padding(DayViewLayout.detailPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: Kopf

  private var isCancelled: Bool {
    if case .cancelled = row.status { return true }
    return false
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(verbatim: "\(row.lesson.key.schoolClass.normalized) · \(row.lesson.key.subject.display)")
        .scaledFont(.detailTitle)
        .foregroundStyle(style.text)
        .strikethrough(isCancelled)
        .accessibilityAddTraits(.isHeader)
      periodTime
        .monospacedDigit()
        .scaledFont(.detailMeta)
        .foregroundStyle(style.text)
      ForEach(statements, id: \.self) { statement in
        StatementView(statement, scale: .detailMeta)
      }
    }
  }

  private var periodTime: Text {
    guard let time = row.lesson.time else { return Text("dayView.period \(row.lesson.period)") }
    return Text("dayView.row.periodTime \(row.lesson.period) \(LessonTimeFormat.range(time, on: day))")
  }

  /// Alle zutreffenden Aussagen; der Zustand des Materials kommt live aus der Ablage.
  private var statements: [LessonStatement] {
    row.statements { material in
      environment.storage.availability[material.item.reference.locationKey] ?? material.availability
    }
  }

  // MARK: Angaben

  @ViewBuilder private var notes: some View {
    if let topic = row.info.topic {
      Text(verbatim: topic)
        .scaledFont(.topic)
        .foregroundStyle(style.text)
        .accessibilityLabel(Text("dayView.info.topic \(topic)"))
    }
    VStack(alignment: .leading, spacing: 4) {
      if let toPrepare = row.info.toPrepare {
        Text("dayView.info.toPrepare \(toPrepare)")
      }
      if let homework = row.info.homework {
        Text("dayView.info.homework \(homework)")
      }
      if let hint = row.planHint {
        PlanHintLabel(markers: hint.markers)
      }
    }
    .scaledFont(.detailMeta)
    .foregroundStyle(style.text)
  }

  // MARK: Kacheln

  /// Material in Reihenfolge, danach die Tafel (nicht bei Ausfall).
  @ViewBuilder private var tiles: some View {
    if !row.materials.isEmpty || !isCancelled {
      LazyVGrid(
        columns: [
          GridItem(.adaptive(minimum: DayViewLayout.tileMinWidth), spacing: DayViewLayout.tileSpacing)
        ],
        alignment: .leading, spacing: DayViewLayout.tileSpacing
      ) {
        ForEach(row.materials) { material in
          tile(for: material)
        }
        if !isCancelled {
          BoardTile(key: row.lesson.key, isShown: isBoardShown, actions: actions)
        }
      }
    }
  }

  @ViewBuilder private func tile(for material: MaterialRow) -> some View {
    let view = MaterialTile(
      row: material, isOpening: openingIDs.contains(material.id), isShown: shownLinkID == material.id,
      inLesson: true, actions: actions
    )
    // Nur an der ersten Kachel, sonst stünden mehrere Hinweise übereinander.
    .popoverTip(material.id == row.materials.first?.id ? MaterialTileTip() : nil)
    #if os(iOS)
      view.matchedTransitionSource(id: material.id, in: zoomNamespace)
    #else
      view
    #endif
  }

  // MARK: Aktionen der Stunde

  private var capsules: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: DayViewLayout.tileSpacing) { capsuleButtons }
      VStack(alignment: .leading, spacing: DayViewLayout.tileSpacing) { capsuleButtons }
    }
  }

  @ViewBuilder private var capsuleButtons: some View {
    switch row.status {
    case .cancelled(let origin):
      // Ein Ausfall aus der Stundenplan-Quelle lässt sich nicht von Hand aufheben (FR-8).
      if origin == .manual {
        Button("dayView.uncancel") { actions.setCancelled(row.lesson.key, false) }
          .buttonStyle(CapsuleActionButtonStyle())
      }
    case .regular, .substitute:
      Button("dayView.cancel") { actions.setCancelled(row.lesson.key, true) }
        .buttonStyle(CapsuleActionButtonStyle())
    }
    if !row.materials.isEmpty {
      Button("dayView.passOn") { actions.passOn(row.lesson.key) }
        .buttonStyle(CapsuleActionButtonStyle())
    }
  }
}
