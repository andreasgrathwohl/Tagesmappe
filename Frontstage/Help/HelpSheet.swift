import FrontstageCore
import SwiftUI

/// Womit das Hilfeblatt beginnt.
enum HelpSheetRoot: Hashable {
  case center
  case article(HelpTopic)
}

/// Hilfeblatt: eigener `NavigationStack`, Artikel und Hilfecenter als Ziele.
/// `onFeedback`: Artikel → (`.issue`, gezeigtes Thema); Center → (gewählte Art, `nil`).
struct HelpSheet: View {
  let root: HelpSheetRoot
  let onFeedback: (FeedbackKind, HelpTopic?) -> Void

  @Environment(\.dismiss) private var dismiss

  init(root: HelpSheetRoot, onFeedback: @escaping (FeedbackKind, HelpTopic?) -> Void) {
    self.root = root
    self.onFeedback = onFeedback
  }

  var body: some View {
    NavigationStack {
      rootContent
        .navigationDestination(for: HelpTopic.self) { topic in
          article(topic, isRoot: false).toolbar { doneItem }
        }
        .navigationDestination(for: HelpSheetRoot.self) { _ in
          // Nur `.center` wird gepusht (Link „Alle Hilfethemen“).
          center.toolbar { doneItem }
        }
        .toolbar { doneItem }
    }
  }

  @ViewBuilder private var rootContent: some View {
    switch root {
    case .center: center
    case .article(let topic): article(topic, isRoot: true)
    }
  }

  private var center: some View {
    HelpCenterView { kind in onFeedback(kind, nil) }
  }

  @ViewBuilder private func article(_ topic: HelpTopic, isRoot: Bool) -> some View {
    if let article = HelpLibrary.shared.article(for: topic) {
      HelpArticleView(article: article, showsAllTopicsLink: isRoot) { shown in
        onFeedback(.issue, shown)
      }
    } else {
      // Der Katalog meldet fehlende Texte beim Laden; das Blatt bleibt trotzdem bedienbar.
      HelpCenterView { kind in onFeedback(kind, nil) }
    }
  }

  @ToolbarContentBuilder private var doneItem: some ToolbarContent {
    ToolbarItem(placement: .confirmationAction) {
      Button("help.done") { dismiss() }
    }
  }
}
