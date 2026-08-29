import SwiftUI

/// The horizontal shortcut rail shared by Stations and address search.
/// Callers decide what selecting a saved address means and only provide the
/// management actions that make sense on their surface.
struct SavedPlacesBar: View {
    let places: [SavedPlace]
    let destinations: [SavedDestination]
    let selectionAccessibilityHint: String
    let isSelectedPlace: ((SavedPlace) -> Bool)?
    let isSelectedDestination: ((SavedDestination) -> Bool)?
    let onSelectPlace: (SavedPlace) -> Void
    let onSelectDestination: (SavedDestination) -> Void
    let onConfigure: ((SavedPlace.Role) -> Void)?
    let onAdd: (() -> Void)?
    let onEditPlace: ((SavedPlace) -> Void)?
    let onEditDestination: ((SavedDestination) -> Void)?
    let onClearPlace: ((SavedPlace.Role) -> Void)?
    let onRemoveDestination: ((UUID) -> Void)?
    let onManage: (() -> Void)?

    @State private var destinationPendingRemoval: SavedDestination?
    @State private var addTick = 0

    init(
        places: [SavedPlace],
        destinations: [SavedDestination],
        selectionAccessibilityHint: String,
        isSelectedPlace: ((SavedPlace) -> Bool)? = nil,
        isSelectedDestination: ((SavedDestination) -> Bool)? = nil,
        onSelectPlace: @escaping (SavedPlace) -> Void,
        onSelectDestination: @escaping (SavedDestination) -> Void,
        onConfigure: ((SavedPlace.Role) -> Void)? = nil,
        onAdd: (() -> Void)? = nil,
        onEditPlace: ((SavedPlace) -> Void)? = nil,
        onEditDestination: ((SavedDestination) -> Void)? = nil,
        onClearPlace: ((SavedPlace.Role) -> Void)? = nil,
        onRemoveDestination: ((UUID) -> Void)? = nil,
        onManage: (() -> Void)? = nil
    ) {
        self.places = places
        self.destinations = destinations
        self.selectionAccessibilityHint = selectionAccessibilityHint
        self.isSelectedPlace = isSelectedPlace
        self.isSelectedDestination = isSelectedDestination
        self.onSelectPlace = onSelectPlace
        self.onSelectDestination = onSelectDestination
        self.onConfigure = onConfigure
        self.onAdd = onAdd
        self.onEditPlace = onEditPlace
        self.onEditDestination = onEditDestination
        self.onClearPlace = onClearPlace
        self.onRemoveDestination = onRemoveDestination
        self.onManage = onManage
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SavedPlace.Role.allCases) { role in
                    if let place = places.first(where: { $0.role == role }) {
                        placeButton(for: role, place: place)
                    } else if onConfigure != nil {
                        placeButton(for: role, place: nil)
                    }
                }

                ForEach(destinations.sorted { $0.position < $1.position }) { destination in
                    destinationButton(destination)
                }

