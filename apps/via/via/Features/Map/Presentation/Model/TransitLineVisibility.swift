import Foundation

enum TransitLineVisibility {
    static let fullyVisibleSpanMeters = 15_000.0
    static let cityOverviewSpanMeters = 100_000.0
    static let regionalSpanMeters = 500_000.0
    static let maximumVisibleSpanMeters = 800_000.0
    static let cityOverviewOpacity = 0.45
    static let regionalOpacity = 0.18
    static let localLineWidth = 3.0
    static let cityOverviewLineWidth = 1.25
    static let regionalLineWidth = 0.75
    static let localLaneSpacing = 6.0
    static let cityOverviewLaneSpacing = 1.5
    static let collapsedLaneSpanMeters = 250_000.0

    /// Zoom-driven styles are quantized: every distinct value republishes the
    /// map snapshot and rebuilds every polyline, so a continuous curve would
    /// rebuild on each pinch frame. Steps small enough to read as a fade.
    static let opacityStep = 0.05
    static let lineWidthStep = 0.25

    static func opacity(for spanMeters: Double) -> Double {
        quantized(
            piecewiseLinear(spanMeters, through: [
                (fullyVisibleSpanMeters, 1),
                (cityOverviewSpanMeters, cityOverviewOpacity),
                (regionalSpanMeters, regionalOpacity),
                (maximumVisibleSpanMeters, 0),
            ]),
            step: opacityStep
        )
    }

    static func lineWidth(for spanMeters: Double) -> Double {
        quantized(
            piecewiseLinear(spanMeters, through: [
                (fullyVisibleSpanMeters, localLineWidth),
                (cityOverviewSpanMeters, cityOverviewLineWidth),
                (regionalSpanMeters, regionalLineWidth),
            ]),
            step: lineWidthStep
        )
    }

    static func quantized(_ value: Double, step: Double) -> Double {
        (value / step).rounded() * step
    }

    static func laneSpacing(for spanMeters: Double) -> Double {
        piecewiseLinear(spanMeters, through: [
            (fullyVisibleSpanMeters, localLaneSpacing),
            (cityOverviewSpanMeters, cityOverviewLaneSpacing),
            (collapsedLaneSpanMeters, 0),
        ])
    }

    /// Linear interpolation through breakpoints with ascending spans, clamped
    /// to the first value when zoomed in below the curve and to the last value
    /// beyond it. A non-finite span maps to the fully-zoomed-out end state.
    private static func piecewiseLinear(
        _ spanMeters: Double,
        through points: [(span: Double, value: Double)]
    ) -> Double {
        guard let first = points.first, let last = points.last else { return 0 }
        guard spanMeters.isFinite else { return last.value }
        guard spanMeters > first.span else { return first.value }
        guard spanMeters < last.span else { return last.value }

        for (lower, upper) in zip(points, points.dropFirst()) where spanMeters <= upper.span {
            let progress = (spanMeters - lower.span) / (upper.span - lower.span)
            return lower.value + progress * (upper.value - lower.value)
        }
        return last.value
    }
}
