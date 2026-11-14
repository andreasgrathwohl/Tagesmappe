import FrontstageCore
import SwiftUI

/// Tafel hinter der Kaufschranke (FR-13), für die Tagesansicht und „Vorbereiten“. Ohne Kauf zeigt sie das Angebot
/// samt „Fertig“, sonst gäbe es im Vollbild keinen Weg zurück; mit Kauf bringt `BoardScreen` sein eigenes „Fertig“ mit.
struct PaidBoardCover: View {
  let lessonKey: LessonKey
  @Environment(Unlock.self) private var unlock
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    PaidGate(feature: .board) {
      BoardScreen(lessonKey: lessonKey)
    }
    .overlay(alignment: .topTrailing) {
      if !unlock.isUnlocked {
        Button("board.done") { dismiss() }
          .frame(minWidth: 44, minHeight: 44)
          .padding()
      }
    }
  }
}

/// Ziel für die Tafel: die Stunde, deren Tafel geöffnet wird.
///
/// Swift-Hinweis: `.fullScreenCover(item:)` und `.sheet(item:)` verlangen einen `Identifiable`-Wert; `LessonKey`
/// selbst ist es nicht, daher diese Hülle mit dem Speichertext als Kennung.
struct BoardTarget: Identifiable {
  let key: LessonKey
  var id: String { key.storageText }
}

extension View {
  /// Öffnet die Tafel der Stunde in `target`: am iPad als Vollbild, am Mac als Sheet.
  func boardPresentation(_ target: Binding<BoardTarget?>) -> some View {
    #if os(iOS)
      return fullScreenCover(item: target) { target in PaidBoardCover(lessonKey: target.key) }
    #else
      return sheet(item: target) { target in
        PaidBoardCover(lessonKey: target.key).frame(minWidth: 900, minHeight: 620)
      }
    #endif
  }
}
