import SwiftUI

struct StationPlacePicker: View {
    let places: [SavedPlace]
    let destinations: [SavedDestination]
    let onOpen: (SearchResult) -> Void
    let onConfigure: (SavedPlace.Role) -> Void
    let onAdd: () -> Void
    let onEditPlace: (SavedPlace) -> Void
    let onEditDestination: (SavedDestination) -> Void
    let onClearPlace: (SavedPlace.Role) -> Void
    let onRemoveDestination: (UUID) -> Void
    let onManage: () -> Void

    @State private var destinationPendingRemoval: SavedDestination?
    @State private var addTick = 0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SavedPlace.Role.allCases) { role in
                    placeButton(for: role)
                }

                ForEach(destinations.sorted { $0.position < $1.position }) { destination in
                    destinationButton(destination)
                }

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
                onRemoveDestination(id)
                destinationPendingRemoval = nil
            }
            Button("Annuler", role: .cancel) {
                destinationPendingRemoval = nil
            }
        }
    }

    private func placeButton(for role: SavedPlace.Role) -> some View {
        let place = places.first { $0.role == role }
        return Button {
            if let place {
                onOpen(place.searchResult)
            } else {
                onConfigure(role)
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
        .accessibilityValue(place == nil ? "À configurer" : "Configuré")
        .accessibilityHint(
            place == nil
                ? "Recherche l’adresse de \(role.displayTitle)"
                : "Calcule un trajet depuis votre position"
        )
        .contextMenu {
            if let place {
                Button("Modifier", systemImage: "pencil") {
                    onEditPlace(place)
                }
                Button("Effacer l’adresse", systemImage: "eraser", role: .destructive) {
                    onClearPlace(role)
                }
            }
            Button("Gérer les favoris", systemImage: "list.bullet") {
                onManage()
            }
        }
    }

    private func destinationButton(_ destination: SavedDestination) -> some View {
        Button {
            onOpen(destination.searchResult)
        } label: {
            capsuleLabel(
                title: destination.label,
                systemImage: SavedDestinationSymbols.resolved(destination.systemImage),
                isConfigured: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Calcule un trajet depuis votre position")
        .contextMenu {
            Button("Modifier", systemImage: "pencil") {
                onEditDestination(destination)
            }
            Button("Supprimer", systemImage: "trash", role: .destructive) {
                destinationPendingRemoval = destination
            }
            Button("Gérer les favoris", systemImage: "list.bullet") {
                onManage()
            }
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

    private var removalPresentation: Binding<Bool> {
        Binding(
            get: { destinationPendingRemoval != nil },
            set: { if !$0 { destinationPendingRemoval = nil } }
        )
    }
}

#Preview {
    StationPlacePicker(
        places: [],
        destinations: [],
        onOpen: { _ in },
        onConfigure: { _ in },
        onAdd: {},
        onEditPlace: { _ in },
        onEditDestination: { _ in },
        onClearPlace: { _ in },
        onRemoveDestination: { _ in },
        onManage: {}
    )
    .padding(.vertical)
}
