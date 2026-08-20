import SwiftUI

struct OnboardingView: View {
    let model: OnboardingModel

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPage = 0

    private let pages = [
        OnboardingPage.stations,
        OnboardingPage.lines,
        OnboardingPage.search,
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedPage) {
                ForEach(Array(pages.enumerated()), id: \.element) { index, page in
                    OnboardingSlideView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            // Stacked rather than side by side: two buttons sharing a row end
            // up as a bare word next to a pill, and the word is the one that
            // dismisses onboarding for good.
            VStack(spacing: 10) {
                Button(selectedPage == pages.count - 1 ? "Commencer" : "Continuer") {
                    if selectedPage == pages.count - 1 {
                        model.complete()
                        dismiss()
                    } else {
                        withAnimation(.snappy) {
                            selectedPage += 1
                        }
                    }
                }
                .primaryAction()

                Button("Passer") {
                    model.skip()
                    dismiss()
                }
                .secondaryAction()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }
}

enum OnboardingPage: String, Hashable {
    case stations
    case lines
    case search

    var title: String {
        switch self {
        case .stations: "Stations"
        case .lines: "Lignes"
        case .search: "Recherche"
        }
    }

    var message: String {
        switch self {
        case .stations:
            "Trouve rapidement les stations autour de toi et consulte les prochains passages."
        case .lines:
            "Suis les lignes, leurs directions et les perturbations importantes."
        case .search:
            "Prépare un trajet depuis ta position, une station ou un lieu enregistré."
        }
    }

    var systemImage: String {
        switch self {
        case .stations: "tram.fill"
        case .lines: "point.3.connected.trianglepath.dotted"
        case .search: "magnifyingglass"
        }
    }
}
