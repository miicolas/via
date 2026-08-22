import SwiftUI

struct LinesFilterMenu: View {
  @Binding var filter: LineStatusFilter

  var body: some View {
    Menu {
      Picker(selection: $filter.mode) {
        Label("Tous les modes", systemImage: "square.grid.2x2")
          .tag(nil as TransitMode?)

        ForEach(TransitMode.allCases, id: \.self) { mode in
          Label {
            Text(mode.displayName)
          } icon: {
            TransitModeIconView(mode: mode, size: 20)
          }
          .tag(mode as TransitMode?)
        }
      } label: {
        Label("Mode", systemImage: "tram.fill")
      }

      Toggle(isOn: $filter.disruptionsOnly) {
        Label("Perturbées uniquement", systemImage: "exclamationmark.triangle")
      }

      if filter.isActive {
        Divider()

        Button("Réinitialiser", systemImage: "arrow.counterclockwise") {
          filter.reset()
        }
      }
    } label: {
      Image(systemName: "line.3.horizontal.decrease")
        .foregroundStyle(filter.isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
    }
    .accessibilityLabel("Filtrer les lignes")
    .accessibilityValue(accessibilityValue)
  }

  private var accessibilityValue: String {
    if let mode = filter.mode, filter.disruptionsOnly {
      return "\(mode.displayName), perturbées uniquement"
    }
    if let mode = filter.mode {
      return mode.displayName
    }
    if filter.disruptionsOnly {
      return "Perturbées uniquement"
    }
    return "Tous les modes et tous les états"
  }
}
