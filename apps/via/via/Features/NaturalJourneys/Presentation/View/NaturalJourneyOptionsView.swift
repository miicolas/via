import SwiftUI

struct NaturalJourneyOptionsView: View {
    let onApply: (Set<TransitMode>, Set<TransitMode>, Set<TransitMode>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selections: [TransitMode: ModeSelection]

    init(
        required: Set<TransitMode>,
        excluded: Set<TransitMode>,
        preferred: Set<TransitMode>,
        onApply: @escaping (Set<TransitMode>, Set<TransitMode>, Set<TransitMode>) -> Void,
    ) {
        self.onApply = onApply
        var values: [TransitMode: ModeSelection] = [:]
        for mode in TransitMode.allCases {
            values[mode] = if required.contains(mode) {
                .required
            } else if excluded.contains(mode) {
                .excluded
            } else if preferred.contains(mode) {
                .preferred
            } else {
                ModeSelection.none
            }
        }
        _selections = State(initialValue: values)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(TransitMode.allCases, id: \.self) { mode in
                        Picker(mode.displayName, selection: selection(for: mode)) {
                            ForEach(ModeSelection.allCases, id: \.self) { value in
                                Text(value.label).tag(value)
                            }
                        }
                        .haptic(Haptic.selection, on: selection(for: mode).wrappedValue)
                    }
                } footer: {
                    Text("Chaque mode peut être obligatoire, préféré, exclu ou sans préférence.")
                }
            }
            .navigationTitle("Options de transport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Appliquer") {
                        onApply(modes(for: .required), modes(for: .excluded), modes(for: .preferred))
                        dismiss()
                    }
                }
            }
        }
    }

    private func selection(for mode: TransitMode) -> Binding<ModeSelection> {
        Binding(
            get: { selections[mode, default: .none] },
            set: { selections[mode] = $0 },
        )
    }

    private func modes(for selection: ModeSelection) -> Set<TransitMode> {
        Set(selections.compactMap { $0.value == selection ? $0.key : nil })
    }
}

private enum ModeSelection: String, CaseIterable {
    case none
    case required
    case preferred
    case excluded

    var label: String {
        switch self {
        case .none: "Sans préférence"
        case .required: "Obligatoire"
        case .preferred: "Préféré"
        case .excluded: "Exclu"
        }
    }
}
