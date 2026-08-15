import SwiftUI

struct NavigoView: View {
    let client: any NavigoClient

    var body: some View {
        NavigationStack {
            Group {
                switch client.availability {
                case .unavailable:
                    UnavailableFeatureView(
                        title: "Navigo",
                        description: "Le service Navigo n’est pas encore exposé par l’API Via. Vos titres et leur validité apparaîtront ici quand le contrat sera disponible.",
                        systemImage: "creditcard.fill",
                        actionTitle: nil,
                        action: nil
                    )
                }
            }
            .navigationTitle("Navigo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
