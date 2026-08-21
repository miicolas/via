import SwiftUI

struct SearchAccessibilityInfoView: View {
    let source: SearchResponse.AccessibilitySource

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Label("Filtre PMR", systemImage: "figure.roll")
                        .font(.title2.weight(.bold))

                    Text("Via demande à Île-de-France Mobilités un itinéraire adapté aux personnes en fauteuil roulant. Le résultat peut être nettement plus long qu’un trajet classique.")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Niveaux inclus")
                            .font(.headline)

                        Label("En autonomie", systemImage: "checkmark.circle.fill")
                        Label("Avec un agent", systemImage: "person.fill.checkmark")
                        Label("Sur réservation", systemImage: "calendar.badge.clock")
                    }

                    Text("Les itinéraires nécessitant une réservation ou l’assistance d’un agent restent proposés avec un avertissement. Les données locales complètent le résultat sans supprimer un itinéraire PMR renvoyé par Île-de-France Mobilités.")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Limites de la donnée")
                            .font(.headline)
                        Text("La source couvre principalement les gares ferroviaires, RER et Transilien. Elle est statique et ne reflète pas les pannes d’ascenseur en temps réel.")
                            .foregroundStyle(.secondary)
                        Text(
                            source.status == .ok
                                ? "La dernière déclaration disponible a été importée par Via."
                                : "Aucune déclaration PMR n’est actuellement disponible dans Via."
                        )
                            .foregroundStyle(.secondary)
                        if let importedAt = source.importedAt {
                            Text("Dernière importation Via : \(importedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Source")
                            .font(.headline)
                        Link(
                            "Accessibilité en gare — Île-de-France Mobilités",
                            destination: URL(string: "https://prim.iledefrance-mobilites.fr/fr/jeux-de-donnees/accessibilite-en-gare")!
                        )
                        Text("Licence Ouverte 2.0 — Etalab")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 560, alignment: .leading)
                .padding(20)
            }
            .navigationTitle("Accessibilité")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
