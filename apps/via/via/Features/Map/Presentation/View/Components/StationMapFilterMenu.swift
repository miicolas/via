import SwiftUI

struct StationMapFilterMenu: View {
  @Binding var filter: StationMapFilter

  var body: some View {
    menu
    .buttonStyle(.plain)
    .foregroundStyle(filter.isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
    .frame(width: 52, height: 52)
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
      Label("Filtrer les stations", systemImage: "line.3.horizontal.decrease")
        .labelStyle(.iconOnly)
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
