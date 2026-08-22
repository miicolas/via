import SwiftUI

/// The mark a disclosure row wears at its leading edge.
enum LineRowGlyph {
    /// A plain symbol in the row's gutter — a perturbation, a fold of works.
    case symbol(String, tint: Color)
    /// A symbol inside a tinted disc — the plan's own branches wear this one.
    case disc(String, tint: Color)
}

/// One tappable row of the line screen: a mark, what it is, what it costs the
/// rider, and a chevron. The chevron turns when the row folds something open
/// and points on when it opens a sheet — which is the only thing that separates
/// a branch, a perturbation and the works fold from each other.
struct LineDisclosureRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let glyph: LineRowGlyph
    let title: String
    var titleWeight: Font.Weight = .semibold
    var subtitle: String?
    var subtitleTint: Color = .secondary
    /// `nil` for a row that opens a sheet: the chevron points on, it never turns.
    var isOpen: Bool?
    let accessibilityLabel: String
    var accessibilityValue: String?
    var accessibilityHint: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: spacing) {
                mark

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(titleWeight))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(subtitleTint)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isOpen == true ? 90 : 0))
                    .animation(reduceMotion ? nil : .snappy, value: isOpen)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue ?? "")
        .accessibilityHint(accessibilityHint ?? "")
    }

    private var spacing: CGFloat {
        switch glyph {
        case .symbol: 12
        case .disc: 14
        }
    }

    @ViewBuilder
    private var mark: some View {
        switch glyph {
        case let .symbol(name, tint):
            Image(systemName: name)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: 24)
        case let .disc(name, tint):
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                Image(systemName: name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 28, height: 28)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        LineDisclosureRow(
            glyph: .disc("arrow.triangle.branch", tint: .red),
            title: "Branche Cergy le Haut",
            subtitle: "9 gares",
            isOpen: false,
            accessibilityLabel: "Branche Cergy le Haut, 9 gares",
            accessibilityValue: "Repliée",
            accessibilityHint: "Déplier les gares",
            action: {}
        )
        LineDisclosureRow(
            glyph: .symbol("exclamationmark.triangle.fill", tint: .orange),
            title: "La Défense → Nation",
            titleWeight: .medium,
            subtitle: "Jusqu’à 18:30",
            accessibilityLabel: "Trafic perturbé, La Défense → Nation",
            accessibilityHint: "Afficher le détail",
            action: {}
        )
        LineDisclosureRow(
            glyph: .symbol("calendar", tint: .secondary),
            title: "Travaux à venir · 3",
            isOpen: true,
            accessibilityLabel: "Travaux à venir, 3",
            accessibilityValue: "Dépliés",
            action: {}
        )
    }
    .padding()
}
