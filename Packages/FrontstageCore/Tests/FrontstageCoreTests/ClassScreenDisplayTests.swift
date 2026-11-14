import Testing
@testable import FrontstageCore

@Suite("ClassScreenDisplay")
struct ClassScreenDisplayTests {
  // Aufbau AK-36: Di 2. Stunde 8b Englisch 8:35–9:20, danach nur ein Ausfall (9c Mathe 5. Stunde)
  private let lessons = [
    CoreFixtures.lesson("8b", "Englisch", period: 2, from: (8, 35), to: (9, 20)),
    CoreFixtures.lesson("9c", "Mathe", period: 5, from: (11, 30), to: (12, 15), cancelled: true),
  ]
  private let info = LessonInfo(
    topic: "Unit 4 – Wortschatz", toPrepare: "Buch, Heft", homework: "Workbook S. 34")

  private func show(_ h: Int, _ m: Int) -> ClassScreenDisplay {
    ClassScreenDisplayBuilder.display(
      phase: ClassScreenCalculator.phase(now: TimeOfDay(hour: h, minute: m), lessons: lessons),
      info: info, workMode: nil)
  }

  @Test("AK-36: 8:31 zeigt „Gleich: 8b Englisch“ und Bereitlegen, ohne Countdown und ohne Ende")
  func upcomingShowsNextLessonAndToPrepare() {
    let d = show(8, 31)
    #expect(d.kind == .upcoming)
    #expect(d.schoolClass == "8b")
    #expect(d.subject == "Englisch")
    #expect(d.toPrepare == "Buch, Heft")
    #expect(d.endTime == nil)
    #expect(d.topic == nil)
    #expect(d.homework == nil)
  }

  @Test("AK-36/AK-42: 8:40 zeigt Klasse, Fach, Thema, Bereitlegen und „bis 9:20“")
  func inLessonShowsTopicToPrepareAndEnd() {
    let d = show(8, 40)
    #expect(d.kind == .inLesson)
    #expect(d.endTime == TimeOfDay(hour: 9, minute: 20))
    #expect(d.topic == "Unit 4 – Wortschatz")
    #expect(d.toPrepare == "Buch, Heft")
    #expect(d.homework == nil)
  }

  @Test("AK-36: 9:16 zeigt die Hausaufgabe groß")
  func finalMinutesShowsHomework() {
    let d = show(9, 16)
    #expect(d.kind == .finalMinutes)
    #expect(d.homework == "Workbook S. 34")
    #expect(d.topic == nil)
  }

  @Test("AK-36: 9:30 nur Uhrzeit und Datum – der Ausfall zählt nicht")
  func afterLastLessonShowsClockOnly() {
    let d = show(9, 30)
    #expect(d.kind == .clockOnly)
    #expect(d.schoolClass == nil)
    #expect(d.subject == nil)
    #expect(d.workMode == nil)
  }

  @Test("AK-25: leeres Bereitlegen erzeugt keine Zeile")
  func emptyFieldsAreNil() {
    let phase = ClassScreenCalculator.phase(now: TimeOfDay(hour: 8, minute: 40), lessons: lessons)
    let d = ClassScreenDisplayBuilder.display(
      phase: phase,
      info: LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: "  ", homework: nil), workMode: nil)
    #expect(d.topic == "Unit 4 – Wortschatz")
    #expect(d.toPrepare == nil)
  }

  @Test("Review Focus 2: letzte fünf Minuten ohne Hausaufgabe zeigen den Inhalt der Stunde")
  func finalMinutesWithoutHomeworkFallsBackToLessonContent() {
    let phase = ClassScreenCalculator.phase(now: TimeOfDay(hour: 9, minute: 16), lessons: lessons)
    let d = ClassScreenDisplayBuilder.display(
      phase: phase,
      info: LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: "Buch, Heft", homework: ""),
      workMode: nil)
    #expect(d.kind == .finalMinutes)
    #expect(d.homework == nil)
    #expect(d.topic == "Unit 4 – Wortschatz")
    #expect(d.toPrepare == "Buch, Heft")
  }

  @Test("AK-24: nur Daten der laufenden Unterrichtsstunde – keine andere Klasse")
  func showsOnlyRunningLesson() {
    let two = [
      CoreFixtures.lesson("8b", "Englisch", period: 2, from: (8, 35), to: (9, 20)),
      CoreFixtures.lesson("9c", "Mathe", period: 3, from: (9, 25), to: (10, 10)),
    ]
    let d = ClassScreenDisplayBuilder.display(
      phase: ClassScreenCalculator.phase(now: TimeOfDay(hour: 8, minute: 40), lessons: two),
      info: nil, workMode: nil)
    let texts = [d.schoolClass, d.subject, d.topic, d.toPrepare, d.homework].compactMap { $0 }
    #expect(texts == ["8b", "Englisch"])
  }

  @Test("AK-27: Partnerarbeit wird gezeigt, ohne Auswahl keine")
  func workModeIsPassedThrough() {
    let phase = ClassScreenCalculator.phase(now: TimeOfDay(hour: 8, minute: 40), lessons: lessons)
    #expect(ClassScreenDisplayBuilder.display(phase: phase, info: nil, workMode: .pairs).workMode == .pairs)
    #expect(ClassScreenDisplayBuilder.display(phase: phase, info: nil, workMode: nil).workMode == nil)
  }
}
