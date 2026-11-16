import FrontstageCore
import SwiftUI

/// Hilfeknopf: Fragezeichen; zeigt sein Blatt selbst und startet von dort eine Rückmeldung.
///
/// Die Rückmeldung öffnet erst, wenn das Hilfeblatt zu ist (`onDismiss`) – zwei Blätter gleichzeitig
/// am selben View verträgt SwiftUI nicht; das Rückmeldeblatt hängt deshalb an einem eigenen Hintergrund.
struct HelpButton: View {
  let topic: HelpTopic

  @State private var showsArticle = false
  @State private var pending: (kind: FeedbackKind, topic: HelpTopic)?
  @State private var session: FeedbackSession?
  @Environment(\.feedbackContext) private var feedbackContext

  init(topic: HelpTopic) {
    self.topic = topic
  }

  var body: some View {
    let title = HelpLibrary.shared.article(for: topic)?.title ?? ""
    Button {
      showsArticle = true
    } label: {
      Label("help.button", systemImage: "questionmark.circle")
    }
    .labelStyle(.iconOnly)
    .accessibilityLabel(Text("help.button.label \(title)"))
    .help(Text("help.button.label \(title)"))
    .sheet(isPresented: $showsArticle, onDismiss: { startPendingFeedback() }) {
      HelpSheet(root: .article(topic)) { kind, shown in
        pending = (kind, shown ?? topic)
        showsArticle = false
      }
    }
    .background { Color.clear.feedbackSheet($session) }
  }

  private func startPendingFeedback() {
    guard let pending else { return }
    self.pending = nil
    session = FeedbackStarter.start(kind: pending.kind, topic: pending.topic, context: feedbackContext)
  }
}
