import SwiftUI

struct MapSearchSheet: View {
    @Binding var text: String
    let authViewModel: AuthSessionViewModel
    let favoriteStations: any FavoriteStationRepository
    let transportPreferences: any TransportPreferencesRepository
    @State private var isAccountPresented = false

    var body: some View {
        NavigationStack {
            Color.clear
                .searchable(text: $text, prompt: "Où est-ce que tu veux aller ?")
                .toolbar {
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)

                    ToolbarSpacer(placement: .bottomBar)

                    ToolbarItem(placement: .bottomBar) {
                        Button("Compte", systemImage: "person.crop.circle.fill") {
                            isAccountPresented = true
                        }
                        .labelStyle(.iconOnly)
                    }
                }
                .sheet(isPresented: $isAccountPresented) {
                    AccountView(
                        authViewModel: authViewModel,
                        favoriteStations: favoriteStations,
                        transportPreferences: transportPreferences
                    )
                }
        }
    }
}

#Preview {
    @Previewable @State var text = ""

    ZStack {
        Color.blue
        MapSearchSheet(
            text: $text,
            authViewModel: .preview,
            favoriteStations: AppDependencies.preview.favoriteStations,
            transportPreferences: AppDependencies.preview.transportPreferences
        )
    }
}
