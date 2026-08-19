import SwiftUI

struct SupportView: View {
    let onboarding: OnboardingModel
    let destinations: SupportDestinations

    @State private var isOnboardingPresented = false

    var body: some View {
        List {
            Section("Besoin d’aide") {
                if let faq = destinations.faq {
                    Link(destination: faq) {
                        Label("FAQ", systemImage: "questionmark.circle")
                    }
                }

                if let feedback = destinations.feedback {
                    Link(destination: feedback) {
                        Label("Envoyer un feedback", systemImage: "bubble.left.and.bubble.right")
                    }
                }
            }

            Section("Via") {
                NavigationLink {
                    AboutView(destinations: destinations)
                } label: {
                    Label("À propos", systemImage: "info.circle")
                }

                Button {
                    onboarding.reset()
                    isOnboardingPresented = true
                } label: {
                    Label("Revoir l’introduction", systemImage: "sparkles.rectangle.stack")
                }
            }
        }
        .navigationTitle("Aide et support")
        .toolbarTitleDisplayMode(.inlineLarge)
        .sheet(isPresented: $isOnboardingPresented) {
            OnboardingView(model: onboarding)
        }
    }
}
