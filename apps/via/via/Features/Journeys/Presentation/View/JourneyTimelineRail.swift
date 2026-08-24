import SwiftUI

/// One slice of the passenger-display rail. Consecutive slices meet edge to
/// edge, forming a single wide band with white station holes punched through.
struct JourneyTimelineRail: View {
    let above: JourneyTimelineRailStyle
    let below: JourneyTimelineRailStyle
    let bead: JourneyTimelineBead
    let state: JourneyTimelineNodeState
    var cursorFraction: Double?
    var isCursorLive = false
    var beadTopInset: CGFloat = 0

    static let width: CGFloat = 56

    /// Wide enough for the white station hole to remain visibly inset in the
    /// coloured band, like the platform displays used as reference.
    private static let transitWidth: CGFloat = 26
    private static let pedestrianWidth: CGFloat = 7
    private static let cursorTint = Color.blue
    private static let cursorSize: CGFloat = 28

    @ScaledMetric(relativeTo: .headline) private var beadCenter: CGFloat = 22
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                pedestrianStroke(above)
                    .frame(height: beadPosition)

                pedestrianStroke(below)
                    .frame(maxHeight: .infinity)
            }

            GeometryReader { proxy in
                transitBand(in: proxy.size)
            }
        }
        .frame(width: Self.width)
        .overlay(alignment: .top) {
            beadView
                .offset(y: beadPosition - beadSize / 2)
        }
        .overlay { cursorView }
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: state)
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: above)
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: below)
        .accessibilityHidden(true)
    }

    private func pedestrianStroke(_ style: JourneyTimelineRailStyle) -> some View {
        ZStack {
            JourneyRailPath()
                .stroke(
                    Color.secondary.opacity(0.75),
                    style: StrokeStyle(
                        lineWidth: Self.pedestrianWidth,
                        lineCap: .round,
                        dash: [1, 11]
                    )
                )
                .frame(width: Self.pedestrianWidth)
                .opacity(style.isPedestrian ? strokeOpacity(for: style) : 0)
        }
        .frame(width: Self.width)
    }

    /// The coloured rail is one of three deliberate pieces. A start owns its
    /// rounded top, a middle is edge-to-edge, and an end owns its rounded
    /// bottom. Consecutive rows therefore meet without spacer seams.
    @ViewBuilder
    private func transitBand(in size: CGSize) -> some View {
        switch transitBandRole {
        case .start(let colorHex):
            let startY = max(0, beadPosition - Self.transitWidth / 2)
            let height = max(0, size.height - startY)

            UnevenRoundedRectangle(
                topLeadingRadius: Self.transitWidth / 2,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: Self.transitWidth / 2,
                style: .continuous
            )
            .fill(lineTint(colorHex))
            .frame(width: Self.transitWidth, height: height)
            .position(x: size.width / 2, y: startY + height / 2)
            .opacity(transitOpacity)

        case .middle(let colorHex):
            Rectangle()
                .fill(lineTint(colorHex))
                .frame(width: Self.transitWidth, height: size.height)
                .position(x: size.width / 2, y: size.height / 2)
                .opacity(transitOpacity)

        case .end(let colorHex):
            let height = min(size.height, beadPosition + Self.transitWidth / 2)

            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: Self.transitWidth / 2,
                bottomTrailingRadius: Self.transitWidth / 2,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(lineTint(colorHex))
            .frame(width: Self.transitWidth, height: height)
            .position(x: size.width / 2, y: height / 2)
            .opacity(transitOpacity)

        case .transition(let aboveHex, let belowHex):
            VStack(spacing: 0) {
                Rectangle()
                    .fill(lineTint(aboveHex))
                    .frame(height: beadPosition)

                Rectangle()
                    .fill(lineTint(belowHex))
                    .frame(maxHeight: .infinity)
            }
            .frame(width: Self.transitWidth, height: size.height)
            .position(x: size.width / 2, y: size.height / 2)
            .opacity(transitOpacity)

        case .none:
            EmptyView()
        }
    }

    private var transitBandRole: TransitBandRole {
        switch (above, below) {
        case let (.line(aboveHex), .line(belowHex)) where aboveHex == belowHex:
            .middle(colorHex: aboveHex)
        case let (.line(aboveHex), .line(belowHex)):
            .transition(aboveHex: aboveHex, belowHex: belowHex)
        case let (_, .line(colorHex)):
            .start(colorHex: colorHex)
        case let (.line(colorHex), _):
            .end(colorHex: colorHex)
        default:
            .none
        }
    }

    private func lineTint(_ colorHex: String?) -> Color {
        Color(transitHex: colorHex ?? "", fallback: .accentColor)
    }

    private var transitOpacity: Double {
        state == .done ? 0.42 : 1
    }

    private var beadPosition: CGFloat {
        beadCenter + beadTopInset
    }

    private var beadSize: CGFloat {
        switch bead {
        case .terminus, .major: 16
        case .minor: 14
        case .none: 0
        }
    }

    @ViewBuilder
    private var beadView: some View {
        switch bead {
        case .none:
            EmptyView()
        case .minor, .major:
            stationHole
        case .terminus:
            if hasTransitRail {
                stationHole
            } else {
                Circle()
                    .fill(beadTint)
                    .overlay {
                        Circle()
                            .fill(.white)
                            .frame(width: beadSize * 0.38, height: beadSize * 0.38)
                    }
                    .frame(width: beadSize, height: beadSize)
                    .opacity(state == .done ? 0.5 : 1)
            }
        }
    }

    private var stationHole: some View {
        Circle()
            .fill(.white)
            .frame(width: beadSize, height: beadSize)
            .opacity(state == .done ? 0.72 : 1)
    }

    private var beadTint: Color {
        below.lineTint ?? above.lineTint ?? Color.accentColor
    }

    private var hasTransitRail: Bool {
        above.isLine || below.isLine
    }

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
            .transition(.scale(scale: 0.5).combined(with: .opacity))
            .animation(reduceMotion ? nil : .smooth(duration: 0.5), value: cursorFraction)
        }
    }

    private func strokeOpacity(for style: JourneyTimelineRailStyle) -> Double {
        guard state == .done else { return 1 }
        return style.isLine ? 0.42 : 0.46
    }
}

private enum TransitBandRole {
    case start(colorHex: String?)
    case middle(colorHex: String?)
    case end(colorHex: String?)
    case transition(aboveHex: String?, belowHex: String?)
    case none
}

extension JourneyTimelineRailStyle {
    fileprivate var isLine: Bool {
        if case .line = self { return true }
        return false
    }

    fileprivate var isPedestrian: Bool {
        self == .pedestrian
    }

    var lineTint: Color? {
        guard case .line(let colorHex) = self else { return nil }
        return Color(transitHex: colorHex ?? "", fallback: .accentColor)
    }
}

private struct JourneyRailPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
