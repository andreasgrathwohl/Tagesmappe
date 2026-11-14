import FrontstageCore
import SwiftUI

/// Klassenbildschirm des Zweitbildschirms (FR-11). Ohne Kauf zeigt er nur die neutrale Fläche (FR-13).
struct ClassScreenView: View {
  @Environment(Unlock.self) private var unlock
  @Environment(DataStore.self) private var store: DataStore?
  @Environment(LessonSessionState.self) private var session

  var body: some View {
    switch SecondScreenRendering.resolve(.classScreen, isUnlocked: unlock.isUnlocked) {
    case .classScreen:
      if let store {
        ClassScreenLiveView(store: store, session: session)
      } else {
        SystemBackground()
      }
    default:
      SystemBackground()
    }
  }
}

/// Merkt sich die Stunden des Tages, solange Store, Tag, Minute und `revision` gleich bleiben (AK-25).
/// Der Store gehört zum Schlüssel: Nach einem Wechsel des Datenorts kann `revision` zufällig gleich sein.
///
/// Swift-Hinweis: Eine Klasse ohne `@Observable` darf im `body` Werte ablegen, ohne einen neuen
/// Zeichendurchlauf auszulösen; bei einem `@State`-Wert wäre das verboten (Zustand ändern während des
/// Zeichnens).
@MainActor private final class LessonsCache {
  private var key: [Int]?
  private var storeID: ObjectIdentifier?
  private var lessons: [Lesson] = []

  func lessons(store: DataStore, day: CalendarDay, minute: Int) -> [Lesson] {
    let current = [day.year, day.month, day.day, minute, store.revision]
    let currentStore = ObjectIdentifier(store)
    if key != current || storeID != currentStore {
      lessons = (try? store.lessons(on: day)) ?? []
      key = current
      storeID = currentStore
    }
    return lessons
  }
}

private struct ClassScreenLiveView: View {
  let store: DataStore
  let session: LessonSessionState
  @State private var cache = LessonsCache()

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      content(at: context.date)
    }
  }

  private func content(at date: Date) -> some View {
    let calendar = Calendar.current
    let time = TimeOfDay(date, calendar: calendar)
    let lessons = cache.lessons(
      store: store, day: CalendarDay(date, calendar: calendar), minute: time.minutesSinceMidnight)
    let phase = ClassScreenCalculator.phase(now: time, lessons: lessons)
    let lesson = Self.lesson(in: phase)
    let info = lesson.flatMap { try? store.lessonInfo(for: $0.key) }
    // Die Arbeitsform gilt nur für die Stunde, für die sie gewählt wurde. Gemeldet wird die Stunde auch von
    // `ClassroomControls` (Minutentakt), damit das nicht davon abhängt, was der Zweitbildschirm zeigt.
    let reportedKey = phase.runningLessonKey
    let workMode = reportedKey != nil && session.lessonKey == reportedKey ? session.workMode : nil
    let display = ClassScreenDisplayBuilder.display(phase: phase, info: info, workMode: workMode)
    return ClassScreenContentView(display: display, now: date)
      .onChange(of: reportedKey, initial: true) { _, newKey in
        // Nur eine laufende Stunde zählt als „aktuell“, nicht die nächste.
        session.lessonDidChange(to: newKey)
      }
  }

  private static func lesson(in phase: ClassScreenPhase) -> Lesson? {
    switch phase {
    case .upcoming(let lesson), .inLesson(let lesson), .finalMinutes(let lesson): lesson
    case .noMoreLessons: nil
    }
  }
}

/// Neutrale Fläche in der Hintergrundfarbe des Systems (iOS und macOS).
///
/// Swift-Hinweis: Eine `Color` ist für VoiceOver unsichtbar; `.accessibilityElement()` macht sie zu einem Element,
/// damit die Fläche als „Kein Inhalt“ angesagt wird statt gar nicht.
struct SystemBackground: View {
  var body: some View {
    Self.color
      .accessibilityElement()
      .accessibilityLabel(Text("secondScreen.neutral.accessibility"))
  }

  /// Nur die Farbe, ohne Ansage – als Hintergrund hinter echtem Inhalt.
  static var color: Color {
    #if os(iOS)
      return Color(uiColor: .systemBackground)
    #else
      return Color(nsColor: .windowBackgroundColor)
    #endif
  }
}
