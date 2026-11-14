import Foundation

/// Das, was der Klassenbildschirm zeigt: ausschließlich Angaben der einen Unterrichtsstunde,
/// nie Stundenlisten, Zuordnungen oder Dateinamen (FR-11, FR-11.1).
public struct ClassScreenDisplay: Hashable, Sendable {
  /// Form der Anzeige.
  public enum Kind: Hashable, Sendable {
    /// Die nächste Stunde beginnt gleich.
    case upcoming
    /// Die Stunde läuft.
    case inLesson
    /// Die Stunde läuft und endet in wenigen Minuten; die Hausaufgabe steht im Vordergrund.
    case finalMinutes
    /// Keine Stunde: nur Uhrzeit und Datum.
    case clockOnly
  }

  public let kind: Kind
  public let schoolClass: String?
  public let subject: String?
  /// Nur bei `inLesson` und `finalMinutes`.
  public let endTime: TimeOfDay?
  public let topic: String?
  public let toPrepare: String?
  /// Nur bei `finalMinutes`, dann groß dargestellt.
  public let homework: String?
  /// Arbeitsform (FR-11.7); nie bei `clockOnly`.
  public let workMode: WorkMode?

  public init(
    kind: Kind, schoolClass: String?, subject: String?, endTime: TimeOfDay?, topic: String?,
    toPrepare: String?, homework: String?, workMode: WorkMode?
  ) {
    self.kind = kind
    self.schoolClass = schoolClass
    self.subject = subject
    self.endTime = endTime
    self.topic = topic
    self.toPrepare = toPrepare
    self.homework = homework
    self.workMode = workMode
  }
}

/// Bildet aus Phase und Stundenangaben die Anzeige des Klassenbildschirms (FR-11, FR-11.1, FR-11.3, FR-11.7).
public enum ClassScreenDisplayBuilder {
  /// - Parameters:
  ///   - phase: Phase aus `ClassScreenCalculator`.
  ///   - info: Stundenangaben der Phasen-Stunde; leere Felder ergeben keine Zeile.
  ///   - workMode: Gewählte Arbeitsform; entfällt bei `clockOnly`.
  public static func display(
    phase: ClassScreenPhase, info: LessonInfo?, workMode: WorkMode?
  ) -> ClassScreenDisplay {
    let topic = clean(info?.topic)
    let toPrepare = clean(info?.toPrepare)
    let homework = clean(info?.homework)

    switch phase {
    case .noMoreLessons:
      return ClassScreenDisplay(
        kind: .clockOnly, schoolClass: nil, subject: nil, endTime: nil, topic: nil,
        toPrepare: nil, homework: nil, workMode: nil)
    case .upcoming(let lesson):
      // Gleich: nur Bereitlegen, ohne Ende und ohne Thema.
      return make(.upcoming, lesson, endTime: nil, topic: nil, toPrepare: toPrepare, homework: nil, workMode)
    case .inLesson(let lesson):
      return make(
        .inLesson, lesson, endTime: lesson.time?.upperBound, topic: topic, toPrepare: toPrepare,
        homework: nil, workMode)
    case .finalMinutes(let lesson):
      // Ohne Hausaufgabe bleibt der Inhalt der Stunde sichtbar.
      let hasHomework = homework != nil
      return make(
        .finalMinutes, lesson, endTime: lesson.time?.upperBound,
        topic: hasHomework ? nil : topic, toPrepare: hasHomework ? nil : toPrepare,
        homework: homework, workMode)
    }
  }

  private static func make(
    _ kind: ClassScreenDisplay.Kind, _ lesson: Lesson, endTime: TimeOfDay?, topic: String?,
    toPrepare: String?, homework: String?, _ workMode: WorkMode?
  ) -> ClassScreenDisplay {
    ClassScreenDisplay(
      kind: kind, schoolClass: lesson.key.schoolClass.normalized,
      subject: lesson.key.subject.display, endTime: endTime, topic: topic, toPrepare: toPrepare,
      homework: homework, workMode: workMode)
  }

  private static func clean(_ text: String?) -> String? {
    guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty
    else { return nil }
    return trimmed
  }
}
