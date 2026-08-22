import SwiftUI

/// What an `EmptyStateView` says, apart from how it is drawn.
///
/// Splitting the description from the view is what lets the recurring dead ends
/// — no favourite, no result, no network — exist as named values instead of as
/// four screens each spelling out their own French. A screen that needs its own
/// sentence still builds one by hand; a screen that hits a case Via has already
/// worded should not get to word it differently.
struct EmptyState {
    /// How loud the column is. `.standard` is the grey dead end every screen
    /// shares; `.ai` is the Apple Intelligence surface — a glass disc in the
    /// shared purple, a rounded title, and metrics left to the sheet around it.
    enum Emphasis {
        case standard
        case ai
    }

    /// `nil` draws no glyph. Stations does this: the screen is already a map of
    /// symbols, and a 44-point one on top only repeats them.
    var systemImage: String?
    var title: String
    var message: String?
    var emphasis: Emphasis = .standard
    /// Replaces the glyph and title with `LoadingStatus`: still looking, not
    /// yet empty.
    var isBusy: Bool = false
}

// MARK: - The dead ends Via has already worded

extension EmptyState {
    /// No message: the way out is a control on another screen, so the sentence
    /// belongs to an `EmptyStateHint` that can carry that control's symbol
    /// inline instead of describing it in words.
    static let noNotificationSchedules = EmptyState(
        systemImage: "calendar.badge.plus",
        title: "Aucune programmation",
        message: "Ajoutez un rappel domicile–travail ou un résumé quotidien pour ne plus avoir à y penser."
    )

    static let noFollowedLines = EmptyState(
        systemImage: "tram",
        title: "Aucune ligne suivie",
        message: "Suivez une ligne depuis sa fiche pour recevoir ses perturbations et son retour à la normale."
    )

    static let emptyInbox = EmptyState(
        systemImage: "bell",
        title: "Tout est calme",
        message: "Les informations importantes pour vos trajets apparaîtront ici."
    )

    static let notificationsDenied = EmptyState(
        systemImage: "bell.slash",
        title: "Notifications désactivées",
        message: "Autorisez les notifications dans Réglages pour recevoir les alertes de Via."
    )

    static let noFavorites = EmptyState(
        systemImage: "star",
        title: "Aucune station favorite",
    )

    /// Quoting the query back is what tells the traveller the search ran on what
    /// they think they typed — the usual cause of an empty result is a typo.
    static func noResults(
        query: String? = nil,
        message: String? = "Essayez un autre nom de station ou d’adresse.",
    ) -> EmptyState {
        let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return EmptyState(
            systemImage: "magnifyingglass",
            title: trimmed.isEmpty ? "Aucun résultat" : "Aucun résultat pour « \(trimmed) »",
            message: message,
        )
    }

    static func offline(
        title: String,
        message: String = "Vérifiez votre connexion puis réessayez.",
    ) -> EmptyState {
        EmptyState(systemImage: "wifi.exclamationmark", title: title, message: message)
    }

    /// Everything is there, the filters are hiding it. Distinct from
    /// `noResults` — nothing was searched for — and from `unavailable`: the way
    /// out is a control the traveller already set, not a retry.
    static func filtered(
        title: String,
        message: String
    ) -> EmptyState {
        EmptyState(
            systemImage: "line.3.horizontal.decrease",
            title: title,
            message: message
        )
    }

    static func unavailable(title: String, message: String) -> EmptyState {
        EmptyState(systemImage: "exclamationmark.triangle", title: title, message: message)
    }

    /// The message stays a parameter: what the traveller should do about a
    /// missing position depends on what the screen was about to use it for.
    static func locationBlocked(
        title: String = "Position indisponible",
        message: String,
    ) -> EmptyState {
        EmptyState(systemImage: "location.slash", title: title, message: message)
    }

    static let accessibilityUnavailable = EmptyState(
        systemImage: "figure.roll",
        title: "Données PMR indisponibles",
        message: "La source d’accessibilité n’est pas disponible. Modifie le filtre PMR ou réessaie plus tard.",
    )

    static let noAccessibleRoute = EmptyState(
        systemImage: "figure.roll",
        title: "Aucun trajet PMR vérifié",
        message: """
        Aucune combinaison de gares accessibles ne respecte cette recherche. \
        Modifie la destination ou désactive le filtre de trajet PMR.
        """,
    )

    static func searching(_ label: String = "Recherche…") -> EmptyState {
        EmptyState(title: label, isBusy: true)
    }

    static func ai(systemImage: String, title: String, message: String) -> EmptyState {
        EmptyState(
            systemImage: systemImage,
            title: title,
            message: message,
            emphasis: .ai,
        )
    }
}

// MARK: - Metrics

extension EmptyState.Emphasis {
    var spacing: CGFloat {
        switch self {
        case .standard: 10
        case .ai: 22
        }
    }

    var textSpacing: CGFloat {
        switch self {
        case .standard: 10
        case .ai: 8
        }
    }

    var titleFont: Font {
        switch self {
        case .standard: .title2.weight(.semibold)
        case .ai: .system(.title2, design: .rounded).weight(.bold)
        }
    }

    var titleColor: Color {
        switch self {
        case .standard: .secondary
        case .ai: .primary
        }
    }

    var messageFont: Font {
        switch self {
        case .standard: .body
        case .ai: .callout
        }
    }

    /// A dead end is a paragraph, and a paragraph the width of an iPad is
    /// unreadable. The AI sheet already caps and pads its own content, so it
    /// keeps its metrics rather than being capped twice.
    var maxWidth: CGFloat? {
        switch self {
        case .standard: 360
        case .ai: nil
        }
    }

    var insets: EdgeInsets {
        switch self {
        case .standard: EdgeInsets(top: 28, leading: 24, bottom: 28, trailing: 24)
        case .ai: EdgeInsets()
        }
    }
}
