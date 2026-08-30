import SwiftUI

/// One slice of the passenger-display rail. Consecutive slices meet edge to
/// edge, forming a single wide band with white station holes punched through.
///
/// A branched line plan reuses these vertical slices and draws only the angled
/// connectors separately. A leg read from a trip and a line read from the
/// Lignes tab therefore keep the same band width and station holes.
struct JourneyTimelineRail: View {
    let above: JourneyTimelineRailStyle
    let below: JourneyTimelineRailStyle
    let bead: JourneyTimelineBead
    /// What is wrong at this station, when anything is. A journey leaves it
    /// `.open`; a line plan is where the marks come from.
    var mark: JourneyTimelineBeadMark = .open
    /// A fresh GPS fix replaces this station's white hole with the live diode.
    var liveStopStatus: JourneyStopProgress.Status? = nil
    let state: JourneyTimelineNodeState
    var beadTopInset: CGFloat = 0

    static let width: CGFloat = 56

    /// Wide enough for the white station hole to remain visibly inset in the
    /// coloured band, like the platform displays used as reference.
    static let transitWidth: CGFloat = 26
    static let interruptedDash: [CGFloat] = [13, 8]

    private static func beadDiameter(
        for bead: JourneyTimelineBead,
        mark: JourneyTimelineBeadMark
    ) -> CGFloat {
        let base: CGFloat = switch bead {
        case .terminus, .major: 16
        case .minor: 14
        case .none: 0
        }
        // A marked hole carries a real pictogram, not colour alone. The extra
        // room keeps its white rim and lets the sign read at a glance.
        guard base > 0, mark != .open else { return base }
        return base + 7
    }

