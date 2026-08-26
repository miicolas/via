import SwiftUI

struct StationMapFilterMenu: View {
  @Binding var filter: StationMapFilter

  /// Apple's own map controls are 44pt, and the filter sits beside them.
  private static let side: CGFloat = 44

  var body: some View {
    menu
    .buttonStyle(.plain)
    // The menu stays open while criteria are ticked, and it covers the map it
    // is filtering: the checkmark is the only thing that moves, so each tick
    // answers on its own. Emptying the filter answers differently.
    .haptic(Haptic.selection, on: filter) { _, new in new.isActive }
    .haptic(Haptic.cleared, on: filter.isActive) { $0 && !$1 }
    .foregroundStyle(filter.isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
    .glassEffect(.regular, in: .circle)
    .accessibilityLabel("Filtrer les stations")
    .accessibilityValue(accessibilityValue)
    .accessibilityHint("Affiche les filtres de stations")
  }

  private var menu: some View {
    Menu {
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

      Section("Vélos partagés") {
        ForEach(StationMapFilterCriterion.sharedMobility, id: \.self) { criterion in
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
      Label("Filtrer les stations", systemImage: "line.3.horizontal.decrease")
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
        Text(mode.displayName)
      } icon: {
        TransitModeIconView(mode: mode, size: 20)
      }
    case .accessibility, .elevators, .toilets, .bikeStations:
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
