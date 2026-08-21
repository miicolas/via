import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                MarkBadge(tint: .blue, size: 88)

                VStack(spacing: 6) {
                    Text("Via")
                        .font(.largeTitle.bold())
                    Text("Version \(Bundle.main.marketingVersion) (\(Bundle.main.buildNumber))")
                        .foregroundStyle(.secondary)
                }

                Text("Les transports d’Île-de-France, plus simples à lire et à parcourir.")
                    .font(.title3)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 12) {
                    Label("Application iOS native", systemImage: "apple.logo")
                    Label("Itinéraires et recherche", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    Label("Données de compte exportables", systemImage: "lock.shield.fill")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(.quaternary, in: .rect(cornerRadius: 22))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Données de fréquentation")
                        .font(.headline)
                    Link(
                        "Profils horaires — Île-de-France Mobilités",
                        destination: URL(string: "https://data.iledefrance-mobilites.fr/explore/dataset/validations-reseau-ferre-profils-horaires-par-jour-type-4eme-trimestre/")!
                    )
                    Text("Source : Île-de-France Mobilités — ODbL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(.quaternary, in: .rect(cornerRadius: 22))

                Text("Bon trajet.")
                    .font(.title2.italic())
                    .foregroundStyle(.secondary)
                    .padding(.top, 30)
            }
            .padding(24)
        }
        .navigationTitle("À propos")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Bundle {
    var marketingVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var buildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
