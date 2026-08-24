import SwiftUI

struct JourneyTimeEditorSheet: View {
    let journey: Journey
    let endpoint: JourneyDatetimeRepresents
    let tint: Color
    let onApply: (Date, JourneyDatetimeRepresents) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Date
    @State private var isApplying = false
    @State private var errorMessage: String?

    init(
        journey: Journey,
        endpoint: JourneyDatetimeRepresents,
        tint: Color,
        onApply: @escaping (Date, JourneyDatetimeRepresents) async throws -> Void
    ) {
        self.journey = journey
        self.endpoint = endpoint
        self.tint = tint
        self.onApply = onApply
        _selection = State(
            initialValue: endpoint == .departure ? journey.departureAt : journey.arrivalAt
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                schedulePreview

                InfiniteJourneyTimePicker(selection: $selection, tint: tint)

                Label(
                    "Glissez pour parcourir les horaires",
                    systemImage: "arrow.up.and.down"
                )
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }

                Button(action: apply) {
                    HStack(spacing: 9) {
                        if isApplying {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Label("Mettre à jour le trajet", systemImage: "checkmark")
                    }
                }
                .primaryAction(tint: tint)
                .disabled(isApplying)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .navigationTitle(endpoint.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                        .disabled(isApplying)
                }
            }
        }
        .interactiveDismissDisabled(isApplying)
    }

    private var schedulePreview: some View {
        HStack(spacing: 14) {
            previewValue(
                title: "Départ",
                date: departureAt,
                isEdited: endpoint == .departure
            )

            Image(systemName: "arrow.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            previewValue(
                title: "Arrivée",
                date: arrivalAt,
                isEdited: endpoint == .arrival
            )
        }
        .padding(16)
        .background(Color.secondary.opacity(0.1), in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    private func previewValue(title: LocalizedStringKey, date: Date, isEdited: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.caption.weight(.semibold))
                if isEdited {
                    Image(systemName: "slider.vertical.3")
                        .font(.caption2.weight(.bold))
                }
            }
            .foregroundStyle(isEdited ? tint : Color.secondary)

            Text(JourneyFormatting.time(date))
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(isEdited ? tint : Color.primary)
                .contentTransition(.numericText())

            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var departureAt: Date {
        switch endpoint {
        case .departure:
            selection
        case .arrival:
            selection.addingTimeInterval(-TimeInterval(journey.durationSeconds))
        }
    }

    private var arrivalAt: Date {
        switch endpoint {
        case .departure:
            selection.addingTimeInterval(TimeInterval(journey.durationSeconds))
        case .arrival:
            selection
        }
    }

    private func apply() {
        guard !isApplying else { return }
        isApplying = true
        errorMessage = nil

        Task {
            do {
                try await onApply(selection, endpoint)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isApplying = false
            }
        }
    }
}

private extension JourneyDatetimeRepresents {
    var navigationTitle: LocalizedStringKey {
        switch self {
        case .departure: "Heure de départ"
        case .arrival: "Heure d’arrivée"
        }
    }
}
