import FrontstageCore
import SwiftUI

/// Ein Hilfeartikel. Ohne eigenen `NavigationStack`; Verwandte Themen sind `NavigationLink(value:)` und
/// brauchen ein `navigationDestination(for: HelpTopic.self)` im umgebenden Stack (`HelpSheet`, Einrichten).
struct HelpArticleView: View {
  let article: HelpArticle
  /// Nur im Hilfeblatt, und nur beim ersten Artikel – dort führt der Link ins Hilfecenter.
  let showsAllTopicsLink: Bool
  let onFeedback: (HelpTopic) -> Void

  @Environment(\.themeStyle) private var style

  init(
    article: HelpArticle, showsAllTopicsLink: Bool = false,
    onFeedback: @escaping (HelpTopic) -> Void
  ) {
    self.article = article
    self.showsAllTopicsLink = showsAllTopicsLink
    self.onFeedback = onFeedback
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text(article.summary)
          .scaledFont(.topic)
        ForEach(article.blocks.indices, id: \.self) { index in
          HelpBlockView(block: article.blocks[index])
        }
        related
        footer
      }
      .foregroundStyle(style.text)
      .frame(maxWidth: 640, alignment: .leading)
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .themedBackground()
    .fontDesign(.rounded)
    .navigationTitle(article.title)
  }

  @ViewBuilder private var related: some View {
    if !article.topic.related.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text("help.related")
          .scaledFont(.topic)
          .accessibilityAddTraits(.isHeader)
        ForEach(article.topic.related, id: \.self) { topic in
          NavigationLink(value: topic) {
            Text(HelpRelatedTitle.title(for: topic))
              .foregroundStyle(style.accent)
              .frame(minHeight: 44, alignment: .leading)
          }
        }
      }
    }
  }

  private var footer: some View {
    VStack(alignment: .leading, spacing: 12) {
      Button("help.giveFeedback") { onFeedback(article.topic) }
        .buttonStyle(CapsuleActionButtonStyle())
      if showsAllTopicsLink {
        NavigationLink(value: HelpSheetRoot.center) {
          Text("help.allTopics")
            .foregroundStyle(style.accent)
            .frame(minHeight: 44, alignment: .leading)
        }
      }
    }
  }
}

/// Titel eines Themas aus der Tabelle – die Verwandtenliste kennt nur `HelpTopic`, nicht den Artikel.
enum HelpRelatedTitle {
  @MainActor static func title(for topic: HelpTopic) -> String {
    HelpLibrary.shared.article(for: topic)?.title ?? topic.rawValue
  }
}
