import FrontstageCore
import SwiftUI

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

/// Bildeditor der Rückmeldung: Zeichnen und Schwärzen auf einem Bildschirmfoto.
///
/// Zeichenfläche und `RedactionOverlay` liegen in exakt gleicher Größe über dem Bild. Im Modus Schwärzen nimmt
/// nur das Overlay Gesten an, im Modus Zeichnen nur die Zeichenfläche.
struct MarkupEditorView: View {
  let imageData: Data
  let model: MarkupEditorModel
  let onDone: (MarkupEditorModel) -> Void

  @State private var confirmClear = false
  #if os(macOS)
    @State private var macTool: MacMarkupTool = .pen
  #endif

  init(imageData: Data, model: MarkupEditorModel, onDone: @escaping (MarkupEditorModel) -> Void) {
    self.imageData = imageData
    self.model = model
    self.onDone = onDone
  }

  var body: some View {
    VStack(spacing: 12) {
      bar
      imageArea
      Text("feedback.markup.redactHint")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
    .navigationTitle(Text("feedback.markup.title"))
    .confirmationDialog(
      Text("feedback.markup.clear.confirm"), isPresented: $confirmClear, titleVisibility: .visible
    ) {
      Button("feedback.markup.clear", role: .destructive) { model.clear() }
    }
  }

  // MARK: Leiste

  private var bar: some View {
    @Bindable var model = model
    return HStack(spacing: 16) {
      Picker("feedback.markup.title", selection: $model.mode) {
        Text("feedback.markup.draw").tag(MarkupMode.draw)
        Text("feedback.markup.redact").tag(MarkupMode.redact)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(maxWidth: 280)

      #if os(macOS)
        if model.mode == .draw {
          Picker("feedback.markup.pen", selection: $macTool) {
            Text("feedback.markup.pen").tag(MacMarkupTool.pen)
            Text("feedback.markup.marker").tag(MacMarkupTool.marker)
          }
          .pickerStyle(.segmented)
          .frame(maxWidth: 200)
        }
      #endif

      Spacer()

      Button {
        model.undo()
      } label: {
        Label("feedback.markup.undo", systemImage: "arrow.uturn.backward")
      }
      .disabled(!model.canUndo)

      Button(role: .destructive) {
        confirmClear = true
      } label: {
        Text("feedback.markup.clear")
      }
      .disabled(!model.canUndo)

      Button {
        onDone(model)
      } label: {
        Text("feedback.markup.done")
      }
      .buttonStyle(.borderedProminent)
    }
  }

  // MARK: Bild

  private var imageArea: some View {
    platformImage
      .resizable()
      .aspectRatio(contentMode: .fit)
      .overlay {
        ZStack {
          drawingSurface
          RedactionOverlay(
            redactions: model.redactions, isActive: model.mode == .redact,
            onAdd: { model.addRedaction($0) })
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text("feedback.markup.image"))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder private var drawingSurface: some View {
    #if os(iOS)
      MarkupCanvas(model: model)
    #else
      MacMarkupCanvas(model: model, tool: macTool)
    #endif
  }

  private var platformImage: Image {
    #if os(iOS)
      Image(uiImage: UIImage(data: imageData) ?? UIImage())
    #else
      Image(nsImage: NSImage(data: imageData) ?? NSImage())
    #endif
  }
}
