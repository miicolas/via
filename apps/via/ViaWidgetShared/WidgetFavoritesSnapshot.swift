import Foundation

/// A favourite the traveller can start from the Home Screen, the Lock Screen
/// or Control Centre.
///
/// Widget-shaped on purpose, the way `JourneyActivityAttributes.LineBadge` is:
/// the extension does not link the app's account models, so what crosses the
/// App Group is a flat value carrying its own identifier and everything a tile
/// needs to draw itself.
struct WidgetFavoriteJourney: Codable, Sendable, Hashable, Identifiable {
    /// The token `ViaWidgetLink.favoriteJourney(id:)` puts in the deep link and
    /// the app resolves back to a destination. Also the widget entity's id, so
    /// a widget configured to a favourite keeps pointing at it across reloads.
    let id: String
    /// What the traveller named it — "Maison", "Travail", "Salle de sport".
    let label: String
    /// Where it actually goes, shown under the label so two favourites named
    /// alike stay distinguishable.
    let destinationName: String
    let systemImage: String

    init(id: String, label: String, destinationName: String, systemImage: String) {
        self.id = id
        self.label = label
        self.destinationName = destinationName
        self.systemImage = systemImage
    }
}

/// The service level of a saved line, mirroring the app's `LineCondition`.
///
/// Declared a second time rather than shared: the extension links neither the
/// app's domain nor its API client. `WidgetFavoritesProjectionTests` asserts
/// the two case sets stay identical, so a fifth condition cannot reach the app
/// without reaching the widgets.
enum WidgetLineCondition: String, Codable, Sendable, Hashable, CaseIterable {
    case normal
    case attention
    case disrupted
    case suspended

    var title: String {
        switch self {
        case .normal: "Service normal"
        case .attention: "Information"
        case .disrupted: "Perturbée"
        case .suspended: "Interrompue"
        }
    }

    var systemImage: String {
        switch self {
        case .normal: "checkmark.circle.fill"
        case .attention: "info.circle.fill"
        case .disrupted: "exclamationmark.triangle.fill"
        case .suspended: "xmark.octagon.fill"
        }
    }

    /// Lower values appear first wherever travellers scan for problems.
    var displayPriority: Int {
        switch self {
        case .suspended: 0
        case .disrupted: 1
        case .attention: 2
        case .normal: 3
        }
    }

    var isDisrupted: Bool { self != .normal }
}

/// One saved line, ready to draw as a badge with its condition mark.
struct WidgetLineStatus: Codable, Sendable, Hashable, Identifiable {
    let routeID: String
    let shortName: String
    /// The French mode name, resolved app-side so the extension never has to
    /// own a second copy of `TransitMode`'s wording.
    let modeName: String
    let colorHex: String
    let textColorHex: String
    let condition: WidgetLineCondition
    /// Title of the worst active disruption; `nil` when the line runs normally.
    let summary: String?
    /// A planned closure starts within the week. Worth a mark even on a line
    /// that runs normally right now.
    let hasUpcomingClosure: Bool

    var id: String { routeID }

    init(
        routeID: String,
        shortName: String,
        modeName: String,
        colorHex: String,
        textColorHex: String,
        condition: WidgetLineCondition,
        summary: String?,
        hasUpcomingClosure: Bool
    ) {
        self.routeID = routeID
        self.shortName = shortName
        self.modeName = modeName
        self.colorHex = colorHex
        self.textColorHex = textColorHex
        self.condition = condition
        self.summary = summary
        self.hasUpcomingClosure = hasUpcomingClosure
    }

    private enum CodingKeys: String, CodingKey {
        case routeID = "routeId"
        case shortName, modeName, colorHex, textColorHex, condition, summary, hasUpcomingClosure
    }
}

/// Everything the widgets read, written by the app in one blob.
///
/// One value rather than a key per list: a widget reload that landed between
/// two writes would otherwise draw favourites from one moment and lines from
/// another.
struct WidgetFavoritesSnapshot: Codable, Sendable, Hashable {
    var journeys: [WidgetFavoriteJourney]
    /// The traveller's saved lines, worst condition first.
    var lines: [WidgetLineStatus]
    /// When the app last wrote this blob.
    var capturedAt: Date
    /// When the *statuses* were read from the network. Distinct from
    /// `capturedAt`, which also moves when only a favourite was renamed: a
    /// widget reporting freshness has to report the age of the conditions.
    var linesFetchedAt: Date?

    init(
        journeys: [WidgetFavoriteJourney] = [],
        lines: [WidgetLineStatus] = [],
        capturedAt: Date = .distantPast,
        linesFetchedAt: Date? = nil
    ) {
        self.journeys = journeys
        self.lines = lines
        self.capturedAt = capturedAt
        self.linesFetchedAt = linesFetchedAt
    }

    static let empty = WidgetFavoritesSnapshot()
}
