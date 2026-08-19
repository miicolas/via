import SwiftUI

struct AboutView: View {
    let destinations: SupportDestinations

    var body: some View {
        List {
            Section {
                LabeledContent("Application", value: "Via")
                LabeledContent("Version", value: version)
            }

            Section("Documents") {
                if let privacy = destinations.privacy {
                    Link("Confidentialité", destination: privacy)
                }
                if let terms = destinations.terms {
                    Link("Conditions d’utilisation", destination: terms)
                }
            }
        }
        .navigationTitle("À propos")
        .toolbarTitleDisplayMode(.inlineLarge)
    }

    private var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }
}
