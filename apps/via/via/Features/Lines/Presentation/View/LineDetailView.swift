import SwiftUI

struct LineDetailView: View {
    @State private var viewModel: LineDetailViewModel
    private let route: RouteBadge

    init(repository: any LineStatusRepository, route: RouteBadge) {
        _viewModel = State(
            initialValue: LineDetailViewModel(repository: repository, lineID: route.id)
        )
        self.route = route
    }

    var body: some View {
        List {
            headerSection

            if let detail = viewModel.detail.value {
                if detail.branches.count > 1 {
                    branchPicker(branches: detail.branches)
                }

                if let branch = viewModel.selectedBranch {
                    Section("Schéma de la ligne") {
                        LineSchemaView(
                            branch: branch,
                            lineColor: Color(transitHex: route.colorHex, fallback: .secondary),
                            cutSegments: viewModel.cutSegments,
                            affectedStopIDs: viewModel.affectedStopIDs
                        )
                    }
                }

                if !detail.activeDisruptions.isEmpty {
                    Section("En cours") {
                        ForEach(detail.activeDisruptions) { disruption in
                            LineDisruptionCard(disruption: disruption)
                        }
                    }
                }

                if !detail.upcomingDisruptions.isEmpty {
                    Section("À venir") {
                        ForEach(detail.upcomingDisruptions) { disruption in
                            LineDisruptionCard(disruption: disruption)
                        }
                    }
                }
            }
        }
        .navigationTitle("\(route.mode.displayName) \(route.shortName)")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if case .loading(nil) = viewModel.detail {
                ProgressView("Chargement de la ligne…")
            } else if case .failed(_, nil) = viewModel.detail {
                ContentUnavailableView(
                    "Ligne indisponible",
                    systemImage: "wifi.exclamationmark",
                    description: Text("Impossible de charger cette ligne. Réessayez.")
                )
            }
        }
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.runAutomaticRefresh() }
    }

    private var headerSection: some View {
        Section {
            HStack(spacing: 14) {
                LineBadgeView(route: route, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    LineConditionLabel(condition: viewModel.detail.value?.condition ?? .normal)

                    if viewModel.detail.value?.source == .unavailable {
                        Text("État du trafic indisponible")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let fetchedAt = viewModel.detail.value?.fetchedAt {
                        Text("Mis à jour à \(fetchedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
    }

    private func branchPicker(branches: [LineBranch]) -> some View {
        Section {
            Picker("Direction", selection: branchSelection) {
                ForEach(branches) { branch in
                    Text("Vers \(branch.headsign)").tag(branch.id)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var branchSelection: Binding<String> {
        Binding(
            get: { viewModel.selectedBranch?.id ?? "" },
            set: { viewModel.selectedBranchID = $0 }
        )
    }
}

#Preview {
    NavigationStack {
        LineDetailView(
            repository: PreviewLineStatusRepository(),
            route: PreviewLineStatusRepository.metro1
        )
    }
}
