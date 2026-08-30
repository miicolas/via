import SwiftUI

struct MeetupPlaceCard: View {
    let title: String
    let name: String
    let detail: String
    let systemImage: String
    var onCurrentLocation: (() -> Void)? = nil
    let onSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(.blue.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            }

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)

                    if let onCurrentLocation {
                        Button("Utiliser ma position", systemImage: "location.fill", action: onCurrentLocation)
                            .iconAction(size: .regular)
                    }

                    Button("Rechercher", systemImage: "magnifyingglass", action: onSearch)
                        .iconAction(isProminent: true, size: .regular)
                }
            }
        }
        .detailCard()
        .accessibilityElement(children: .contain)
    }
}
