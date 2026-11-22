import FrontstageCore
import SwiftUI

/// Lösungsspalte neben dem Blatt (FR-6.3, UI-17): Kopfzeile mit Seite, eigenen Pfeilen, „Seiten koppeln“ und
/// „Ausblenden“, darunter die Lösung nur lesend. Erscheint nie auf dem Zweitbildschirm.
struct SolutionPane: View {
  let model: SolutionPaneModel
  /// Seite des Blatts (für „Seiten koppeln“).
  let sheetPage: Int
  /// `nil` = Aufnahmezustand noch unbekannt.
  let isMirrored: Bool?
  /// „Andere Datei wählen …“, wenn die Lösung nicht verfügbar ist.
  let pickOther: () -> Void

  @Environment(SolutionVisibility.self) private var visibility

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  // MARK: Kopfzeile

  private var header: some View {
    HStack(spacing: 12) {
      Text("solution.title").font(.headline)
      Spacer(minLength: 8)
      if model.phase == .ready, model.pageCount > 1, visibility.isVisible(isMirrored: isMirrored) {
        Button("solution.previousPage", systemImage: "chevron.left") { model.goToPage(model.pageIndex - 1) }
          .labelStyle(.iconOnly)
          .disabled(model.pageIndex <= 0)
        Text("solution.pageOfPages \(model.pageIndex + 1) \(model.pageCount)")
          .monospacedDigit()
          .foregroundStyle(.secondary)
        Button("solution.nextPage", systemImage: "chevron.right") { model.goToPage(model.pageIndex + 1) }
          .labelStyle(.iconOnly)
          .disabled(model.pageIndex >= model.pageCount - 1)
        Toggle(
          isOn: Binding(get: { model.isCoupled }, set: { _ in model.toggleCoupling(sheetPage: sheetPage) })
        ) {
          Label("solution.couple", systemImage: "link")
        }
        .toggleStyle(.button)
        .labelStyle(.iconOnly)
      }
      Button("solution.hide", systemImage: "xmark") { visibility.isShownByUser = false }
        .labelStyle(.iconOnly)
    }
    .padding(.horizontal)
    .frame(minHeight: 44)
  }

  // MARK: Inhalt

  @ViewBuilder private var content: some View {
    if isMirrored == nil {
      // Aufnahmezustand noch unbekannt: weder Lösung noch Warnung, bis er feststeht.
      ProgressView()
    } else if !visibility.isVisible(isMirrored: isMirrored) {
      // Ruhige Aussage statt der Lösung (UI-13): Die Klasse sähe sonst das gespiegelte Tablet-Bild.
      ContentUnavailableView {
        Label("solution.mirrored.title", systemImage: "rectangle.on.rectangle.slash")
      } description: {
        Text("solution.mirrored.body")
      } actions: {
        Button("solution.mirrored.showAnyway") { visibility.overrideMirroring = true }
      }
    } else {
      switch model.phase {
      case .loading:
        ProgressView()
      case .unavailable:
        ContentUnavailableView {
          Label("solution.unavailable", systemImage: "doc.questionmark")
        } actions: {
          Button("solution.suggestion.other", action: pickOther)
        }
      case .ready:
        if let data = model.documentData {
          PDFDisplayView(documentData: data, pageIndex: model.pageIndex, drawing: nil, visibleRect: nil)
            .accessibilityLabel(Text(verbatim: model.reference.displayName))
        }
      }
    }
  }
}
