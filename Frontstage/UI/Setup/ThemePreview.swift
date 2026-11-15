import FrontstageCore
import SwiftUI

/// Vorschau des Erscheinungsbilds (FR-16.1): hell und dunkel nebeneinander, mit festen Farben aus
/// `colors(.light)` und `colors(.dark)` – unabhängig vom aktuellen Modus des Geräts.
///
/// Die Kachel und der Kapselknopf sind Nachbauten von `TileButtonStyle` und `CapsuleActionButtonStyle`
/// mit statischen statt dynamischen Farben (die Stile lesen `themeStyle`, das sich nach dem Modus richtet).
struct ThemePreview: View {
  let resolved: ResolvedTheme

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      column(title: "setup.appearance.preview.light", variant: .light)
      column(title: "setup.appearance.preview.dark", variant: .dark)
    }
  }

  private func column(title: LocalizedStringKey, variant: ThemeVariant) -> some View {
    let colors = resolved.colors(variant)
    return VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.footnote).foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text("setup.appearance.preview.sampleMaterial")
            .scaledFont(.materialName)
            .foregroundStyle(Color(colors.accent))
          Text(verbatim: "PDF")
            .scaledFont(.fileType)
            .foregroundStyle(Color(colors.accent))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(colors.accentTint)))
        Text("dayView.cancel")
          .scaledFont(.action)
          .foregroundStyle(Color(colors.accent))
          .padding(.horizontal, 16)
          .frame(minHeight: 44)
          .background(Capsule().fill(Color(colors.accentTint)))
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(colors.background))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(Color(colors.hairline), lineWidth: 1))
      if resolved.isAccentAdjusted(variant) {
        Text("setup.appearance.preview.adjusted").font(.footnote).foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .accessibilityElement(children: .contain)
  }
}
