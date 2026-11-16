import CoreGraphics
import FrontstageCore
import Observation
import PencilKit

/// Werkzeugmodus des Bildeditors: Zeichnen (Stift) oder Schwärzen (Rechtecke).
enum MarkupMode: Hashable { case draw, redact }

/// Zustand des Bildeditors für Rückmeldungen: Zeichnung (Raum der Bildpixel), Schwärzungen und ein gemeinsamer
/// Rückgängig-Verlauf.
///
/// Der Verlauf hält vollständige Zustände (Zeichnung + Schwärzungen) statt einzelner Operationen. Damit ist
/// „Rückgängig“ chronologisch gleich für Striche, Schwärzungen und „Alles löschen“; die Datenmengen sind klein
/// (ein Bildschirmfoto, wenige Striche).
///
/// Swift-Hinweis: `@Observable` (Observation) ersetzt `ObservableObject`; SwiftUI beobachtet jede gelesene
/// Eigenschaft einzeln. `private(set)` erlaubt Lesen von außen, Schreiben nur über die Methoden hier.
@MainActor @Observable final class MarkupEditorModel {
  private struct Snapshot {
    let drawing: PKDrawing
    let redactions: [NormalizedRect]
  }

  let pixelSize: CGSize
  private(set) var drawing: PKDrawing
  private(set) var redactions: [NormalizedRect]
  var mode: MarkupMode = .draw
  private var history: [Snapshot] = []

  var canUndo: Bool { !history.isEmpty }

  init(pixelSize: CGSize, drawing: PKDrawing, redactions: [NormalizedRect]) {
    self.pixelSize = pixelSize
    self.drawing = drawing
    self.redactions = redactions
  }

  /// Rückmeldung der Zeichenfläche (iPad). Legt nur dann einen Schritt an, wenn sich die Zeichnung ändert.
  func replaceDrawing(_ newDrawing: PKDrawing) {
    guard newDrawing != drawing else { return }
    pushHistory()
    drawing = newDrawing
  }

  /// Ein Strich der Mac-Zeichenfläche.
  func addStroke(_ stroke: PKStroke) {
    pushHistory()
    drawing = PKDrawing(strokes: drawing.strokes + [stroke])
  }

  func addRedaction(_ rect: NormalizedRect) {
    pushHistory()
    redactions.append(rect)
  }

  /// Nimmt den letzten Schritt zurück, gleich ob Strich, Schwärzung oder „Alles löschen“.
  func undo() {
    guard let last = history.popLast() else { return }
    drawing = last.drawing
    redactions = last.redactions
  }

  /// Entfernt Zeichnung und Schwärzungen; als ein Schritt rückgängig zu machen. Ohne Inhalt kein Schritt.
  func clear() {
    guard !drawing.strokes.isEmpty || !redactions.isEmpty else { return }
    pushHistory()
    drawing = PKDrawing()
    redactions = []
  }

  private func pushHistory() {
    history.append(Snapshot(drawing: drawing, redactions: redactions))
  }
}
