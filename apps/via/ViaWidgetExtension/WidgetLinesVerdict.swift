import SwiftUI

/// The one sentence at the top of the saved-lines widget.
///
/// A widget is read at arm's length: the verdict has to be legible before any
/// badge is. Worded once here so the small, medium, large and Lock Screen sizes
/// cannot disagree about what "tout roule" means.
struct WidgetLinesVerdict {
    let title: String
    let systemImage: String
    let tint: Color

    init(lines: [WidgetLineStatus]) {
        let disrupted = lines.count { $0.condition.isDisrupted }
        let worst = lines
            .filter { $0.condition.isDisrupted }
            .min { $0.condition.displayPriority < $1.condition.displayPriority }?
            .condition

        switch disrupted {
        case 0:
            title = "Tout roule"
            systemImage = "checkmark.circle.fill"
            tint = .green
        case 1:
            title = "1 ligne perturbée"
            systemImage = worst?.systemImage ?? "exclamationmark.triangle.fill"
            tint = worst?.tint ?? .orange
        default:
            title = "\(disrupted) lignes perturbées"
            systemImage = worst?.systemImage ?? "exclamationmark.triangle.fill"
            tint = worst?.tint ?? .orange
        }
    }
}

/// How old the conditions on screen are, when that is worth saying.
///
/// Silent while the board is fresh: a timestamp under every tile would train
/// the eye to ignore it, and it is only news once the widget has been unable
/// to refresh for a while.
enum WidgetLinesFreshness {
    static let staleAfter: TimeInterval = 45 * 60

    static func caption(refreshedAt: Date?, now: Date = .now) -> String? {
        guard let refreshedAt else { return "État non disponible" }
        guard now.timeIntervalSince(refreshedAt) > staleAfter else { return nil }

        return "Mis à jour \(refreshedAt.formatted(.relative(presentation: .named)))"
    }
}
