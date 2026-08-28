import SwiftUI

struct SearchInputToken: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let lineRoutes: [RouteBadge]
    let accessibilityLabel: String
    let expands: Bool
    let action: () -> Void

    private static let maximumVisibleLineRoutes = 3

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        lineRoutes: [RouteBadge] = [],
        accessibilityLabel: String,
        expands: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.lineRoutes = lineRoutes
        self.accessibilityLabel = accessibilityLabel
        self.expands = expands
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !lineRoutes.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(lineRoutes.prefix(Self.maximumVisibleLineRoutes)) { route in
                                LineBadgeView(route: route, size: 20)
                            }
                        }
                    } else if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: expands ? .infinity : nil, minHeight: 48, alignment: .leading)
            .background(
                Color.secondary.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Modifie ce choix")
    }

    private var accessibilityValue: String {
        if !lineRoutes.isEmpty {
            let visibleRoutes = lineRoutes
                .prefix(Self.maximumVisibleLineRoutes)
                .map(\.shortName)
                .joined(separator: ", ")
            return "Lignes \(visibleRoutes)"
        }

        return subtitle ?? ""
    }
}

#Preview {
    let station = SearchResult.previewStation

    HStack(spacing: 8) {
        SearchInputToken(
            title: station.name,
            subtitle: station.subtitle,
            systemImage: station.systemImage,
            lineRoutes: station.lineRoutes,
            accessibilityLabel: "Destination Châtelet",
            action: {}
        )

        SearchInputToken(
            title: "24 juin",
            subtitle: nil,
            systemImage: "calendar",
            accessibilityLabel: "Date 24 juin",
            action: {}
        )
    }
    .padding()
}
