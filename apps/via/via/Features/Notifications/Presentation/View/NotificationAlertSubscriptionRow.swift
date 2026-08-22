import SwiftUI

struct NotificationAlertSubscriptionRow: View {
    let alert: NotificationAlertSubscription

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: alert.topicKind == .line ? "tram.fill" : "mappin.and.ellipse")
                .font(.title3.weight(.semibold))
                .foregroundStyle(alert.enabled ? .orange : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.label)
                    .font(.body.weight(.medium))
                Text(alert.topicKind == .line ? "Ligne" : "Station")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if !alert.enabled {
                Image(systemName: "pause.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("En pause")
            }
        }
        .frame(minHeight: 52)
    }
}
