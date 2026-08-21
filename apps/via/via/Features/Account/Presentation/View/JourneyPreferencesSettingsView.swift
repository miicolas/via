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
                Toggle(
                    isOn: Binding(
                        get: { searchViewModel.filters.requiresAccessibleStations },
                        set: { searchViewModel.setRequiresAccessibleStations($0) }
                    )
                ) {
                    SettingsRow(
                        title: "Trajets PMR",
                        systemImage: "figure.roll",
                        subtitle: "Stations et ascenseurs accessibles",
                        tint: .accentColor
                    )
                }
            } header: {
                Text("ACCESSIBILITÉ")
            } footer: {
                Text("Via demande un itinéraire accessible, même s’il est plus long. Les pannes d’ascenseur en temps réel peuvent ne pas être connues.")
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
