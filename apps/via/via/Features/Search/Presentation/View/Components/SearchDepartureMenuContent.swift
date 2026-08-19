import SwiftUI

/// Actions shown by the navigation title menu for choosing a journey origin.
struct SearchDepartureMenuContent: View {
    let selection: SearchDepartureSelection
    let savedPlaces: [SavedPlace]
    let onSelect: (SearchDepartureSelection) -> Void
    let onChooseManual: () -> Void

    private var configuredPlaces: [SavedPlace] {
        savedPlaces.filter { $0.role == .home || $0.role == .work }
    }

    var body: some View {
        Button {
            onSelect(.currentLocation)
        } label: {
            menuItem(
                title: "Ma position",
                systemImage: StationPlaceShortcut.currentLocation.systemImage,
                isSelected: selection == .currentLocation
            )
        }
        .accessibilityValue(selection == .currentLocation ? "Sélectionné" : "Non sélectionné")
        .accessibilityAddTraits(selection == .currentLocation ? .isSelected : [])

        ForEach(configuredPlaces) { place in
            let isSelected = selection == .saved(place)
            Button {
                onSelect(.saved(place))
            } label: {
                menuItem(
                    title: place.role.displayTitle,
                    systemImage: place.role.systemImage,
                    isSelected: isSelected
                )
            }
            .accessibilityValue(isSelected ? "Sélectionné" : "Non sélectionné")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }

        if case .manual(let result) = selection {
            Divider()

            Button {
                onChooseManual()
            } label: {
                menuItem(
                    title: result.name,
                    systemImage: "mappin.and.ellipse",
                    isSelected: true
                )
            }
            .accessibilityValue("Sélectionné")
            .accessibilityAddTraits(.isSelected)
        }

        Divider()

        Button(action: onChooseManual) {
            Label("Choisir une station ou une adresse", systemImage: "magnifyingglass")
        }
    }

    private func menuItem(
        title: String,
        systemImage: String,
        isSelected: Bool
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)

            if isSelected {
                Spacer(minLength: 12)
                Image(systemName: "checkmark")
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview {
    SearchDepartureMenuContent(
        selection: .currentLocation,
        savedPlaces: [],
        onSelect: { _ in },
        onChooseManual: {}
    )
}
