import SwiftUI

struct RecentSearchRow: View {
    let recent: RecentSearch

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(.quaternary, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(recent.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                if let context = recent.context, !context.isEmpty {
                    Text(context)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
