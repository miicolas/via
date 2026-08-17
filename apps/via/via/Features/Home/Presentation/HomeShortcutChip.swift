import SwiftUI

/// Circular Apple Maps-style shortcut: filled chips launch a journey, empty
/// home/work chips invite the user to save the place.
struct HomeShortcutChip: View {
    let title: String
    let systemImage: String
    var isPlaceholder = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(isPlaceholder ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                    .frame(width: 56, height: 56)
                    .glassEffect(.regular.interactive(), in: .circle)

                VStack(spacing: 1) {
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if isPlaceholder {
                        Text("Ajouter")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 76)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    HStack(alignment: .top, spacing: 10) {
        HomeShortcutChip(title: "Maison", systemImage: "house.fill", action: {})
        HomeShortcutChip(title: "Travail", systemImage: "briefcase.fill", isPlaceholder: true, action: {})
        HomeShortcutChip(title: "Chatou - Croissy", systemImage: "tram.fill", action: {})
    }
    .padding()
}
