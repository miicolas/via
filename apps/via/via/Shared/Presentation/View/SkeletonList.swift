import SwiftUI

/// The one placeholder layout the whole app uses while a list loads.
///
/// Each screen describes the geometry of its real row — leading glyph, text
/// lines, trailing value, separator, surface — instead of shipping its own
/// skeleton view. The block reads as a single loading unit for VoiceOver and
/// carries a single sweeping highlight.
struct SkeletonList: View {
    struct Line: Sendable {
        enum Width: Sendable {
            case fixed(CGFloat)
            case fill
        }

        var width: Width
        var height: CGFloat

        static let heading = Line(width: .fill, height: 28)
        static let title = Line(width: .fill, height: 14)
        static let body = Line(width: .fill, height: 12)
        static let caption = Line(width: .fill, height: 10)

        static func heading(_ width: CGFloat) -> Line { Line(width: .fixed(width), height: 28) }
        static func title(_ width: CGFloat) -> Line { Line(width: .fixed(width), height: 14) }
        static func body(_ width: CGFloat) -> Line { Line(width: .fixed(width), height: 12) }
        static func caption(_ width: CGFloat) -> Line { Line(width: .fixed(width), height: 10) }
    }

    enum Accessory: Sendable {
        case none
        case circle(CGFloat)
        case capsule(width: CGFloat, height: CGFloat)
        case roundedRectangle(width: CGFloat, height: CGFloat, cornerRadius: CGFloat)

        /// Matches `LineBadgeView`, whose corner radius tracks its size.
        static func lineBadge(_ size: CGFloat) -> Accessory {
            .roundedRectangle(width: size, height: size, cornerRadius: size * 0.28)
        }
    }

    struct Row: Sendable {
        var leading: Accessory = .none
        var lines: [Line]
        var trailing: Accessory = .none
        var spacing: CGFloat = 7
        var verticalPadding: CGFloat = 12
    }

    enum Separator: Sendable {
        case none
        case divider(leadingInset: CGFloat)
    }

    enum Surface: Sendable {
        case plain
        case card(cornerRadius: CGFloat, padding: CGFloat)
    }

    let count: Int
    let label: String