                if let onAdd {
                    Button {
                        addTick += 1
                        onAdd()
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.accentColor, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(destinations.count >= AccountLocalSnapshot.destinationLimit)
                    .haptic(Haptic.tap, on: addTick)
                    .accessibilityLabel("Ajouter un lieu favori")
                    .accessibilityHint(
                        destinations.count >= AccountLocalSnapshot.destinationLimit
                            ? "La limite de favoris est atteinte"
                            : "Recherche une destination à enregistrer"
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .scrollClipDisabled()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Destinations enregistrées")
        // Removing a favourite is confirmed in a dialog that covers the rail:
        // the warning is what tells the thumb the destructive path opened.
        .haptic(Haptic.warned, on: destinationPendingRemoval != nil) { !$0 && $1 }
        .confirmationDialog(
            "Supprimer \(destinationPendingRemoval?.label ?? "ce favori") ?",
            isPresented: removalPresentation,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                guard let id = destinationPendingRemoval?.id else { return }
                onRemoveDestination?(id)
                destinationPendingRemoval = nil
            }
            Button("Annuler", role: .cancel) {
                destinationPendingRemoval = nil
            }
        }
    }

    @ViewBuilder
    private func placeButton(for role: SavedPlace.Role, place: SavedPlace?) -> some View {
        let button = Button {
            if let place {
                onSelectPlace(place)
            } else {
                onConfigure?(role)
            }
        } label: {
            capsuleLabel(
                title: role.displayTitle,
                systemImage: SavedDestinationSymbols.resolved(
                    place?.systemImage ?? role.systemImage,
                    fallback: role.systemImage
                ),
                isConfigured: place != nil
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(placeAccessibilityValue(place))
        .accessibilityHint(
            place == nil
                ? "Recherche l’adresse de \(role.displayTitle)"
                : selectionAccessibilityHint
        )
        .accessibilityAddTraits(isSelected(place) ? .isSelected : [])

        if let place, hasPlaceManagementActions {
            button.contextMenu {
                if let onEditPlace {
                    Button("Modifier", systemImage: "pencil") {
                        onEditPlace(place)
                    }
                }
                if let onClearPlace {
                    Button("Effacer l’adresse", systemImage: "eraser", role: .destructive) {
                        onClearPlace(role)
                    }
                }
                manageButton
            }
        } else if place == nil, onManage != nil {
            button.contextMenu {
                manageButton
            }
        } else {
            button
        }
    }

    @ViewBuilder
    private func destinationButton(_ destination: SavedDestination) -> some View {
        let button = Button {
            onSelectDestination(destination)
        } label: {
            capsuleLabel(
                title: destination.label,
                systemImage: SavedDestinationSymbols.resolved(destination.systemImage),
                isConfigured: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(destinationAccessibilityValue(destination))
        .accessibilityHint(selectionAccessibilityHint)
        .accessibilityAddTraits(isSelected(destination) ? .isSelected : [])

        if hasDestinationManagementActions {
            button.contextMenu {
                if let onEditDestination {
                    Button("Modifier", systemImage: "pencil") {
                        onEditDestination(destination)
                    }
                }
                if onRemoveDestination != nil {
                    Button("Supprimer", systemImage: "trash", role: .destructive) {
                        destinationPendingRemoval = destination
                    }
                }
                manageButton
            }
        } else {
            button
        }
    }

    private func capsuleLabel(
        title: String,
        systemImage: String,
        isConfigured: Bool
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isConfigured ? Color.primary : Color.secondary)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(Color.secondary.opacity(isConfigured ? 0.12 : 0.07), in: Capsule())
            .opacity(isConfigured ? 1 : 0.72)
    }

    @ViewBuilder
    private var manageButton: some View {
        if let onManage {
            Button("Gérer les favoris", systemImage: "list.bullet") {
                onManage()
            }
        }
    }

    private var hasPlaceManagementActions: Bool {
        onEditPlace != nil || onClearPlace != nil || onManage != nil
    }

    private var hasDestinationManagementActions: Bool {
        onEditDestination != nil || onRemoveDestination != nil || onManage != nil
    }

    private func isSelected(_ place: SavedPlace?) -> Bool {
        guard let place, let isSelectedPlace else { return false }
        return isSelectedPlace(place)
    }

    private func isSelected(_ destination: SavedDestination) -> Bool {
        isSelectedDestination?(destination) ?? false
    }

    private func placeAccessibilityValue(_ place: SavedPlace?) -> String {
        guard let place else { return "À configurer" }
        guard isSelectedPlace != nil else { return "Configuré" }
        return isSelected(place) ? "Sélectionné" : "Non sélectionné"
    }

    private func destinationAccessibilityValue(_ destination: SavedDestination) -> String {
        guard isSelectedDestination != nil else { return "Configuré" }
        return isSelected(destination) ? "Sélectionné" : "Non sélectionné"
    }

    private var removalPresentation: Binding<Bool> {
        Binding(
            get: { destinationPendingRemoval != nil },
            set: { if !$0 { destinationPendingRemoval = nil } }
        )
    }
}

#Preview {
    SavedPlacesBar(
        places: [],
        destinations: [],
        selectionAccessibilityHint: "Calcule un trajet vers ce lieu",
        onSelectPlace: { _ in },
        onSelectDestination: { _ in },
        onConfigure: { _ in },
        onAdd: {}
    )
    .padding(.vertical)
}
