import SwiftUI

struct MeetupPlacePickerView: View {
    let model: MeetupsModel
    let stationsOnly: Bool
    let onSelect: (SearchResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                if model.isSearching && model.searchResults.isEmpty {
                    EmptyStateView(.searching("Recherche…"))
                        .frame(maxHeight: .infinity)
                } else if query.count >= 2 && model.searchResults.isEmpty {
                    EmptyStateView(.noResults(query: query))
                        .frame(maxHeight: .infinity)
                } else {
                    List(model.searchResults) { result in
                        Button {
                            onSelect(result)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: result.systemImage)
                                    .foregroundStyle(.tint)
                                    .frame(width: 28)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.name)
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(result.name)
                        .accessibilityValue(result.subtitle)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(stationsOnly ? "Station d’arrivée" : "Choisir un lieu")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: stationsOnly ? "Rechercher une station" : "Station ou adresse")
            .onChange(of: query) { _, value in
                Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    guard value == query else { return }
                    await model.search(value, stationsOnly: stationsOnly)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer", systemImage: "xmark", role: .close) { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
    }
}
