import SwiftUI

struct ReportView: View {
    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress

    let locationModel: LocationModel
    let repository: any ReportRepository

    @State private var viewModel: ReportViewModel

    init(locationModel: LocationModel, repository: any ReportRepository) {
        self.locationModel = locationModel
        self.repository = repository
        _viewModel = State(
            initialValue: ReportViewModel(
                locationModel: locationModel,
                repository: repository
            )
        )
    }

    var body: some View {
        Group {
            if case .completed = viewModel.state {
                ReportConfirmationView(onDone: viewModel.reset)
            } else {
                selectionView
            }
        }
        .opacity(tabVisibilityProgress)
        .task {
            viewModel.requestLocationIfNeeded()
        }
    }

    private var selectionView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Aidez les autres voyageurs en partageant ce que vous observez.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ReportContextBannerView(
                        state: locationModel.state,
                        onRetry: viewModel.requestLocationIfNeeded
                    )

                    ForEach(ReportSection.allCases, id: \.self) { section in
                        ReportSectionView(
                            section: section,
                            categories: ReportCategory.allCases.filter { $0.section == section },
                            isSubmitting: isSubmitting,
                            onSelect: viewModel.submit
                        )
                    }

                    Text("Les signalements sont anonymes et servent à améliorer les informations de transport.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Signaler")
            .toolbarTitleDisplayMode(.inlineLarge)
            .overlay {
                if case .submitting = viewModel.state {
                    ProgressView("Envoi du signalement…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                } else if case .failed(let error) = viewModel.state {
                    ReportErrorView(error: error, onRetry: viewModel.reset)
                }
            }
        }
    }

    private var isSubmitting: Bool {
        if case .submitting = viewModel.state { return true }
        return false
    }
}
