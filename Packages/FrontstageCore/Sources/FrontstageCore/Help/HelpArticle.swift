import Foundation

/// Ein Hilfeartikel, fertig zerlegt.
public struct HelpArticle: Hashable, Sendable, Identifiable {
  public let topic: HelpTopic
  public let title: String
  public let summary: String
  public let keywords: [String]
  public let blocks: [HelpBlock]
  public var id: HelpTopic { topic }

  public init(topic: HelpTopic, title: String, summary: String, keywords: [String], blocks: [HelpBlock]) {
    self.topic = topic
    self.title = title
    self.summary = summary
    self.keywords = keywords
    self.blocks = blocks
  }
}
