import SwiftUI

struct LineDetailView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel: LineDetailViewModel
    @State private var isNotificationAuthorizationRequested = false

    private let route: RouteBadge
    private let accountModel: AccountModel?
    @Binding private var isFavorite: Bool

    init(
        viewModel: LineDetailViewModel,
        route: RouteBadge,
        accountModel: AccountModel? = nil,
        isFavorite: Binding<Bool> = .constant(false)
    ) {
        _viewModel = State(initialValue: viewModel)
        self.route = route
        self.accountModel = accountModel
        _isFavorite = isFavorite
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                LineDetailHeaderView(
                    route: route,
                    condition: viewModel.detail.value?.condition ?? .normal,
                    source: viewModel.detail.value?.source ?? .unavailable,
                    fetchedAt: viewModel.detail.value?.fetchedAt
                )

                if let detail = viewModel.detail.value {
                    if !detail.disruptions.isEmpty {
                        LineDisruptionsSection(
                            active: detail.activeDisruptions,
                            upcoming: detail.upcomingDisruptions
                        )
                    }

                    LinePlanView(
                        strips: viewModel.strips,
                        lineColorHex: route.colorHex,
                        isOpen: { viewModel.isOpen($0) },
                        onToggle: { strip in
                            withAnimation(reduceMotion ? nil : .snappy) {
                                viewModel.toggle(strip)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .hapticRefreshable { await viewModel.refresh() }
        .task { await viewModel.runAutomaticRefresh() }
        .navigationTitle("\(route.mode.displayName) \(route.shortName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isFavorite.toggle()
                } label: {
                    Image(systemName: StateSymbol.star(isOn: isFavorite))
                }
                .labelStyle(.iconOnly)
                .stateSymbolTransition(value: isFavorite)
                .toggleHaptic(on: isFavorite)
                .tint(isFavorite ? .orange : .primary)
                .accessibilityLabel(
                    isFavorite
                        ? "Retirer la ligne des favoris"
                        : "Ajouter la ligne aux favoris"
                )
                .accessibilityValue(isFavorite ? "Ajoutée" : "Non ajoutée")
                .accessibilityHint("Enregistre la ligne en accès rapide dans l’onglet Lignes.")
            }

            if let accountModel {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Apple asks for the prompt in context: the moment someone
                        // follows a line is the moment the permission means something.
                        let isFollowing = accountModel.toggleNotificationAlert(
                            topicKind: .line,
                            topicID: route.id.rawValue,
                            label: "\(route.mode.displayName) \(route.shortName)"
                        )
                        if isFollowing { isNotificationAuthorizationRequested = true }
                    } label: {
                        Image(systemName: StateSymbol.bell(isOn: accountModel.isFollowingNotification(
                            topicKind: .line,
                            topicID: route.id.rawValue
                        )))
                    }
                    .labelStyle(.iconOnly)
                    .toggleHaptic(on: accountModel.isFollowingNotification(
                        topicKind: .line,
                        topicID: route.id.rawValue
                    ))
                    .stateSymbolTransition(value: accountModel.isFollowingNotification(
                        topicKind: .line,
                        topicID: route.id.rawValue
                    ))
                    .accessibilityLabel("Suivre la ligne")
                    .accessibilityValue(accountModel.isFollowingNotification(
                        topicKind: .line,
                        topicID: route.id.rawValue
                    ) ? "Activé" : "Désactivé")
                }
            }
        }
        .notificationAuthorization(
            isRequested: $isNotificationAuthorizationRequested,
            message: "Autorisez les notifications dans Réglages iOS pour être prévenu des perturbations de cette ligne."
        )
        .overlay {
            if case .loading(nil) = viewModel.detail {
                SkeletonGate(isLoading: true) {
                    SkeletonList(
                        count: 10,
                        label: "Chargement de la ligne…",
                        row: .schemaStop
                    )
                    .padding(.horizontal, 20)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .background(.background)
            } else if case .failed(_, nil) = viewModel.detail {
                EmptyStateView(
                    .offline(
                        title: "Ligne indisponible",
                        message: "Impossible de charger cette ligne. Réessayez.",
                    ),
                ) {
                    RetryButton { Task { await viewModel.refresh() } }
                        .primaryAction()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
            }
        }
    }
}

#Preview("Métro 1 — trafic interrompu") {
    NavigationStack {
        LineDetailView(
            viewModel: LineDetailViewModel(
                repository: PreviewLineStatusRepository(),
                lineID: PreviewLineStatusRepository.metro1.id
            ),
            route: PreviewLineStatusRepository.metro1
        )
    }
}

#Preview("RER A — tronc commun et branches") {
    NavigationStack {
        LineDetailView(
            viewModel: LineDetailViewModel(
                repository: PreviewLineStatusRepository(),
                lineID: PreviewLineStatusRepository.rerA.id
            ),
            route: PreviewLineStatusRepository.rerA
        )
    }
}

#Preview("Sombre") {
    NavigationStack {
        LineDetailView(
            viewModel: LineDetailViewModel(
                repository: PreviewLineStatusRepository(),
                lineID: PreviewLineStatusRepository.rerA.id
            ),
            route: PreviewLineStatusRepository.rerA
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Dynamic Type — accessibilité 2") {
    NavigationStack {
        LineDetailView(
            viewModel: LineDetailViewModel(
                repository: PreviewLineStatusRepository(),
                lineID: PreviewLineStatusRepository.metro1.id
            ),
            route: PreviewLineStatusRepository.metro1
        )
    }
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Service normal — écran complet") {
    let detail = PreviewLineStatusRepository.metro1Detail
    let normalDetail = LineDetail(
        route: detail.route,
        branches: detail.branches,
        directions: detail.directions,
        source: detail.source,
        fetchedAt: detail.fetchedAt,
        disruptions: []
    )
    let repository = PreviewLineStatusRepository(
        details: [detail.route.id: normalDetail]
    )

    NavigationStack {
        LineDetailView(
            viewModel: LineDetailViewModel(
                repository: repository,
                lineID: detail.route.id
            ),
            route: detail.route
        )
    }
}
