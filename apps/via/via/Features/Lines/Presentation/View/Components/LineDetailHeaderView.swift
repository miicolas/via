import SwiftUI

struct LineDetailHeaderView: View {
    let route: RouteBadge
    let condition: LineCondition
    let source: LineStatusBoard.Source
    let fetchedAt: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            LineBadgeView(route: route, size: 44)

            VStack(alignment: .leading, spacing: 6) {
                LineConditionLabel(condition: condition)

                Text(freshnessText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var freshnessText: String {
        if source == .unavailable {
            return "État du trafic indisponible"
        }
        if let fetchedAt {
            return "Mis à jour à \(fetchedAt.formatted(date: .omitted, time: .shortened))"
        }
        return "Données en direct"
    }

    private var accessibilityLabel: String {
        return "Ligne \(route.shortName), \(condition.title). \(freshnessText)"
    }
}

#Preview {
    VStack(spacing: 16) {
        LineDetailHeaderView(
            route: PreviewLineStatusRepository.metro1,
            condition: .suspended,
            source: .live,
            fetchedAt: Date.now
        )
        LineDetailHeaderView(
            route: PreviewLineStatusRepository.metro1,
            condition: .normal,
            source: .unavailable,
            fetchedAt: nil
        )
    }
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
