import SwiftUI

/// Everything the operator said about one perturbation. It lives in a sheet so
/// the line screen itself can stay a plan and a short list.
struct LineDisruptionDetailView: View {
    let disruption: LineDisruption

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 10) {
                        LineConditionLabel(condition: disruption.condition)

                        Text(disruption.isActive ? "En cours" : "À venir")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(disruption.isActive ? disruption.condition.tint : Color.secondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                (disruption.isActive ? disruption.condition.tint : Color.secondary)
                                    .opacity(0.12)
                            )
                            .clipShape(Capsule())
                    }

                    if let title = disruption.title {
                        Text(title)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    section("Tronçons concernés") {
                        let named = disruption.impactedSections.compactMap(\.travelText)
                        if named.isEmpty {
                            Text("Toute la ligne")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(named, id: \.self) { text in
                                Label(text, systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                    .labelStyle(.titleAndIcon)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if !disruption.periods.isEmpty {
                        section("Période") {
                            ForEach(Array(disruption.periods.enumerated()), id: \.offset) { _, period in
                                Label(periodText(period), systemImage: "calendar")
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if let message = disruption.message {
                        section("Détail") {
                            Text(message)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let updatedAt = disruption.updatedAt {
                        Text("Mis à jour à \(updatedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle("Perturbation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                        .accessibilityLabel("Fermer le détail de la perturbation")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(36)
    }

    @ViewBuilder
    private func section(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)

            content()
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func periodText(_ period: LineDisruptionPeriod) -> String {
        let begins = period.beginsAt.formatted(date: .abbreviated, time: .shortened)
        let ends = period.endsAt.formatted(date: .abbreviated, time: .shortened)
        return "Du \(begins) au \(ends)"
    }
}

#Preview {
    LineDisruptionDetailView(
        disruption: PreviewLineStatusRepository.metro1Detail.disruptions[0]
    )
}
