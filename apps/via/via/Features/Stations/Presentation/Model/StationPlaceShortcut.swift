import Foundation

enum StationPlaceShortcut: String, CaseIterable, Hashable, Identifiable, Sendable {
    case currentLocation
    case home
    case work

    var id: Self { self }

    var title: String {
        switch self {
        case .currentLocation:
            "Ma position"
        case .home:
            "Maison"
        case .work:
            "Travail"
        }
    }

    var systemImage: String {
        switch self {
        case .currentLocation:
            "location.fill"
        case .home:
            "house.fill"
        case .work:
            "briefcase.fill"
        }
    }
}
