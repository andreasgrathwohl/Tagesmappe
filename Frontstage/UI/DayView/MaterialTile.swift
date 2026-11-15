import FrontstageCore
import SwiftUI

/// Material-Ziel der Tagesansicht (UI-4, UI-9, UI-10, UI-11): eine Kachel je Material. Oben ggf. die Kapsel
/// „Am Smartboard“, dann der Name im Akzentton (zwei Zeilen, Mitte gekürzt), unten der Dateityp – oder bei
/// nicht verfügbarem Material die Aussage, beim Laden Fortschritt und „Wird geladen …“.
///
/// Swift-Hinweis: Der Zustand der Datei kommt live aus `environment.storage.availability` (`@Observable`);
/// die übergebene Zeile ist nur der Stand des letzten Lesens.
struct MaterialTile: View {
  /// Die übergebene Zeile ist nur der Stand des letzten Lesens; der Zustand kommt live aus der Ablage.
  let passedRow: MaterialRow
  let isOpening: Bool
  let isShown: Bool
  /// `true`: Teil einer Stunde (Menüpunkt „In die nächste Stunde“); `false`: Material ohne Stunde.
  let inLesson: Bool
  let actions: DayRowActions

  /// Ort des „Öffnen in …“-Menüs: die Kachel selbst (liefert `HandOffAnchorReader`).
  @State private var anchor = HandOffAnchor()
  @Environment(AppEnvironment.self) private var environment
  @Environment(\.themeStyle) private var style
  @ScaledMetric(relativeTo: .title3) private var height = DayViewLayout.tileHeight

  init(row: MaterialRow, isOpening: Bool, isShown: Bool, inLesson: Bool, actions: DayRowActions) {
    self.passedRow = row
    self.isOpening = isOpening
    self.isShown = isShown
    self.inLesson = inLesson
    self.actions = actions
  }

  /// Zeile mit dem Zustand zur Renderzeit.
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
      VStack(alignment: .leading, spacing: DayViewLayout.tileSpacing) {
        if isShown {
          SignalCapsule(.onSmartboard).transition(.opacity)
        }
        Text(verbatim: row.item.reference.displayName)
          .scaledFont(.materialName)
          .foregroundStyle(style.accent)
          .lineLimit(2)
          .truncationMode(.middle)
          .multilineTextAlignment(.leading)
        Spacer(minLength: 0)
        footer
      }
      .padding(DayViewLayout.tileSpacing * 2)
      // Mindesthöhe statt fester Höhe: bei großer Dynamic-Type-Stufe wird nichts abgeschnitten.
      .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
      .animation(.snappy(duration: 0.15), value: isShown)
    }
    .buttonStyle(TileButtonStyle())
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
    .accessibilityValue(Text(verbatim: accessibilityValue))
  }

  // MARK: Fuß

  @ViewBuilder private var footer: some View {
    if isLoading {
      HStack(spacing: DayViewLayout.tileSpacing) {
        progress
        Text("dayView.loading")
          .scaledFont(.fileType)
          .foregroundStyle(style.text)
      }
    } else if row.availability.isUnavailable {
      StatementView(.materialUnavailable, scale: .fileType)
    } else {
      Text(verbatim: Self.fileTypeLabel(row.item.reference))
        .scaledFont(.fileType)
        .foregroundStyle(style.accent)
    }
  }

  private var isLoading: Bool {
    if isOpening { return true }
    if case .downloading? = row.availability { return true }
    return false
  }

  /// Fortschritt, wenn das System ihn liefert, sonst unbestimmt.
  @ViewBuilder private var progress: some View {
    if case .downloading(let value?)? = row.availability {
      ProgressView(value: value).progressViewStyle(.circular).controlSize(.small)
    } else {
      ProgressView().controlSize(.small)
    }
  }

  private var accessibilityValue: String {
    var parts: [String] = []
    if isShown { parts.append(String(localized: "dayView.onSmartboard.accessibility")) }
    if isLoading {
      parts.append(String(localized: "dayView.loading"))
    } else if row.availability.isUnavailable {
      parts.append(String(localized: "dayView.statement.materialUnavailable"))
    }
    return parts.joined(separator: ", ")
  }

  /// Dateityp: die Endung des Pfads in Großbuchstaben, ohne Endung „Datei“.
  static func fileTypeLabel(_ reference: MaterialReference) -> String {
    let fileExtension = (reference.relativePath as NSString).pathExtension
    return fileExtension.isEmpty
      ? String(localized: "dayView.fileType.unknown") : fileExtension.uppercased()
  }
}

/// Tafel als Kachel derselben Form (FR-12): Symbol und „Tafel“; steht sie auf dem Zweitbildschirm, trägt sie
/// wie Material die Kapsel „Am Smartboard“.
struct BoardTile: View {
  let key: LessonKey
  let isShown: Bool
  let actions: DayRowActions

  @Environment(\.themeStyle) private var style
  @ScaledMetric(relativeTo: .title3) private var height = DayViewLayout.tileHeight

  init(key: LessonKey, isShown: Bool, actions: DayRowActions) {
    self.key = key
    self.isShown = isShown
    self.actions = actions
  }

  var body: some View {
    Button {
      actions.openBoard(key)
    } label: {
      VStack(alignment: .leading, spacing: DayViewLayout.tileSpacing) {
        if isShown {
          SignalCapsule(.onSmartboard).transition(.opacity)
        }
        HStack(spacing: DayViewLayout.tileSpacing) {
          Image(systemName: "pencil.and.scribble").accessibilityHidden(true)
          Text("board.title")
        }
        .scaledFont(.materialName)
        .foregroundStyle(style.accent)
        Spacer(minLength: 0)
      }
      .padding(DayViewLayout.tileSpacing * 2)
      .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
      .animation(.snappy(duration: 0.15), value: isShown)
    }
    .buttonStyle(TileButtonStyle())
    .accessibilityLabel(Text("board.title"))
    .accessibilityValue(isShown ? Text("dayView.onSmartboard.accessibility") : Text(verbatim: ""))
  }
}
