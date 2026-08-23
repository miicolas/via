import Foundation

enum SavedDestinationSymbols {
    static let choices = [
        "mappin",
        "house.fill",
        "briefcase.fill",
        "graduationcap.fill",
        "figure.run",
        "dumbbell.fill",
        "cart.fill",
        "cross.case.fill",
        "fork.knife",
        "cup.and.saucer.fill",
        "tram.fill",
        "airplane",
        "car.fill",
        "building.2.fill",
        "tree.fill",
        "person.2.fill",
    ]

    static func suggestion(for result: SearchResult) -> String {
        switch result {
        case .station:
            "tram.fill"
        case .address:
            "mappin"
        }
    }

    static func resolved(_ symbol: String, fallback: String = "mappin") -> String {
        choices.contains(symbol) ? symbol : fallback
    }
}
