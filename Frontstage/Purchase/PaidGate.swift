import SwiftUI

/// Bezahlte Funktionen (FR-13). Material, „Dunkel“ und Stundenangaben gehören **nie** hierher.
enum PaidFeature: Hashable {
  case classScreen, timer, workMode, board
}

/// Zeigt `content`, wenn freigeschaltet, sonst das Kaufangebot.
struct PaidGate<Content: View>: View {
  let feature: PaidFeature
  @ViewBuilder let content: () -> Content
  @Environment(Unlock.self) private var unlock

  var body: some View {
    if unlock.isUnlocked {
      content()
    } else {
      PurchaseOfferView()
    }
  }
}
