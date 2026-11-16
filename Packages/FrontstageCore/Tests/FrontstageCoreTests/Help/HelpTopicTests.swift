import Testing
@testable import FrontstageCore

@Suite("Help Topics")
struct HelpTopicTests {
  @Test("21 Themen, Rohwerte englisch (FR-17)")
  func allTopics() {
    #expect(HelpTopic.allCases.count == 21)
    #expect(HelpTopic.dataLocation.rawValue == "dataLocation")
  }

  @Test("Jedes Thema in genau einer Gruppe, Gruppen decken alles ab (FR-17)")
  func groupsPartitionTopics() {
    let grouped = HelpGroup.allCases.flatMap(\.topics).sorted { $0.rawValue < $1.rawValue }
    #expect(grouped == HelpTopic.allCases.sorted { $0.rawValue < $1.rawValue })
  }

  @Test("Gruppen folgen der festgelegten Zuordnung (FR-17)")
  func groupAssignment() {
    #expect(HelpGroup.start.topics == [.gettingStarted])
    #expect(HelpGroup.teaching.topics == [.dayView, .openingMaterial, .penNotes])
    #expect(HelpGroup.about.topics == [.purchase, .privacy, .feedback])
    #expect(HelpGroup.setup.topics.count == 9)
  }

  @Test("Verwandte Themen: 1–3, nie das Thema selbst, ohne Doppelte (FR-17.1)")
  func relatedIsSane() {
    for topic in HelpTopic.allCases {
      let related = topic.related
      #expect((1...3).contains(related.count), "\(topic)")
      #expect(!related.contains(topic), "\(topic)")
      #expect(Set(related).count == related.count, "\(topic)")
    }
  }

  @Test("Textschlüssel (FR-17)")
  func textKeyPrefix() {
    #expect(HelpTopic.board.textKeyPrefix == "help.board")
  }
}