    private static let pedestrianWidth: CGFloat = 7

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
                .offset(y: beadPosition - renderedBeadSize / 2)
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: state)
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: above)
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: below)
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: mark)
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: liveStopStatus)
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
        case .start(let fill):
            let startY = max(0, beadPosition - Self.transitWidth / 2)
            let height = max(0, size.height - startY)

            band(
                fill,
                shape: UnevenRoundedRectangle(
                    topLeadingRadius: Self.transitWidth / 2,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: Self.transitWidth / 2,
                    style: .continuous
                ),
                height: height
            )
            .position(x: size.width / 2, y: startY + height / 2)

        case .middle(let fill):
            band(fill, shape: Rectangle(), height: size.height)
                .position(x: size.width / 2, y: size.height / 2)

        case .end(let fill):
            let height = min(size.height, beadPosition + Self.transitWidth / 2)

            band(
                fill,
                shape: UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: Self.transitWidth / 2,
                    bottomTrailingRadius: Self.transitWidth / 2,
                    topTrailingRadius: 0,
                    style: .continuous
                ),
                height: height
            )
            .position(x: size.width / 2, y: height / 2)

        case .transition(let aboveFill, let belowFill):
            VStack(spacing: 0) {
                band(aboveFill, shape: Rectangle(), height: beadPosition)
                band(belowFill, shape: Rectangle(), height: max(0, size.height - beadPosition))
            }
            .frame(width: Self.transitWidth, height: size.height)
            .position(x: size.width / 2, y: size.height / 2)

        case .none:
            EmptyView()
        }
    }

    /// A cut keeps the width of a running band and loses its continuity: the
    /// same stroke chopped into dashes, so an interruption reads as a broken
    /// rail rather than as a rail that merely changed colour.
    private func band(_ fill: BandFill, shape: some Shape, height: CGFloat) -> some View {
        Rectangle()
            .fill(fill.tint.opacity(0.86))
            // Keep the material's horizontal boundaries outside this row.
            // Adjacent slices then read as one long piece of glass instead of
            // a stack of individually outlined tiles.
            .frame(
                width: Self.transitWidth,
                height: height + Self.transitWidth * 2
            )
            .glassEffect(
                .regular.tint(fill.tint.opacity(0.32)),
                in: Rectangle()
            )
            .overlay {
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.22), location: 0),
                                .init(color: .clear, location: 0.42),
                                .init(color: .black.opacity(0.08), location: 1),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .blendMode(.softLight)
            }
            .frame(width: Self.transitWidth, height: height)
            .clipped()
            .mask { shape }
            .mask {
                if fill.isBroken {
                    JourneyRailPath()
                        .stroke(
                            Color.black,
                            style: StrokeStyle(
                                lineWidth: Self.transitWidth,
                                dash: Self.interruptedDash
                            )
                        )
                        .frame(width: Self.transitWidth, height: height)
                } else {
                    Rectangle()
                }
            }
            .opacity(transitOpacity)
    }

    private var transitBandRole: TransitBandRole {
        switch (above.band, below.band) {
        case let (aboveFill?, belowFill?) where aboveFill == belowFill:
            .middle(aboveFill)
        case let (aboveFill?, belowFill?):
            .transition(above: aboveFill, below: belowFill)
        case let (_, belowFill?):
            .start(belowFill)
        case let (aboveFill?, _):
            .end(aboveFill)
        default:
            .none
        }
    }

    private var transitOpacity: Double {
        state == .done ? 0.42 : 1
    }

    private var beadPosition: CGFloat {
        beadCenter + beadTopInset
    }

    private var beadSize: CGFloat {
        Self.beadDiameter(for: bead, mark: mark)
    }

    private var renderedBeadSize: CGFloat {
        liveStopStatus == nil ? beadSize : beadSize + 4
    }

    /// A hole is punched *through* something. With no band under it there is
    /// nothing to punch, and a white disc on a white card would be no bead at
    /// all — so an unrailed node wears the disc itself instead.
    @ViewBuilder
    private var beadView: some View {
        switch bead {
        case .none:
            EmptyView()
        case .minor, .major, .terminus:
            if hasTransitRail {
                stationHole
            } else {
                unrailedBead
            }
        }
    }

    private var unrailedBead: some View {
        Circle()
            .fill(mark.condition?.tint ?? beadTint)
            .overlay {
                switch mark {
                case .open:
                    Circle()
                        .fill(.white)
                        .frame(width: beadSize * 0.38, height: beadSize * 0.38)
                case .warned(let condition):
                    markerSymbol("exclamationmark", condition: condition)
                case .closed(let condition):
                    markerSymbol("xmark", condition: condition)
                }
            }
            .frame(width: beadSize, height: beadSize)
            .opacity(state == .done ? 0.5 : 1)
    }

    @ViewBuilder
    private var stationHole: some View {
        if let liveStopStatus {
            JourneyPositionIndicatorView(
                status: liveStopStatus,
                diameter: beadSize + 4
            )
        } else {
            Circle()
                .fill(.white)
                .frame(width: beadSize, height: beadSize)
                .overlay { markGlyph }
                .opacity(state == .done ? 0.72 : 1)
        }
    }

    /// The white hole keeps its rim whatever the mark: the inset coloured disc
    /// can never disappear into a band of the same colour, while its symbol
    /// makes the disruption readable without relying on colour.
    @ViewBuilder
    private var markGlyph: some View {
        switch mark {
        case .open:
            EmptyView()
        case .warned(let condition):
            markerDisc("exclamationmark", condition: condition)
        case .closed(let condition):
            markerDisc("xmark", condition: condition)
        }
    }

    private func markerDisc(_ systemImage: String, condition: LineCondition) -> some View {
        Circle()
            .fill(condition.tint)
            .padding(2)
            .overlay {
                markerSymbol(systemImage, condition: condition)
            }
    }

    private func markerSymbol(_ systemImage: String, condition: LineCondition) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: beadSize * 0.5, weight: .black))
            .foregroundStyle(condition == .attention ? Color.black.opacity(0.72) : .white)
    }

    private var beadTint: Color {
        below.band?.tint ?? above.band?.tint ?? Color.accentColor
    }

    private var hasTransitRail: Bool {
        above.band != nil || below.band != nil
    }

    private func strokeOpacity(for style: JourneyTimelineRailStyle) -> Double {
        guard state == .done else { return 1 }
        return style.band == nil ? 0.46 : 0.42
    }
}

/// How one band is painted: its colour, and whether the service running over
/// it is interrupted.
private struct BandFill: Equatable {
    let tint: Color
    let isBroken: Bool
}

private enum TransitBandRole {
    case start(BandFill)
    case middle(BandFill)
    case end(BandFill)
    case transition(above: BandFill, below: BandFill)
    case none
}

extension JourneyTimelineRailStyle {
    fileprivate var band: BandFill? {
        switch self {
        case .line(let colorHex):
            BandFill(
                tint: Color(transitHex: colorHex ?? "", fallback: .accentColor),
                isBroken: false
            )
        case .cut(let condition):
            BandFill(tint: condition.tint, isBroken: true)
        case .pedestrian, .none:
            nil
        }
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
