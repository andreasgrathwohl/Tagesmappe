/// Erkennt aus datierten Schulmanager-Stunden die Abweichungen (Ausfall, Vertretung) einer Lehrkraft.
public enum SchulmanagerChangeExtractor {
  private struct Slot: Hashable {
    var schoolClass: SchoolClass
    var subject: Subject
  }

  public static func changes(in lessons: [SchulmanagerLesson], teacherID: String) -> [SourceChange] {
    var result: [SourceChange] = []
    var seen = Set<SourceChange>()
    func add(_ change: SourceChange) {
      if seen.insert(change).inserted { result.append(change) }
    }

    for lesson in lessons {
      guard lesson.type == .cancelledLesson || lesson.type == .changedLesson else { continue }
      let own = slots(of: lesson.originals.filter { $0.teacherIDs.contains(teacherID) })
      let actual: [Slot]
      if let info = lesson.actual, info.teacherIDs.contains(teacherID) {
        actual = slots(of: [info])
      } else {
        actual = []
      }
      // Gleiche Klasse und gleiches Fach bleiben unverändert (nur Raum oder Mitlehrkraft geändert).
      for slot in own where !actual.contains(slot) {
        add(.cancelled(date: lesson.date, period: lesson.period, schoolClass: slot.schoolClass, subject: slot.subject))
      }
      for slot in actual where !own.contains(slot) {
        add(.substitute(date: lesson.date, period: lesson.period, schoolClass: slot.schoolClass, subject: slot.subject))
      }
    }
    return result
  }

  private static func slots(of infos: [SchulmanagerLessonInfo]) -> [Slot] {
    infos.flatMap { info in
      info.classNames.map { Slot(schoolClass: SchoolClass($0), subject: Subject(info.subjectName)) }
    }
  }
}