    var row: Row
    var separator: Separator = .none
    var surface: Surface = .plain
    var spacing: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(0..<count, id: \.self) { index in
                rowContent(at: index)

                if case .divider(let inset) = separator, index < count - 1 {
                    Divider()
                        .padding(.leading, inset)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .skeletonGroup(label: label)
    }

    @ViewBuilder
    private func rowContent(at index: Int) -> some View {
        let bars = HStack(alignment: .center, spacing: 14) {
            accessory(row.leading)

            VStack(alignment: .leading, spacing: row.spacing) {
                ForEach(Array(row.lines.enumerated()), id: \.offset) { offset, line in
                    lineContent(line, jitter: jitter(row: index, line: offset))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            accessory(row.trailing)
        }

        switch surface {
        case .plain:
            bars.padding(.vertical, row.verticalPadding)

        case .card(let cornerRadius, let padding):
            bars
                .padding(padding)
                .background(
                    Color.secondary.opacity(0.085),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        }
    }

    @ViewBuilder
    private func lineContent(_ line: Line, jitter: CGFloat) -> some View {
        switch line.width {
        case .fixed(let width):
            Skeleton(.capsule)
                .frame(width: width, height: line.height)

        case .fill:
            // A perfectly flush right edge reads as a table, not as text still
            // arriving, so each line stops a little short by a varying amount.
            HStack(spacing: 0) {
                Skeleton(.capsule)
                    .frame(height: line.height)

                Spacer(minLength: 0)
                    .frame(width: jitter)
            }
        }
    }

    @ViewBuilder
    private func accessory(_ accessory: Accessory) -> some View {
        switch accessory {
        case .none:
            EmptyView()
        case .circle(let size):
            Skeleton(.circle)
                .frame(width: size, height: size)
        case .capsule(let width, let height):
            Skeleton(.capsule)
                .frame(width: width, height: height)
        case .roundedRectangle(let width, let height, let cornerRadius):
            Skeleton(.roundedRectangle(cornerRadius: cornerRadius))
                .frame(width: width, height: height)
        }
    }

    private func jitter(row: Int, line: Int) -> CGFloat {
        [0, 46, 22, 68][(row &+ line) % 4]
    }
}

/// Every preset traces the real row it stands in for, so a placeholder never
/// drifts from the content that replaces it. The numbers are the ones the
/// production views declare — change them together.
extension SkeletonList.Row {
    /// `SearchResultRow`: 46pt circle, title3 name, a strip of 20pt line badges,
    /// trailing chevron, 12pt vertical padding.
    static let searchResult = Self(
        leading: .circle(46),
        lines: [
            SkeletonList.Line(width: .fill, height: 16),
            SkeletonList.Line(width: .fixed(76), height: 20),
        ],
        trailing: .capsule(width: 8, height: 14),
        spacing: 6,
        verticalPadding: 12
    )

    /// `JourneySummaryCard`: qualifier caption, title2 departure→arrival times,
    /// subheadline summary, then a row of 24pt line badges. 14pt inner spacing.
    static let journeyCard = Self(
        lines: [
            SkeletonList.Line(width: .fixed(120), height: 12),
            SkeletonList.Line(width: .fixed(186), height: 26),
            SkeletonList.Line(width: .fill, height: 13),
            SkeletonList.Line(width: .fixed(140), height: 24),
        ],
        spacing: 14,
        verticalPadding: 0
    )

    /// `DepartureLineRow`: 36pt line badge, body destination, and the trailing
    /// timing capsule. 58pt minimum height — 36 + 11 above and below.
    static let departure = Self(
        leading: .lineBadge(36),
        lines: [SkeletonList.Line(width: .fill, height: 15)],
        trailing: .capsule(width: 92, height: 34),
        verticalPadding: 11
    )

    /// `LineStatusRow`: 36pt line badge, body summary over a caption, trailing
    /// condition pill. 52pt minimum height.
    static let lineStatus = Self(
        leading: .lineBadge(36),
        lines: [
            SkeletonList.Line(width: .fill, height: 14),
            SkeletonList.Line(width: .fixed(150), height: 10),
        ],
        trailing: .capsule(width: 76, height: 22),
        spacing: 3,
        verticalPadding: 8
    )

    /// `LineSchemaStopRow`: 14pt bead on the rail, subheadline stop name,
    /// 34pt row height.
    static let schemaStop = Self(
        leading: .circle(14),
        lines: [SkeletonList.Line(width: .fill, height: 13)],
        verticalPadding: 10
    )
}

#Preview("Recherche de lieux") {
    SkeletonList(
        count: 4,
        label: "Recherche…",
        row: .searchResult,
        separator: .divider(leadingInset: 60)
    )
    .padding(.horizontal)
}

#Preview("Itinéraires") {
    SkeletonList(
        count: 3,
        label: "Recherche des itinéraires…",
        row: .journeyCard,
        surface: .card(cornerRadius: 22, padding: 18),
        spacing: 12
    )
    .padding(.horizontal)
}

#Preview("Prochains passages") {
    SkeletonList(
        count: 4,
        label: "Recherche de stations…",
        row: .departure,
        separator: .divider(leadingInset: 52)
    )
    .padding(.horizontal)
}

#Preview("Lignes") {
    SkeletonList(
        count: 6,
        label: "Chargement des lignes…",
        row: .lineStatus
    )
    .padding(.horizontal)
}

#Preview("Détail de ligne") {
    SkeletonList(
        count: 8,
        label: "Chargement de la ligne…",
        row: .schemaStop
    )
    .padding(.horizontal)
}
