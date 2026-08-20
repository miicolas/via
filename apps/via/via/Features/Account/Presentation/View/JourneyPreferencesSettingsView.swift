import SwiftUI

struct JourneyPreferencesSettingsView: View {
    let accountModel: AccountModel
    @Bindable var searchViewModel: SearchViewModel

    var body: some View {
        List {
            Section {
                ForEach(TransitMode.allCases, id: \.self) { mode in
                    Picker(selection: preferenceBinding(for: mode)) {
                        ForEach(TransitModePreference.allCases) { preference in
                            Text(preference.title).tag(preference)
                        }
                    } label: {
                        Label(mode.displayName, systemImage: mode.chipSystemImage)
                    }
                    .pickerStyle(.menu)
                }
            } header: {
                Text("MODES DE TRANSPORT")
            } footer: {
                Text("Via privilégie ou évite ces modes lorsqu’un trajet ne précise pas de préférence.")
            }

            Section {
                Toggle("Stations accessibles uniquement", isOn: Binding(
                    get: { searchViewModel.filters.accessibleStationsOnly },
                    set: { searchViewModel.setAccessibleStationsOnly($0) }
                ))

                Toggle("Trajets accessibles uniquement", isOn: Binding(
                    get: { searchViewModel.filters.requiresAccessibleStations },
                    set: { searchViewModel.setRequiresAccessibleStations($0) }
                ))
            } header: {
                Text("ACCESSIBILITÉ")
            } footer: {
                Text("Le second réglage active automatiquement le filtrage des stations accessibles.")
            }
        }
        .navigationTitle("Préférences de trajet")
        .navigationBarTitleDisplayMode(.large)
    }

    private func preferenceBinding(for mode: TransitMode) -> Binding<TransitModePreference> {
        Binding(
            get: { accountModel.preference(for: mode) },
            set: { accountModel.setPreference($0, for: mode) }
        )
    }
}
