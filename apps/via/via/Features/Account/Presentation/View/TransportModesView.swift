import SwiftUI

struct TransportModesView: View {
    let account: AccountModel

    var body: some View {
        List {
            Section {
                ForEach(TransitMode.allCases, id: \.self) { mode in
                    Toggle(isOn: binding(for: mode)) {
                        Label {
                            Text(mode.displayName)
                        } icon: {
                            mode.glyph
                                .frame(width: 28, height: 28)
                                .foregroundStyle(.tint)
                        }
                    }
                    .frame(minHeight: 44)
                }
            } footer: {
                Text("Sélectionne plusieurs modes. Aucun mode minimal n’est imposé.")
            }
        }
        .navigationTitle("Modes de transport")
        .toolbarTitleDisplayMode(.inlineLarge)
    }

    private func binding(for mode: TransitMode) -> Binding<Bool> {
        Binding(
            get: { account.transportPreferences.preferredModes.contains(mode) },
            set: { account.setPreferred(mode, enabled: $0) }
        )
    }
}
