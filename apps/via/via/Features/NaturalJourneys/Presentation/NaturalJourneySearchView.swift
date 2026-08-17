import SwiftUI

struct NaturalJourneySearchView: View {
    let viewModel: NaturalJourneyViewModel
    let currentLocation: GeoCoordinate?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedJourneyID: JourneyID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                composer
                resultContent
            }
            .navigationTitle("Demande à Via")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Décris ton trajet naturellement", systemImage: "sparkles")
                .font(.title3.weight(.semibold))

            TextField(
                "Ex. Je veux arriver à Bastille avant 19 h en évitant le bus",
                text: query,
                axis: .vertical
            )
            .lineLimit(2...4)
            .textFieldStyle(.plain)
            .padding(14)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .submitLabel(.search)
            .onSubmit(submit)

            Button("Trouver mon itinéraire", systemImage: "arrow.right", action: submit)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    @ViewBuilder
    private var resultContent: some View {
        switch viewModel.state {
        case .idle:
            Spacer()
        case .loading:
            ViaLoadingStatus(label: "Via comprend ta demande…")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            Spacer()
        case .failed:
            ContentUnavailableView {
                Label("Recherche indisponible", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Impossible d’interpréter la demande pour le moment.")
            } actions: {
                Button("Réessayer", systemImage: "arrow.clockwise", action: viewModel.retry)
            }
        case .loaded(let result):
            loadedContent(result)
        }
    }

    @ViewBuilder
    private func loadedContent(_ result: NaturalJourneyResult) -> some View {
        switch result {
        case .ready(let answer, let notice, _, let journeys):
            VStack(alignment: .leading, spacing: 8) {
                Text(answer).font(.headline)
                if let notice { Text(notice).font(.footnote).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)

            JourneyAlternativesView(
                state: .loaded(journeys),
                selectedJourneyID: selectedJourneyID,
                onSelect: { selectedJourneyID = $0 },
                onRetry: viewModel.retry
            )
        case .needsClarification(_, let fields):
            ContentUnavailableView(
                "Un détail manque",
                systemImage: "questionmark.bubble",
                description: Text(fields.first?.question ?? "Précise ta demande puis réessaie.")
            )
        case .unsupported(let message, let examples):
            messageView(message, example: examples.first)
        case .unavailable(let message), .rateLimited(let message):
            messageView(message, example: nil)
        }
    }

    private func messageView(_ message: String, example: String?) -> some View {
        ContentUnavailableView {
            Label("Via n’a pas pu répondre", systemImage: "sparkles")
        } description: {
            VStack(spacing: 8) {
                Text(message)
                if let example { Text("Exemple : \(example)") }
            }
        }
    }

    private func submit() {
        selectedJourneyID = nil
        viewModel.submit(currentLocation: currentLocation)
    }

    private var query: Binding<String> {
        Binding(
            get: { viewModel.query },
            set: { viewModel.query = $0 }
        )
    }
}
