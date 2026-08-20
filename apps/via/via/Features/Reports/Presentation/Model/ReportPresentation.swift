import SwiftUI

extension ReportCategoryGroup {
    var title: String {
        switch self {
        case .safetyAndCrowding: "Sécurité et affluence"
        case .accessibilityAndEquipment: "Accessibilité et équipements"
        case .accessAndService: "Accès et service"
        }
    }
}

extension ReportCategory {
    var title: String {
        switch self {
        case .pickpocket: "Pickpocket"
        case .crowding: "Affluence"
        case .restroomsClosed: "WC fermés"
        case .ticketMachinesUnavailable: "Aucun distributeur de tickets fonctionnel"
        case .elevatorsUnavailable: "Certains ascenseurs indisponibles"
        case .escalatorUnavailable: "Escalator indisponible"
        case .validatorsUnavailable: "Portiques ou validateurs indisponibles"
        case .entranceOrExitClosed: "Entrée ou sortie fermée"
        case .stopRelocated: "Arrêt déplacé ici"
        case .stopNotServed: "Arrêt non desservi"
        case .passengerInformationUnavailable: "Écrans ou annonces indisponibles"
        case .passageObstructed: "Travaux ou passage obstrué"
        }
    }

    var systemImage: String {
        switch self {
        case .pickpocket: "figure.run"
        case .crowding: "person.3.fill"
        case .restroomsClosed: "figure.dress.line.vertical.figure"
        case .ticketMachinesUnavailable: "creditcard.fill"
        case .elevatorsUnavailable: "arrow.up.arrow.down.square.fill"
        case .escalatorUnavailable: "figure.stairs"
        case .validatorsUnavailable: "rectangle.portrait.and.arrow.forward"
        case .entranceOrExitClosed: "door.left.hand.closed"
        case .stopRelocated: "arrowshape.right.fill"
        case .stopNotServed: "minus.circle.fill"
        case .passengerInformationUnavailable: "display.2"
        case .passageObstructed: "wrench.and.screwdriver.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pickpocket: .purple
        case .crowding, .entranceOrExitClosed: .red
        case .restroomsClosed,
             .ticketMachinesUnavailable,
             .elevatorsUnavailable,
             .escalatorUnavailable,
             .validatorsUnavailable,
             .passengerInformationUnavailable:
            .blue
        case .stopRelocated, .stopNotServed, .passageObstructed:
            .orange
        }
    }
}

extension CrowdingLevel {
    var systemImage: String {
        switch self {
        case .low: "person.fill"
        case .moderate: "person.2.fill"
        case .high: "person.3.fill"
        case .saturated: "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .low: .green
        case .moderate: .blue
        case .high: .orange
        case .saturated: .red
        }
    }
}
