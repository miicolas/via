import Foundation

enum FriendAlertLevel: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case none
    case justLanded
    case basics
    case everything

    var id: Self { self }

    var title: String {
        switch self {
        case .none: "Aucune"
        case .justLanded: "Atterrissage"
        case .basics: "Essentiel"
        case .everything: "Tout"
        }
    }

    var explanation: String {
        switch self {
        case .none:
            "Aucune alerte. Consulte simplement leurs vols dans Metyro."
        case .justLanded:
            "Préviens-moi uniquement quand ils atterrissent."
        case .basics:
            "Ajoute les perturbations majeures, le décollage, l’arrivée et le matin du voyage."
        case .everything:
            "Toutes les alertes : check-in, changement de porte, perturbations, bagages, etc."
        }
    }

    var systemImage: String {
        switch self {
        case .none: "bell.slash.fill"
        case .justLanded: "airplane.arrival"
        case .basics: "bell.fill"
        case .everything: "bell.badge.fill"
        }
    }
}
