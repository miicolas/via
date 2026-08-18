import SwiftUI

enum StationPlaceShortcut: String, CaseIterable, Hashable, Identifiable {
    case home
    case work

    var id: Self { self }

    var title: String {
        switch self {
        case .home:
            "Maison"
        case .work:
            "Travail"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house.fill"
        case .work:
            "briefcase.fill"
        }
    }
}

struct StationPlacePicker: View {
    @Binding private var selection: StationPlaceShortcut?

    private let onAddPlace: () -> Void

    init(
        selection: Binding<StationPlaceShortcut?>,
        onAddPlace: @escaping () -> Void = {}
    ) {
        _selection = selection
        self.onAddPlace = onAddPlace
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(StationPlaceShortcut.allCases) { shortcut in
                    shortcutButton(for: shortcut)
                }

                Button(action: onAddPlace) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ajouter un lieu")
                .accessibilityHint("Ajoute un nouveau bouton de lieu")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .scrollClipDisabled()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lieux enregistrés")
    }

    private func shortcutButton(for shortcut: StationPlaceShortcut) -> some View {
        let isSelected = selection == shortcut

        return Button {
            selection = shortcut
        } label: {
            Label(shortcut.title, systemImage: shortcut.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(
                    isSelected
                        ? Color.accentColor.opacity(0.14)
                        : Color.secondary.opacity(0.12),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected ? Color.accentColor.opacity(0.35) : .clear,
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Sélectionné" : "Non sélectionné")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var selection: StationPlaceShortcut? = .home

    StationPlacePicker(selection: $selection)
        .padding(.vertical)
}
