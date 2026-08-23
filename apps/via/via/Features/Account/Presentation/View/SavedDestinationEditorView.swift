import SwiftUI

struct SavedDestinationEditorView: View {
    let draft: SavedDestinationDraft
    let onSave: (String, String) -> Void
    let onChangeDestination: (String, String) -> Void
    let onDelete: (() -> Void)?
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var label: String
    @State private var systemImage: String
    @State private var showsDiscardConfirmation = false
    @State private var showsDeleteConfirmation = false

    init(
        draft: SavedDestinationDraft,
        onSave: @escaping (String, String) -> Void,
        onChangeDestination: @escaping (String, String) -> Void,
        onDelete: (() -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.draft = draft
        self.onSave = onSave
        self.onChangeDestination = onChangeDestination
        self.onDelete = onDelete
        self.onClose = onClose
        _label = State(initialValue: draft.label)
        _systemImage = State(initialValue: draft.systemImage)
    }

    var body: some View {
        navigationContent
            .interactiveDismissDisabled(isDirty)
            .presentationDetents([.medium, .large])
            .confirmationDialog(
                "Abandonner les modifications ?",
                isPresented: $showsDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Abandonner", role: .destructive, action: onClose)
                Button("Continuer", role: .cancel) {}
            }
            .confirmationDialog(
                "Supprimer ce favori ?",
                isPresented: $showsDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Supprimer", role: .destructive, action: deleteAndClose)
                Button("Annuler", role: .cancel) {}
            }
    }

    private var navigationContent: some View {
        NavigationStack {
            editorContent
            .navigationTitle(draft.role?.displayTitle ?? "Favori")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                editorToolbar
            }
        }
    }

    private var editorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                destinationSummary
                labelField
                symbolField

                Button("Enregistrer", systemImage: "checkmark") {
                    onSave(trimmedLabel, systemImage)
                }
                .primaryAction()
                .disabled(trimmedLabel.isEmpty)
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private var labelField: some View {
        if draft.role == nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("LIBELLÉ")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("Nom du favori", text: $label)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .padding(14)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    .onChange(of: label) { _, value in
                        if value.count > 80 { label = String(value.prefix(80)) }
                    }
            }
        }
    }

    private var symbolField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SYMBOLE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            SavedDestinationSymbolPicker(selection: $systemImage)
        }
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(role: .close) {
                requestClose()
            }
        }

        if onDelete != nil {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Supprimer", systemImage: "trash", role: .destructive) {
                    if draft.role == nil {
                        showsDeleteConfirmation = true
                    } else {
                        deleteAndClose()
                    }
                }
                .labelStyle(.iconOnly)
            }
        }
    }

    private var destinationSummary: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .contentTransition(
                    reduceMotion
                        ? .identity
                        : .symbolEffect(
                            .replace.magic(fallback: .offUp.byLayer),
                            options: .nonRepeating
                        )
                )
                .animation(reduceMotion ? nil : .default, value: systemImage)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text(draft.result.name)
                    .font(.headline)
                Text(draft.result.savedDestinationContext)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button("Changer la destination", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
                onChangeDestination(trimmedLabel, systemImage)
            }
            .labelStyle(.iconOnly)
            .iconAction(size: .small)
        }
    }

    private var trimmedLabel: String {
        if let role = draft.role { return role.displayTitle }
        return label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDirty: Bool {
        draft.isNew || trimmedLabel != draft.label || systemImage != draft.systemImage
    }

    private func requestClose() {
        if isDirty {
            showsDiscardConfirmation = true
        } else {
            onClose()
        }
    }

    private func deleteAndClose() {
        onDelete?()
        onClose()
    }
}

private extension SearchResult {
    var savedDestinationContext: String {
        switch self {
        case .station:
            "Station"
        case .address(let address):
            address.context.isEmpty ? "Adresse" : address.context
        }
    }
}
