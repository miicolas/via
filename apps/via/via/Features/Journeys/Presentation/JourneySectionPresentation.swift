extension JourneySection.Kind {
    var systemImage: String {
        switch self {
        case .walk: "figure.walk"
        case .wait: "clock"
        case .transfer: "arrow.triangle.turn.up.right.diamond"
        case .transit: "tram.fill"
        }
    }

    var isVisuallySecondary: Bool {
        self == .wait || self == .transfer
    }
}

extension JourneyRoute {
    /// Shared bridge to the neutral badge model `LineBadgeView` renders.
    var badge: RouteBadge {
        RouteBadge(
            id: id,
            shortName: shortName,
            mode: mode,
            colorHex: colorHex,
            textColorHex: textColorHex
        )
    }
}
