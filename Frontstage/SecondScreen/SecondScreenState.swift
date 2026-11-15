import Foundation
import FrontstageCore
import Observation
import PencilKit

/// Das Material, das der Zweitbildschirm gerade zeigt. Flüchtig; die Notizen gehören dem Betrachter
/// und werden von dort per `SecondScreenState.updateDrawing(_:pageIndex:)` nachgeführt.
struct MaterialPresentation: Equatable {
  /// Verknüpfung des Materials mit der Stunde.
  let linkID: UUID
  /// Dateiinhalt des Dokuments (PDF oder Bild).
  let documentData: Data
  let kind: MaterialFileKind
  /// Gezeigte Seite, ab 0.
  var pageIndex: Int
  /// Sichtbarer Ausschnitt in **PDFKit-Seitenkoordinaten** (ungedrehte `mediaBox`, Ursprung unten links),
  /// `nil` = ganze Seite. Anders als die Notizen nicht in Seitenkoordinaten (oben links, Drehung angewandt):
  /// Erzeuger (`PDFCanvasView`) und Abnehmer (`PDFDisplayView`, `PDFView.go(to:on:)`) arbeiten beide in PDFKit.
  var visibleRect: CGRect?
  /// Stiftnotizen je Seite, in Seitenkoordinaten.
  var drawings: [Int: PKDrawing]
}

/// Gemeinsamer, flüchtiger Zustand beider Szenen (Hauptfenster und Zweitbildschirm).
///
/// `@Observable` (Framework Observation) macht jede gespeicherte Eigenschaft beobachtbar: Liest eine
/// SwiftUI-Ansicht sie im `body`, wird sie bei Änderung neu gezeichnet – in beiden Szenen, weil beide
/// dasselbe Objekt (`shared`) halten. `@MainActor` stellt unter Swift 6 sicher, dass nur der
/// Haupt-Thread es ändert. Der Zustand hält keinen `DataStore`.
@MainActor @Observable final class SecondScreenState {
  /// App-weite Instanz, die beide Szenen halten.
  static let shared = SecondScreenState()

  /// Welcher Inhalt gezeigt wird und welche wählbar sind (reine Logik im Kern-Paket).
  private(set) var state = SecondScreenSelection()
  /// Ein externer Bildschirm ist verbunden.
  private(set) var isConnected = false
  /// Bildformat (Breite/Höhe) des verbundenen Bildschirms, Vorgabe 16:9.
  private(set) var screenAspectRatio: Double = 16.0 / 9.0
  /// Das gezeigte Material, solange eines geöffnet ist.
  private(set) var material: MaterialPresentation?
  /// Stunde, deren Tafel gezeigt werden kann; `nil` = keine Tafel verfügbar.
  private(set) var boardLessonKey: LessonKey?

  init() {}

  /// Aktuell gezeigter Inhalt.
  var content: SecondScreenContent { state.mode }

  /// Zuordnung, die gerade am verbundenen Zweitbildschirm steht (UI-12); sonst `nil`.
  var shownMaterialLinkID: UUID? {
    isConnected && content == .material ? material?.linkID : nil
  }

  /// Die Tafel steht gerade am verbundenen Zweitbildschirm (UI-12).
  var isBoardShown: Bool { isConnected && content == .board }

  /// Wählt einen Inhalt; nicht verfügbare Inhalte werden ignoriert.
  func select(_ mode: SecondScreenContent) {
    state.select(mode)
  }

  /// „Dunkel“ ein- oder ausschalten (FR-11.4).
  func toggleDark() {
    state.toggleDark()
  }

  /// Ein Material wird gezeigt.
  func openMaterial(_ presentation: MaterialPresentation) {
    material = presentation
    state.materialOpened()
  }

  /// Das Material wird geschlossen; der Bildschirm zeigt wieder den Klassenbildschirm (AK-23).
  func closeMaterial() {
    material = nil
    state.materialClosed()
  }

  /// Seitenwechsel oder Zoom des Betrachters; `visibleRect` in PDFKit-Seitenkoordinaten (siehe
  /// `MaterialPresentation.visibleRect`). Ohne offenes Material wirkungslos.
  func showPage(_ pageIndex: Int, visibleRect: CGRect?) {
    guard material != nil else { return }
    material?.pageIndex = pageIndex
    material?.visibleRect = visibleRect
  }

  /// Notiz einer Seite nachführen (Seitenkoordinaten); ohne offenes Material wirkungslos.
  func updateDrawing(_ drawing: PKDrawing, pageIndex: Int) {
    guard material != nil else { return }
    material?.drawings[pageIndex] = drawing
  }

  /// Die Stunde, deren Tafel gezeigt werden kann (Teilplan 07); `nil` nimmt die Tafel weg.
  func setBoardLesson(_ key: LessonKey?) {
    boardLessonKey = key
    state.setBoardAvailable(key != nil)
  }

  /// Verfügbarkeit der Tafel direkt setzen (Teilplan 07).
  func setBoardAvailable(_ available: Bool) {
    state.setBoardAvailable(available)
  }

  /// Ein Bildschirm wurde verbunden. Der aktuelle Inhalt bleibt, nur „Dunkel“ wird aufgehoben (AK-35).
  /// Ein Bildformat ≤ 0 oder nicht endlich wird ignoriert.
  func displayConnected(aspectRatio: Double) {
    isConnected = true
    if aspectRatio.isFinite, aspectRatio > 0 { screenAspectRatio = aspectRatio }
    state.displayConnected()
  }

  /// Nur das Bildformat aktualisieren (Drehung, Auflösung). Hebt „Dunkel“ nicht auf und ändert `isConnected` nicht.
  func updateAspectRatio(_ aspectRatio: Double) {
    if aspectRatio.isFinite, aspectRatio > 0 { screenAspectRatio = aspectRatio }
  }

  /// Der Bildschirm wurde getrennt; Zustand und Zeichnungen bleiben für das Wiederverbinden erhalten.
  func displayDisconnected() {
    isConnected = false
  }
}
