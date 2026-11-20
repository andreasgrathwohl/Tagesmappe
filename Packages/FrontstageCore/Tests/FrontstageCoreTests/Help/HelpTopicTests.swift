import Testing
@testable import FrontstageCore

@Suite("Help Topics")
struct HelpTopicTests {
  @Test("21 Themen, Rohwerte englisch (FR-17)")
  func allTopics() {
    #expect(HelpTopic.allCases.count == 21)
    #expect(HelpTopic.dataLocation.rawValue == "dataLocation")
  }

  @Test("Jedes angezeigte Thema in genau einer Gruppe, Gruppen decken alle angezeigten ab (FR-17)")
  func groupsPartitionTopics() {
    let grouped = HelpGroup.allCases.flatMap(\.topics).sorted { $0.rawValue < $1.rawValue }
    #expect(grouped == HelpTopic.availableCases.sorted { $0.rawValue < $1.rawValue })
  }

  @Test("Schulmanager-Thema folgt der abgeschalteten Quelle (ADR-0016)")
  func schulmanagerTopicHidden() {
    #expect(!HelpTopic.schulmanager.isAvailable)
    #expect(!HelpTopic.availableCases.contains(.schulmanager))
    #expect(!HelpGroup.setup.topics.contains(.schulmanager))
    #expect(HelpTopic.timetable.related == [.bellSchedule, .nonTeachingDays])
    #expect(HelpTopic.availableCases.count == 20)
  }

  @Test("Gruppen folgen der festgelegten Zuordnung (FR-17)")
  func groupAssignment() {
    #expect(HelpGroup.start.topics == [.gettingStarted])
    #expect(HelpGroup.teaching.topics == [.dayView, .openingMaterial, .penNotes])
    #expect(HelpGroup.about.topics == [.purchase, .privacy, .feedback])
    #expect(HelpGroup.setup.topics.count == 8)
  }

  @Test("Verwandte Themen: 1–3, nie das Thema selbst, ohne Doppelte (FR-17.1)")
  func relatedIsSane() {
    for topic in HelpTopic.allCases {
      #expect((1...3).contains(topic.relatedTable.count), "\(topic)")
      let related = topic.related
      #expect((1...3).contains(related.count), "\(topic)")
      let allAvailable = related.allSatisfy { $0.isAvailable }
      #expect(allAvailable, "\(topic)")
      #expect(!related.contains(topic), "\(topic)")
      #expect(Set(related).count == related.count, "\(topic)")
    }
  }

  @Test("Textschlüssel (FR-17)")
  func textKeyPrefix() {
    #expect(HelpTopic.board.textKeyPrefix == "help.board")
  }
}
