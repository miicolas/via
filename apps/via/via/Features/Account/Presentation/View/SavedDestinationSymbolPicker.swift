import SwiftUI

struct SavedDestinationSymbolPicker: View {
    @Binding var selection: String

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(SavedDestinationSymbols.choices, id: \.self) { symbol in
                Button {
                    selection = symbol
                } label: {
                    Image(systemName: symbol)
                        .font(.title3)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(selection == symbol ? Color.white : Color.primary)
                        .background(
                            selection == symbol ? Color.accentColor : Color.secondary.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(symbol.accessibilitySymbolName)
                .accessibilityValue(selection == symbol ? "Sélectionné" : "Non sélectionné")
                .accessibilityAddTraits(selection == symbol ? .isSelected : [])
            }
        }
    }
}

private extension String {
    var accessibilitySymbolName: String {
        switch self {
        case "mappin": "Lieu"
        case "house.fill": "Maison"
        case "briefcase.fill": "Travail"
        case "graduationcap.fill": "Études"
        case "figure.run", "dumbbell.fill": "Sport"
        case "cart.fill": "Courses"
        case "cross.case.fill": "Santé"
        case "fork.knife": "Restaurant"
        case "cup.and.saucer.fill": "Café"
        case "tram.fill": "Transport"
        case "airplane": "Voyage"
        case "car.fill": "Voiture"
        case "building.2.fill": "Bâtiment"
        case "tree.fill": "Parc"
        case "person.2.fill": "Famille"
        default: "Symbole"
        }
    }
}
