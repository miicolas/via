import SwiftUI

/// The vertical rail slice belonging to one timeline row: the stroke above the
/// bead, the bead itself, the stroke below, and — in guidance — the live
/// position bubble.
///
/// Each row draws its own slice rather than a single rail being laid out across
/// the whole list. That keeps the bubble and the beads aligned with their text
/// at every Dynamic Type size, with no cross-row geometry to reconcile.
///
/// Nothing here switches between view branches: the ridden and the walked
/// strokes are both always in the tree and only their opacity changes. That is
/// what lets a leg change colour, dim behind the traveller, or turn from ridden
/// to walked as a crossfade instead of a pop.
struct JourneyTimelineRail: View {
    let above: JourneyTimelineRailStyle
    let below: JourneyTimelineRailStyle
    let bead: JourneyTimelineBead
    let state: JourneyTimelineNodeState
    /// 0…1 down this row, when the traveller is on it.
    var cursorFraction: Double?
    /// A bubble placed from a location fix reads as live; a scheduled one does not.
    var isCursorLive: Bool = false

    static let width: CGFloat = 40

    /// Solid core of a ridden leg. The halo around it is what makes the rail
    /// read as one thick, soft object rather than a hairline.
    private static let lineWidth: CGFloat = 11
    private static let haloWidth: CGFloat = 22
    private static let pedestrianWidth: CGFloat = 7

    /// Deliberately outside the network palette: on a rail already tinted by
    /// every operator colour, only a colour no line uses reads instantly as *me*.
    /// The bubble is also the only bead on the rail wearing the app mark, for
    /// the same reason — everything else on the rail is a place, not a person.
    private static let cursorTint = Color.blue
    private static let cursorSize: CGFloat = 30

    @ScaledMetric(relativeTo: .headline) private var beadCenter: CGFloat = 14

    var body: some View {
        VStack(spacing: 0) {
            stroke(above)
                .frame(height: beadCenter)
            stroke(below)
                .frame(maxHeight: .infinity)
        }
        .frame(width: Self.width)
        .overlay(alignment: .top) { beadView.offset(y: beadCenter - beadSize / 2) }
        .overlay { cursorView }
        .animation(.smooth(duration: 0.35), value: state)
        .animation(.smooth(duration: 0.35), value: above)
        .animation(.smooth(duration: 0.35), value: below)
        .accessibilityHidden(true)
    }

    // MARK: - Strokes

    private func stroke(_ style: JourneyTimelineRailStyle) -> some View {
        ZStack {
            lineStroke(style.lineTint ?? Color.accentColor)
                .opacity(style.isLine ? strokeOpacity : 0)

            pedestrianStroke
                .opacity(style.isPedestrian ? strokeOpacity : 0)
        }
        .frame(width: Self.width)
    }

    /// A solid core inside a soft halo. The halo is a plain horizontal gradient
    /// rather than a blur, so consecutive rows still stack without a seam.
    private func lineStroke(_ tint: Color) -> some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0), tint.opacity(0.22), tint.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: Self.haloWidth)

            Rectangle()
                .fill(tint)
                .frame(width: Self.lineWidth)
        }
    }

    private var pedestrianStroke: some View {
        RailPath()
            .stroke(
                Color.secondary.opacity(0.8),
                style: StrokeStyle(
                    lineWidth: Self.pedestrianWidth,
                    lineCap: .round,
                    dash: [0.5, 11]
                )
            )
            .frame(width: Self.pedestrianWidth)
    }

    // MARK: - Bead

    private var beadSize: CGFloat {
        switch bead {
        case .terminus: 20
        case .major: 18
        case .minor: 12
        case .none: 0
        }
    }

    /// The bead sits in a background-coloured gap, so it keeps punching out of a
    /// rail that is now thick enough to swallow it.
    @ViewBuilder
    private var beadView: some View {
        if bead != .none {
            beadShape
                .frame(width: beadSize, height: beadSize)
                .background {
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: beadSize + 7, height: beadSize + 7)
                }
        }
    }

    @ViewBuilder
    private var beadShape: some View {
        switch bead {
        case .none:
            EmptyView()
        case .terminus:
            Circle()
                .fill(beadTint.opacity(strokeOpacity))
                .overlay {
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: beadSize * 0.36, height: beadSize * 0.36)
                }
        case .minor:
            Circle()
                .fill(Color(.systemBackground))
                .overlay {
                    Circle().strokeBorder(beadTint.opacity(strokeOpacity), lineWidth: 3)
                }
        case .major:
            Circle()
                .fill(Color(.systemBackground))
                .overlay {
                    // A done stop keeps a thin ring, an upcoming one a thick
                    // filled ring, so the state survives without colour.
                    Circle().strokeBorder(
                        beadTint.opacity(strokeOpacity),
                        lineWidth: state == .done ? 2.5 : 5
                    )
                }
        }
    }

    private var beadTint: Color {
        below.lineTint ?? above.lineTint ?? Color.accentColor
    }

    // MARK: - Position bubble

    @ViewBuilder
    private var cursorView: some View {
        if let cursorFraction {
            GeometryReader { proxy in
                MarkBadge(
                    tint: Self.cursorTint,
                    size: Self.cursorSize,
                    isEstimated: !isCursorLive
                )
                .position(
                    x: proxy.size.width / 2,
                    y: proxy.size.height * min(max(0, cursorFraction), 1)
                )
            }
            .transition(.scale(scale: 0.4).combined(with: .opacity))
            .animation(.smooth(duration: 0.55), value: cursorFraction)
        }
    }

    // MARK: - Shared styling

    private var strokeOpacity: Double {
        state == .done ? 0.35 : 1
    }
}

private extension JourneyTimelineRailStyle {
    var isLine: Bool {
        if case .line = self { return true }
        return false
    }

    var isPedestrian: Bool {
        self == .pedestrian
    }

    var lineTint: Color? {
        guard case .line(let colorHex) = self else { return nil }
        return Color(transitHex: colorHex ?? "", fallback: .accentColor)
    }
}

/// A plain vertical line, so the pedestrian rail can be dashed.
private struct RailPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

#Preview("Rail states") {
    HStack(alignment: .top, spacing: 24) {
        JourneyTimelineRail(
            above: .none,
            below: .pedestrian,
            bead: .terminus,
            state: .done
        )
        JourneyTimelineRail(
            above: .pedestrian,
            below: .line(colorHex: "FFCE00"),
            bead: .major,
            state: .done
        )
        JourneyTimelineRail(
            above: .line(colorHex: "FFCE00"),
            below: .line(colorHex: "FFCE00"),
            bead: .none,
            state: .current,
            cursorFraction: 0.45,
            isCursorLive: true
        )
        JourneyTimelineRail(
            above: .line(colorHex: "E3051C"),
            below: .none,
            bead: .major,
            state: .upcoming
        )
    }
    .frame(height: 160)
    .padding()
}

#Preview("Bulle qui descend") {
    @Previewable @State var fraction: Double = 0.1

    return VStack(spacing: 24) {
        JourneyTimelineRail(
            above: .line(colorHex: "0064B0"),
            below: .line(colorHex: "0064B0"),
            bead: .none,
            state: .current,
            cursorFraction: fraction,
            isCursorLive: true
        )
        .frame(height: 260)

        Button("Avancer") {
            fraction = fraction >= 0.9 ? 0.1 : fraction + 0.2
        }
    }
    .padding()
}
