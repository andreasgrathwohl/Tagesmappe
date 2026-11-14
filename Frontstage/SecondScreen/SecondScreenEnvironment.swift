import SwiftUI

extension View {
  /// Eine Stelle für die Umgebung beider Szenen; Modelle von Teilplan 07 kommen über classroomEnvironment().
  ///
  /// Swift-Hinweis: Jede Szene hat eine eigene SwiftUI-Umgebung; was am Hauptfenster hängt, gilt nicht
  /// im Zweitbildschirm.
  func secondScreenEnvironment() -> some View {
    environment(SecondScreenState.shared).classroomEnvironment()
  }
}
