import Foundation

enum ComingSoonFeature: String, CaseIterable, Hashable, Identifiable {
    case notifications
    case automations
    case extensions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notifications: "Notifications"
        case .automations: "Automatisations"
        case .extensions: "Extensions et widgets"
        }
    }

    var message: String {
        switch self {
        case .notifications:
            "Les alertes personnalisées arriveront dans une prochaine version."
        case .automations:
            "Les automatisations de trajets sont en préparation."
        case .extensions:
            "Les widgets et extensions Apple seront bientôt disponibles."
        }
    }

    var systemImage: String {
        switch self {
        case .notifications: "bell.badge"
        case .automations: "bolt.badge.clock"
        case .extensions: "puzzlepiece.extension"
        }
    }
}
