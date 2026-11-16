import FrontstageCore
import SwiftUI

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

/// Vorschaubilder der Bildschirmfotos einer Rückmeldung. Tippen öffnet den Bildeditor; „Entfernen“ steht im
/// Kontextmenü und als VoiceOver-Aktion.
struct AttachmentStrip: View {
  let model: FeedbackModel
  let onEdit: (FeedbackAttachment) -> Void

  /// Höhe und Ecken wie die Kacheln der Tagesansicht (UI-10).
  private let height = DayViewLayout.tileHeight
  private let radius = DayViewLayout.tileRadius

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: DayViewLayout.tileSpacing) {
        ForEach(Array(model.draft.attachments.enumerated()), id: \.element.id) { index, attachment in
          thumbnail(attachment, number: index + 1)
        }
      }
    }
  }

  private func thumbnail(_ attachment: FeedbackAttachment, number: Int) -> some View {
    Button {
      onEdit(attachment)
    } label: {
      AttachmentThumbnail(model: model, attachment: attachment, height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(alignment: .topTrailing) {
          if attachment.hasMarkup || !attachment.redactions.isEmpty {
            Image(systemName: "pencil.circle.fill")
              .symbolRenderingMode(.palette)
              .foregroundStyle(.white, .tint)
              .padding(6)
              .accessibilityHidden(true)
          }
        }
    }
    .buttonStyle(.plain)
    .contextMenu {
      Button(role: .destructive) {
        model.removeAttachment(attachment.id)
      } label: {
        Text("feedback.attachments.remove")
      }
    }
    .accessibilityLabel(label(attachment, number: number))
    .accessibilityAction(named: Text("feedback.attachments.remove")) {
      model.removeAttachment(attachment.id)
    }
  }

  private func label(_ attachment: FeedbackAttachment, number: Int) -> Text {
    let marked = attachment.hasMarkup || !attachment.redactions.isEmpty
    return marked
      ? Text("feedback.attachments.labelMarked \(number)") : Text("feedback.attachments.label \(number)")
  }
}

/// Lädt das Bild einmal je Anhang und je Bearbeitungsstand, nicht bei jedem Zeichnen der Ansicht.
private struct AttachmentThumbnail: View {
  let model: FeedbackModel
  let attachment: FeedbackAttachment
  let height: CGFloat

  @State private var image: Image?

  var body: some View {
    Group {
      if let image {
        image.resizable().aspectRatio(contentMode: .fit)
      } else {
        Rectangle().fill(.quaternary)
          .aspectRatio(CGFloat(attachment.pixelWidth) / CGFloat(max(1, attachment.pixelHeight)), contentMode: .fit)
      }
    }
    .frame(height: height)
    // Geschwärzte Bereiche und Zeichnung sind nur in der Vorschau des Editors sichtbar; die Kachel zeigt das
    // Original, markiert aber „bearbeitet“.
    .task(id: attachment.id) {
      guard let data = model.imageData(for: attachment.id) else { return }
      #if os(iOS)
        if let ui = UIImage(data: data) { image = Image(uiImage: ui) }
      #else
        if let ns = NSImage(data: data) { image = Image(nsImage: ns) }
      #endif
    }
  }
}
