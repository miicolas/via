import SwiftUI

/// Hero card for the currently selected journey: segment chips with the total
/// duration, the origin → destination line, then departure details and the CTA.
struct JourneyAlternativeCard: View {
    let journey: Journey
    var onGo: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                JourneySegmentStrip(journey: journey)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(journey.totalDurationMinutes)")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("min")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Durée totale \(journey.totalDurationLabel)")
            }

            if let routeSummary {
                Text(routeSummary)
                    .font(.headline)
                    .lineLimit(2)
            }

            Divider()

            HStack(spacing: 12) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(departureText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if let onGo {
                    Button("Y aller", systemImage: "location.fill", action: onGo)
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                }
            }

            warnings
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var warnings: some View {
        if journey.status == .disrupted || journey.status == .theoretical {
            VStack(alignment: .leading, spacing: 5) {
                if journey.status == .disrupted {
                    Label("Trajet perturbé", systemImage: "exclamationmark.triangle.fill")
                } else if journey.status == .theoretical {
                    Label("Horaires théoriques", systemImage: "clock.badge.questionmark")
                }

                ForEach(Array(journey.warnings.enumerated()), id: \.offset) { item in
                    Text(item.element)
                }
            }
            .font(.footnote)
            .foregroundStyle(.orange)
        }
    }

    private var routeSummary: String? {
        guard let origin = journey.sections.first?.from.name,
              let destination = journey.sections.last?.to.name else { return nil }
        return "\(origin) → \(destination)"
    }

    private var departureText: String {
        let firstTransit = journey.sections.first { $0.kind == .transit }
        let departure = firstTransit?.departureAt ?? journey.departureAt
        var text = "Départ \(departure.formatted(date: .omitted, time: .shortened))"
        if let platform = firstTransit?.platform {
            text += " · quai \(platform)"
        }
        return text
    }

    private var statusColor: Color {
        switch journey.status {
        case .normal: .green
        case .disrupted: .orange
        case .theoretical: .gray
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    JourneyAlternativeCard(
        journey: JourneyResult.mapPreview.journeys[0],
        onGo: {}
    )
    .padding()
    .background(.gray.opacity(0.08))
}

#Preview("Texte accessibilité", traits: .sizeThatFitsLayout) {
    JourneyAlternativeCard(
        journey: JourneyResult.mapPreview.journeys[0],
        onGo: {}
    )
    .padding()
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Mode sombre", traits: .sizeThatFitsLayout) {
    JourneyAlternativeCard(
        journey: JourneyResult.mapPreview.journeys[0],
        onGo: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Plusieurs correspondances", traits: .sizeThatFitsLayout) {
    JourneyAlternativeCard(
        journey: .mapPreviewMultipleTransfers,
        onGo: {}
    )
    .frame(width: 390)
    .padding()
}
