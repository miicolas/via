import SwiftUI

/// A journey the traveller covers on their own legs or wheels, reduced to the
/// two facts that decide it: the way it moves, and how long it takes. It is an
/// aside to a transit search — never one of its answers — so it wears a tile
/// the size of a saved line rather than a summary card.
struct DirectJourneyTile: View {
  let journey: Journey
  var isSelected = false

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: 10) {
      symbol
      duration
    }
    .padding(.horizontal, 12)
    .frame(height: 76)
    .background(background, in: .rect(cornerRadius: 18))
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(border, lineWidth: 2)
    }
    .contentShape(.rect)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityValue(durationText)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityHint("Ouvre le détail de cet itinéraire et l’affiche sur la carte")
    .animation(reduceMotion ? nil : .snappy, value: isSelected)
  }

  private var symbol: some View {
    Image(systemName: systemImage)
      .font(.title3.weight(.semibold))
      .foregroundStyle(tint)
      .frame(width: 44, height: 44)
      .background(.primary.opacity(0.05), in: .rect(cornerRadius: 14))
  }

  private var duration: some View {
    Text(durationText)
      .font(.subheadline.weight(.bold))
      .monospacedDigit()
      .foregroundStyle(tint)
  }

  private var durationText: String {
    JourneyFormatting.duration(journey.durationSeconds)
  }

  /// A route that mixes the two is still decided by the bike: it is the part
  /// the traveller has to have.
  private var systemImage: String {
    JourneyShape.of(journey).isBikeOnly ? "bicycle" : "figure.walk"
  }

  private var title: LocalizedStringKey {
    JourneyShape.of(journey).isBikeOnly ? "À vélo" : "À pied"
  }

  private var tint: AnyShapeStyle {
    isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
  }

  private var background: AnyShapeStyle {
    isSelected
      ? AnyShapeStyle(Color.accentColor.opacity(0.09))
      : AnyShapeStyle(Color.secondary.opacity(0.08))
  }

  private var border: AnyShapeStyle {
    isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.clear)
  }
}

#Preview {
  HStack(spacing: 12) {
    DirectJourneyTile(journey: .mapPreviewWalking)
    DirectJourneyTile(journey: .mapPreviewCycling, isSelected: true)
  }
  .padding()
}
