import SwiftUI

struct SearchInputToken: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let accessibilityLabel: String
    let expands: Bool
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        accessibilityLabel: String,
        expands: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
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

                    if let subtitle {
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
        .accessibilityHint("Modifie ce choix")
    }
}

#Preview {
    HStack(spacing: 8) {
        SearchInputToken(
            title: "Châtelet",
            subtitle: "M · 1 · 4",
            systemImage: "tram.fill",
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
