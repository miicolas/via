import SwiftUI

/// Actions shown by the navigation title menu for choosing a journey origin.
struct SearchDepartureMenuContent: View {
    let selection: SearchDepartureSelection?
    let onSelect: (SearchDepartureSelection) -> Void
    let onChooseManual: () -> Void

    var body: some View {
        ForEach(StationPlaceShortcut.allCases) { shortcut in
            let isSelected = isSelected(shortcut)

            Button {
                onSelect(selection(for: shortcut))
            } label: {
                menuItem(
                    title: shortcut.title,
                    systemImage: shortcut.systemImage,
                    isSelected: isSelected
                )
            }
            .accessibilityValue(isSelected ? "Sélectionné" : "Non sélectionné")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }

        if case .manual(let result) = selection {
            Divider()

            Button(action: onChooseManual) {
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

    private func selection(for shortcut: StationPlaceShortcut) -> SearchDepartureSelection {
        switch shortcut {
        case .currentLocation:
            .currentLocation
        case .home, .work:
            .saved(shortcut)
        }
    }

    private func isSelected(_ shortcut: StationPlaceShortcut) -> Bool {
        switch (selection, shortcut) {
        case (.currentLocation, .currentLocation):
            true
        case (.saved(let selected), let shortcut):
            selected == shortcut
        default:
            false
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
        onSelect: { _ in },
        onChooseManual: {}
    )
}
