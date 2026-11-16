import FrontstageCore
import SwiftUI

/// Hilfecenter. Ohne eigenen `NavigationStack` – steht in Einrichten (Push) und im `HelpSheet`.
/// Die Zeilen sind `NavigationLink(value: HelpTopic)`; das Ziel liefert der umgebende Stack.
struct HelpCenterView: View {
  let onFeedback: (FeedbackKind) -> Void

  @State private var model = HelpCenterModel(catalog: HelpLibrary.shared)
  @Environment(\.themeStyle) private var style

  init(onFeedback: @escaping (FeedbackKind) -> Void) {
    self.onFeedback = onFeedback
  }

  var body: some View {
    List {
      if model.isSearching {
        searchResults
      } else {
        ForEach(Array(model.sections.enumerated()), id: \.offset) { _, section in
          // Dynamischer Schlüssel: als `String`-Variable übergeben, sonst würde die Interpolation
          // zum Format-Schlüssel „help.group.%@“.
          let key = "help.group.\(section.group.rawValue)"
          Section {
            ForEach(section.articles) { article in row(article) }
          } header: {
            Text(LocalizedStringKey(key))
          }
        }
        tipsSection
        feedbackSection
      }
    }
    .themedBackground()
    .fontDesign(.rounded)
    .navigationTitle("help.center.title")
    .searchable(text: $model.query, prompt: "help.center.search")
  }

  @ViewBuilder private var searchResults: some View {
    if model.results.isEmpty {
      ContentUnavailableView.search(text: model.query)
        .listRowBackground(Color.clear)
    } else {
      ForEach(model.results) { article in row(article) }
    }
  }

  private func row(_ article: HelpArticle) -> some View {
    NavigationLink(value: article.topic) {
      VStack(alignment: .leading, spacing: 2) {
        Text(article.title)
        Text(article.summary)
          .scaledFont(.detailMeta)
          .foregroundStyle(.secondary)
      }
      .frame(minHeight: 44, alignment: .leading)
    }
  }

  private var tipsSection: some View {
    Section {
      Toggle(
        "tips.enabled",
        isOn: Binding(get: { HelpTips.isEnabled }, set: { HelpTips.isEnabled = $0 }))
      Button("tips.reset") { HelpTipsConfiguration.requestReset() }
    } header: {
      Text("tips.section")
    } footer: {
      Text("tips.reset.note")
    }
  }

  private var feedbackSection: some View {
    Section {
      HStack(spacing: 12) {
        Button("help.center.sendIdea") { onFeedback(.idea) }
        Button("help.center.sendIssue") { onFeedback(.issue) }
      }
      .buttonStyle(CapsuleActionButtonStyle())
      .listRowBackground(Color.clear)
    } header: {
      Text("help.center.feedback")
    } footer: {
      Text("help.center.feedbackNote")
    }
  }
}
