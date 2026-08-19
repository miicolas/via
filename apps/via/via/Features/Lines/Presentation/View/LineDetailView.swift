import SwiftUI

struct LineDetailView: View {
    @State private var viewModel: LineDetailViewModel
    private let route: RouteBadge

    init(viewModel: LineDetailViewModel, route: RouteBadge) {
        _viewModel = State(initialValue: viewModel)
        self.route = route
    }

    var body: some View {
        List {
            headerSection

            if let detail = viewModel.detail.value {
                if detail.schemaDirections.count > 1 {
                    directionPicker(directions: detail.schemaDirections)
                }

                if let direction = viewModel.selectedDirection {
                    Section("Schéma de la ligne") {
                        LineSchemaView(
                            rows: viewModel.schemaRows,
                            lineColor: Color(transitHex: route.colorHex, fallback: .secondary),
                            directionLabel: direction.label,
                            onToggleRun: { viewModel.toggleRun($0) }
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

    private func directionPicker(directions: [LineDirection]) -> some View {
        Section {
            Picker("Direction", selection: directionSelection) {
                ForEach(directions) { direction in
                    Text("Vers \(direction.label)").tag(direction.id)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var directionSelection: Binding<String> {
        Binding(
            get: { viewModel.selectedDirection?.id ?? "" },
            set: { viewModel.selectedDirectionID = $0 }
        )
    }
}

#Preview {
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
