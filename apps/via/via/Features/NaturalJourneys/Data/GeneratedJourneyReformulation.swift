import Foundation
import FoundationModels

@Generable(description: "Reformulation canonique d’une demande de trajet")
struct GeneratedJourneyReformulation {
    @Guide(
        description: "Une phrase française unique qui explicite les rôles des lieux, le moment et les contraintes sans ajouter d’information",
    )
    var query: String

    func validatedQuery() -> String? {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty || value.count > 500 ? nil : value
    }
}
