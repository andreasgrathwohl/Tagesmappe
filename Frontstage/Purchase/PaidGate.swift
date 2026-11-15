import SwiftUI

/// Bezahlte Funktionen (FR-13). Material, „Dunkel“ und Stundenangaben gehören **nie** hierher.
/// `appearance`: Erscheinungsbild außerhalb des Standards (Grundton, Akzent, Hell/Dunkel); ohne Kauf gilt der Standard.
enum PaidFeature: Hashable {
  case classScreen, timer, workMode, board, appearance
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
