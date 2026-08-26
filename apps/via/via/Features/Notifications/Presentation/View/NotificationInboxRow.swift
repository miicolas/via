import SwiftUI

struct NotificationInboxRow: View {
    let item: NotificationInboxItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if item.category == .line {
                NotificationLineBadgeView(item: item)
                    .frame(minWidth: 32, alignment: .leading)
            } else {
                Image(systemName: item.category.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(item.readAt == nil ? .orange : .secondary)
                    .frame(width: 32)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(.body.weight(item.readAt == nil ? .semibold : .regular))
                    Spacer(minLength: 4)
                    Text(item.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(item.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(item.deepLink == nil ? "" : "Ouvre le détail associé")
    }
}
