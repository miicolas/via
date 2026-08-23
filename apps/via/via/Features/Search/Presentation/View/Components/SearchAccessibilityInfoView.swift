import SwiftUI

struct SearchAccessibilityInfoView: View {
    let source: SearchResponse.AccessibilitySource
    let elevatorSource: SearchResponse.ElevatorSource

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Label("Filtre PMR", systemImage: "figure.roll")
                        .font(.title2.weight(.bold))

                    Text("Metyro demande à Île-de-France Mobilités un itinéraire adapté aux personnes en fauteuil roulant. Le résultat peut être nettement plus long qu’un trajet classique.")
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

                    Label("Filtre Ascenseurs", systemImage: "arrow.up.arrow.down.square")
                        .font(.title2.weight(.bold))

                    Text("Ce filtre conserve uniquement les itinéraires dont chaque station ferroviaire utilisée possède des ascenseurs référencés et disponibles. Un ascenseur hors service, inconnu ou une station sans état vérifiable écarte le trajet.")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Limites de la donnée")
                            .font(.headline)
                        Text("La déclaration PMR reste un référentiel stable. L’état des ascenseurs provient des rondes en gare et est publié jusqu’à trois fois par jour ; ce n’est pas une télésurveillance en temps réel.")
                            .foregroundStyle(.secondary)
                        Text(
                            source.status == .ok
                                ? "La dernière déclaration disponible a été importée par Metyro."
                                : "Aucune déclaration PMR n’est actuellement disponible dans Metyro."
                        )
                            .foregroundStyle(.secondary)
                        if let importedAt = source.importedAt {
                            Text("Dernière importation Metyro : \(importedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(
                            elevatorSource.status == .ok
                                ? "Le dernier état des ascenseurs disponible a été importé par Metyro."
                                : "Aucun état d’ascenseur n’est actuellement disponible dans Metyro."
                        )
                            .foregroundStyle(.secondary)
                        if let importedAt = elevatorSource.importedAt {
                            Text("Dernière importation ascenseurs : \(importedAt.formatted(date: .abbreviated, time: .shortened))")
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
                        Link(
                            "État des ascenseurs — Île-de-France Mobilités",
                            destination: URL(string: "https://prim.iledefrance-mobilites.fr/fr/jeux-de-donnees/etat-des-ascenseurs")!
                        )
                        Text("Licences des jeux de données Île-de-France Mobilités")
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
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }
}
