import SwiftUI

struct StationMapFilterMenu: View {
  @Binding var filter: StationMapFilter

  /// Apple's own map controls are 44pt, and the filter sits beside them.
  private static let side: CGFloat = 44

  var body: some View {
    menu
    .iconAction(size: .small)
    // A native map compass is allowed to appear transiently under this control
    // while the camera rotates. The opaque system surface keeps that animation
    // from showing through the filter button.
    .background(Color(.secondarySystemBackground), in: Circle())
    .haptic(Haptic.selection, on: filter) { _, new in new.isActive }
    .haptic(Haptic.cleared, on: filter.isActive) { $0 && !$1 }
    .foregroundStyle(filter.isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
    .accessibilityLabel("Filtrer la carte")
    .accessibilityValue(accessibilityValue)
    .accessibilityHint("Affiche les filtres de carte")
  }

  private var menu: some View {
    Menu {
      Section("Mobilité partagée") {
        ForEach(StationMapFilterCriterion.sharedMobility, id: \.self) { criterion in
          criterionToggle(criterion)
        }
      }

      Section("Équipements") {
        ForEach(StationMapFilterCriterion.facilities, id: \.self) { criterion in
          criterionToggle(criterion)
        }
      }

      Section("Transports") {
        ForEach(StationMapFilterCriterion.transportModes, id: \.self) { criterion in
          criterionToggle(criterion)
        }
      }

      if filter.isActive {
        Divider()

        Button("Réinitialiser", systemImage: "arrow.counterclockwise") {
          filter.reset()
        }
      }
    } label: {
      // The frame and the hit shape belong to the *label*: put them outside the
      // `Menu` and they grow the layout box while the tappable area stays the
      // glyph, so every tap around the icon falls through to the map.
      Label("Filtrer la carte", systemImage: "line.3.horizontal.decrease")
        .labelStyle(.iconOnly)
        .font(.system(size: 17, weight: .medium))
        .frame(width: Self.side, height: Self.side)
        .contentShape(.circle)
    }
    .menuOrder(.fixed)
  }

  private func criterionToggle(_ criterion: StationMapFilterCriterion) -> some View {
    Toggle(isOn: binding(for: criterion)) {
      criterionLabel(criterion)
    }
    .menuActionDismissBehavior(.disabled)
  }

  @ViewBuilder
  private func criterionLabel(_ criterion: StationMapFilterCriterion) -> some View {
    switch criterion {
    case .mode(let mode):
      Label {
        Text(criterion.title)
      } icon: {
        TransitModeIconView(mode: mode, size: 20)
          .accessibilityHidden(true)
      }
    default:
      Label(criterion.title, systemImage: criterion.systemImage)
    }
  }

  private func binding(for criterion: StationMapFilterCriterion) -> Binding<Bool> {
    Binding(
      get: { filter.contains(criterion) },
      set: { filter.set(criterion, isEnabled: $0) }
    )
  }

  private var accessibilityValue: String {
    guard filter.isActive else { return "Aucun filtre actif" }
    let count = filter.activeCount
    let names = filter.activeCriteriaInDisplayOrder.map(\.title).joined(separator: ", ")
    return "\(count) filtre\(count > 1 ? "s" : "") actif\(count > 1 ? "s" : "") : \(names)"
  }
}
