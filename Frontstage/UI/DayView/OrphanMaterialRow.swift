import SwiftUI

/// Eine Zeile unter „Material ohne Stunde“ (FR-7, UI-4): der Name öffnet das Material, die Kapsel „Zuordnen …“
/// ordnet es einer Stunde zu. Kontextmenü wie bei `MaterialTile`.
struct OrphanMaterialRow: View {
  let passedRow: MaterialRow
  let isOpening: Bool
  let actions: DayRowActions

  @State private var anchor = HandOffAnchor()
  @Environment(AppEnvironment.self) private var environment
  @Environment(\.themeStyle) private var style
  @ScaledMetric(relativeTo: .body) private var minHeight = DayViewLayout.rowHeight

  init(row: MaterialRow, isOpening: Bool, actions: DayRowActions) {
    self.passedRow = row
    self.isOpening = isOpening
    self.actions = actions
  }

  /// Zeile mit dem Zustand zur Renderzeit (wie `MaterialTile`).
  private var row: MaterialRow {
    MaterialRow(
      item: passedRow.item,
      availability: environment.storage.availability[passedRow.item.reference.locationKey]
        ?? passedRow.availability)
  }

  var body: some View {
    HStack(spacing: DayViewLayout.sectionSpacing) {
      Button {
        actions.open(row, anchor)
      } label: {
        HStack(spacing: DayViewLayout.tileSpacing) {
          if isLoading {
            ProgressView().controlSize(.small)
          } else if row.availability.isUnavailable {
            StatementView(.materialUnavailable, scale: .listMeta)
          }
          Text(verbatim: row.item.reference.displayName)
            .scaledFont(.listTitle)
            .foregroundStyle(style.text)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .background(HandOffAnchorReader { resolved, _ in anchor = resolved })
      .contextMenu {
        Button("dayView.assign", systemImage: "calendar.badge.plus") { actions.assign(row.item) }
        if row.availability.isUnavailable {
          Button("dayView.relink", systemImage: "link") { actions.relink(row) }
        }
      }
      .accessibilityLabel(Text(verbatim: row.item.reference.displayName))
      .accessibilityValue(accessibilityValue)

      Button("dayView.assign") { actions.assign(row.item) }
        .buttonStyle(CapsuleActionButtonStyle())
    }
  }

  private var isLoading: Bool {
    if isOpening { return true }
    if case .downloading? = row.availability { return true }
    return false
  }

  private var accessibilityValue: Text {
    if isLoading { return Text("dayView.loading") }
    if row.availability.isUnavailable { return Text("dayView.statement.materialUnavailable") }
    return Text(verbatim: "")
  }
}
