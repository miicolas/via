import SwiftUI

extension ReportCategoryGroup {
    var title: String {
        switch self {
        case .safetyAndCrowding: "Sécurité et affluence"
        case .accessibilityAndEquipment: "Accessibilité et équipements"
        case .accessAndService: "Accès et service"
        }
    }

    var systemImage: String {
        switch self {
        case .safetyAndCrowding: "exclamationmark.bubble.fill"
        case .accessibilityAndEquipment: "figure.roll"
        case .accessAndService: "rectangle.portrait.and.arrow.forward"
        }
    }
}

extension ReportCategory {
    var compactTitle: String {
        switch self {
        case .pickpocket: "Pickpocket"
        case .crowding: "Affluence"
        case .restroomsClosed: "WC fermés"
        case .ticketMachinesUnavailable: "Distributeurs"
        case .wheelchairAccessUnavailable: "Accès PMR"
        case .elevatorsUnavailable: "Ascenseurs"
        case .escalatorUnavailable: "Escalator"
        case .validatorsUnavailable: "Portiques"
        case .entranceOrExitClosed: "Accès fermé"
        case .stopRelocated: "Arrêt déplacé"
        case .stopNotServed: "Arrêt non desservi"
        case .passengerInformationUnavailable: "Infos voyageurs"
        case .passageObstructed: "Passage bloqué"
        }
    }

    var title: String {
        switch self {
        case .pickpocket: "Pickpocket"
        case .crowding: "Affluence"
        case .restroomsClosed: "WC fermés"
        case .ticketMachinesUnavailable: "Distributeurs indisponibles"
        case .wheelchairAccessUnavailable: "Accès PMR impossible"
        case .elevatorsUnavailable: "Ascenseurs indisponibles"
        case .escalatorUnavailable: "Escalator indisponible"
        case .validatorsUnavailable: "Portiques indisponibles"
        case .entranceOrExitClosed: "Entrée ou sortie fermée"
        case .stopRelocated: "Arrêt déplacé"
        case .stopNotServed: "Arrêt non desservi"
        case .passengerInformationUnavailable: "Information indisponible"
        case .passageObstructed: "Passage obstrué"
        }
    }

    var systemImage: String {
        switch self {
        case .pickpocket: "figure.run"
        case .crowding: "person.3.fill"
        case .restroomsClosed: "figure.dress.line.vertical.figure"
        case .ticketMachinesUnavailable: "creditcard.fill"
        case .wheelchairAccessUnavailable: "figure.roll"
        case .elevatorsUnavailable: "arrow.up.arrow.down.square.fill"
        case .escalatorUnavailable: "figure.stairs"
        case .validatorsUnavailable: "rectangle.portrait.and.arrow.forward"
        case .entranceOrExitClosed: "door.left.hand.closed"
        case .stopRelocated: "arrowshape.right.fill"
        case .stopNotServed: "minus"
        case .passengerInformationUnavailable: "display.2"
        case .passageObstructed: "wrench.and.screwdriver.fill"
        }
    }

    var explanation: String {
        switch self {
        case .pickpocket:
            "Avertissez les voyageurs autour de vous."
        case .crowding:
            "Indiquez le niveau d’occupation que vous observez."
        case .restroomsClosed:
            "Les sanitaires de la station sont inaccessibles."
        case .ticketMachinesUnavailable:
            "Aucune borne ne permet d’acheter un titre."
        case .wheelchairAccessUnavailable:
            "Le parcours sans marche n’est pas praticable."
        case .elevatorsUnavailable:
            "Un ou plusieurs ascenseurs sont hors service."
        case .escalatorUnavailable:
            "Un escalator nécessaire est à l’arrêt."
        case .validatorsUnavailable:
            "Les portiques ou validateurs ne fonctionnent pas."
        case .entranceOrExitClosed:
            "Un accès à la station est fermé."
        case .stopRelocated:
            "Le point d’arrêt a changé d’emplacement."
        case .stopNotServed:
            "Les véhicules ne marquent pas l’arrêt."
        case .passengerInformationUnavailable:
            "Les écrans ou annonces ne fonctionnent pas."
        case .passageObstructed:
            "Des travaux ou un obstacle bloquent le passage."
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
        case .wheelchairAccessUnavailable:
            .orange
        case .stopRelocated, .stopNotServed, .passageObstructed:
            .orange
        }
    }
}

/// How Via attributes a live datum to the people behind it. The same sentence
/// was being written in five places, three of which dropped the noun and
/// printed "Signalé par 3"; the plural rule lives here now so they cannot
/// disagree again.
enum ReportAttribution {
    /// "3 personnes" / "1 personne"
    static func reporters(_ count: Int) -> String {
        "\(count) \(count == 1 ? "personne" : "personnes")"
    }

    static func source(_ source: ReportDataSource, reporterCount: Int?) -> String {
        guard source == .reported, let reporterCount else { return "Donnée habituelle" }
        return "Signalé par \(reporters(reporterCount))"
    }

    static func recovered(reporterCount: Int) -> String {
        "Rétabli selon \(reporters(reporterCount))"
    }

    /// The one sentence that says who a live row comes from, whichever it is.
    static func attribution(for incident: LiveReportIncident) -> String {
        incident.state == .recovered
            ? recovered(reporterCount: incident.reporterCount)
            : source(.reported, reporterCount: incident.reporterCount)
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
