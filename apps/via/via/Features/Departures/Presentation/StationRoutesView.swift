import SwiftUI

struct StationRoutesView: View {
    let routes: [RouteBadge]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lignes présentes")
                .font(.headline)

            if routes.isEmpty {
                Text("Aucune ligne référencée pour cette station.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                AnnotationFlowLayout(
                    spacing: 8,
                    maximumLineWidth: 720,
                    alignment: .leading
                ) {
                    ForEach(routes) { route in
                        TransitRouteBadgeView(route: route, size: 30)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
