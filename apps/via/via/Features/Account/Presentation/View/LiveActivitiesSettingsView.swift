import ActivityKit
import SwiftUI
import UIKit

struct LiveActivitiesSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var activitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Suis ton trajet sans rouvrir Metyro.")
                    .font(.largeTitle.bold())

                LiveActivityPreview()

                Text("Les prochaines étapes restent visibles sur l’écran verrouillé et dans Dynamic Island pendant un trajet actif.")
                    .font(.title3)

                Label(
                    activitiesEnabled ? "Activités en direct autorisées" : "Activités en direct désactivées",
                    systemImage: activitiesEnabled ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(activitiesEnabled ? .green : .orange)

                Button("Ouvrir les réglages iOS", systemImage: "gearshape") {
                    openSettings()
                }
                .primaryAction()
            }
            .padding(24)
        }
        .navigationTitle("Activités en direct")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            activitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}
