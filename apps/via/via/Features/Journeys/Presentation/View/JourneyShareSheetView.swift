import SwiftUI

/// The in-app destination for a public journey link. It deliberately renders
/// the immutable snapshot rather than planning again: the recipient sees what
/// the sender shared, even if the timetable has since moved on.
struct JourneyShareSheetView: View {
    let token: String
    let repository: any JourneyShareRepository
    let onClose: () -> Void

    /// One value rather than a snapshot, an error and a flag kept in step by
    /// hand: the three of them could disagree, and every reader then needed a
    /// branch for a state `load()` is not supposed to produce.
    private enum LoadState {
        case loading
        case loaded(JourneyShareSnapshot)
        case failed(ViaError)
    }

    @State private var state: LoadState = .loading
    @State private var expandedSectionIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .loading:
                    EmptyStateView(.searching("Chargement du trajet…"))
                case .loaded(let snapshot):
                    journeyContent(snapshot)
                case .failed(let error):
                    EmptyStateView(emptyState(for: error)) {
                        RetryButton {
                            Task { await load() }
                        }
                        .primaryAction()
                    }
                }
            }
            .navigationTitle("Trajet partagé")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer", systemImage: "xmark", role: .close, action: onClose)
                        .labelStyle(.iconOnly)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    JourneyShareLinkButton(url: publicURL)
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Partager le trajet")
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(36)
        .presentationDragIndicator(.visible)
        .task(id: token) {
            await load()
        }
    }

    @ViewBuilder
    private func journeyContent(_ snapshot: JourneyShareSnapshot) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                JourneyDetailHeaderView(
                    journey: snapshot.journey,
                    source: snapshot.journey.status == .theoretical ? .theoretical : nil
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 22)

                JourneyDetailSummaryView(
                    journey: snapshot.journey,
                    source: nil,
                    canEditTimes: false,
                    onEditTime: { _ in }
                )
                .padding(.horizontal, 20)

                if !snapshot.journey.warnings.isEmpty {
                    JourneyWarningBanner(warnings: snapshot.journey.warnings)
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                }

                Divider()
                    .padding(.top, 28)

                JourneyTimelineView(
                    journey: snapshot.journey,
                    expandedSectionIDs: $expandedSectionIDs
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)

                Text("Trajet partagé le \(JourneyFormatting.dateTime(snapshot.generatedAt))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    private var publicURL: URL {
        ShareLinkOrigin.url(token: token)
    }

    @MainActor
    private func load() async {
        state = .loading
        do {
            state = .loaded(try await repository.load(token: token))
        } catch {
            state = .failed(error.via)
        }
    }

    /// Title and sentence chosen together, the way the `EmptyState` statics
    /// elsewhere are written — two switches over the same value could word one
    /// half for a failure and the other half for a different one.
    private func emptyState(for error: ViaError) -> EmptyState {
        switch error {
        case .server(statusCode: 404):
            .unavailable(
                title: "Lien indisponible",
                message: "Ce lien ne correspond à aucun trajet partagé."
            )
        case .server(statusCode: 410):
            .unavailable(
                title: "Lien indisponible",
                message: "Ce lien de trajet a expiré."
            )
        default:
            .offline(title: "Connexion impossible")
        }
    }
}
