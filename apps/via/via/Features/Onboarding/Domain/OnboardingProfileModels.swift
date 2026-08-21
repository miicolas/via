import Foundation

enum TransitPassKind: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case navigoAnnual
    case navigoMonthlyOrWeekly
    case imagineR
    case navigoLibertePlus
    case navigoEasyOrTickets
    case noneOrOther

    var id: Self { self }

    var title: String {
        switch self {
        case .navigoAnnual: "Navigo Annuel"
        case .navigoMonthlyOrWeekly: "Navigo Mois ou Semaine"
        case .imagineR: "Imagine R"
        case .navigoLibertePlus: "Navigo Liberté+"
        case .navigoEasyOrTickets: "Navigo Easy / tickets"
        case .noneOrOther: "Aucun / autre"
        }
    }

    var subtitle: String {
        switch self {
        case .navigoAnnual: "Je me déplace toute l’année"
        case .navigoMonthlyOrWeekly: "Mon forfait change selon les périodes"
        case .imagineR: "Mon abonnement étudiant ou scolaire"
        case .navigoLibertePlus: "Je paie mes trajets à l’usage"
        case .navigoEasyOrTickets: "Un carnet, un ticket ou une carte Easy"
        case .noneOrOther: "Je préfère ne pas préciser"
        }
    }

    var systemImage: String {
        switch self {
        case .navigoAnnual: "calendar.badge.clock"
        case .navigoMonthlyOrWeekly: "calendar"
        case .imagineR: "graduationcap.fill"
        case .navigoLibertePlus: "arrow.triangle.2.circlepath"
        case .navigoEasyOrTickets: "ticket.fill"
        case .noneOrOther: "questionmark.circle"
        }
    }
}

enum IleDeFrancePresence: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case resident
    case visitor
    case both

    var id: Self { self }

    var title: String {
        switch self {
        case .resident: "J’habite ici"
        case .visitor: "Je suis de passage"
        case .both: "Un peu des deux"
        }
    }

    var subtitle: String {
        switch self {
        case .resident: "Je connais déjà le réseau francilien"
        case .visitor: "Je découvre Paris et l’Île-de-France"
        case .both: "Je vis ici, mais je reçois aussi des proches"
        }
    }

    var systemImage: String {
        switch self {
        case .resident: "house.fill"
        case .visitor: "suitcase.fill"
        case .both: "arrow.left.arrow.right"
        }
    }
}

enum TransitUsageFrequency: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case daily
    case regular
    case occasional

    var id: Self { self }

    var title: String {
        switch self {
        case .daily: "Tous les jours"
        case .regular: "Quelques fois par semaine"
        case .occasional: "Occasionnellement"
        }
    }

    var subtitle: String {
        switch self {
        case .daily: "Travail, études ou trajets du quotidien"
        case .regular: "Des habitudes, sans trajet tous les jours"
        case .occasional: "Sorties, rendez-vous ou voyages"
        }
    }

    var systemImage: String {
        switch self {
        case .daily: "sun.max.fill"
        case .regular: "calendar.badge.repeat"
        case .occasional: "sparkles"
        }
    }
}

struct OnboardingProfileAnswers: Codable, Equatable, Hashable, Sendable {
    let pass: TransitPassKind
    let presence: IleDeFrancePresence
    let frequency: TransitUsageFrequency
}
