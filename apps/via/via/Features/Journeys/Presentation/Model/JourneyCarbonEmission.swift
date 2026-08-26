import Foundation

/// Estimated passenger CO₂e for a journey, using the mode factors published
/// by Île-de-France Mobilités in its emission dataset.
struct JourneyCarbonEmission: Sendable, Equatable, Hashable {
    let grams: Double
    let transitDistanceMeters: Double

    /// The factors from IDFM's `CO2e/voy/km par mode de transport` column,
    /// expressed in grams of CO₂e per passenger-kilometre.
    ///
    /// Source: https://prim.iledefrance-mobilites.fr/fr/jeux-de-donnees/
    /// emission-de-co2e-par-voyageur-kilometre-sur-le-reseau
    static func gramsPerPassengerKilometer(for mode: TransitMode) -> Double {
        switch mode {
        case .metro: 3.8
        case .rer: 5.5
        case .transilien: 6.6
        case .tram: 3.2
        case .bus: 92.0
        }
    }

    static func estimate(for journey: Journey) -> Self {
        let contributions = journey.sections.compactMap { section -> (distance: Double, factor: Double)? in
            guard section.kind == .transit,
                  let mode = section.route?.mode
            else { return nil }

            let distance = pathDistance(of: section)
            guard distance.isFinite, distance > 0 else { return nil }
            return (
                distance: distance,
                factor: gramsPerPassengerKilometer(for: mode)
            )
        }

        return Self(
            grams: contributions.reduce(0) { total, contribution in
                total + contribution.distance / 1_000 * contribution.factor
            },
            transitDistanceMeters: contributions.reduce(0) { total, contribution in
                total + contribution.distance
            }
        )
    }

    var displayText: String {
        JourneyFormatting.carbonEmission(grams: grams)
    }

    var accessibilityText: String {
        JourneyFormatting.carbonEmissionAccessibility(grams: grams)
    }

    private static func pathDistance(of section: JourneySection) -> Double {
        let coordinates = section.geometry.count >= 2
            ? section.geometry
            : [section.from.coordinate, section.to.coordinate]

        return zip(coordinates, coordinates.dropFirst()).reduce(0) { distance, pair in
            distance + pair.0.metersAway(from: pair.1)
        }
    }
}

extension Journey {
    var carbonEmission: JourneyCarbonEmission {
        JourneyCarbonEmission.estimate(for: self)
    }
}
