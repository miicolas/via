import SwiftUI

struct StationElevatorsSection: View {
    let snapshot: StationElevatorSnapshot
    let loadingState: SelectedStationLoadingState
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Ascenseurs")
                    .font(.title3.weight(.bold))

                Spacer()

                if !snapshot.items.isEmpty {
                    Label(summaryTitle, systemImage: summarySystemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(summaryColor)
                        .labelStyle(.titleAndIcon)
                }
            }

            if loadingState == .loading && snapshot.status == .unavailable {
                SkeletonList(
                    count: 2,
                    label: "Chargement de l’état des ascenseurs…",
                    row: .departure,
                    separator: .divider(leadingInset: 40)
                )
            } else if snapshot.status == .unavailable {
                EmptyStateView(.elevatorsUnavailable) {
                    RetryButton(action: onRetry)
                        .secondaryAction()
                }
            } else if snapshot.items.isEmpty {
                EmptyStateView(.noElevators)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(snapshot.items.enumerated()), id: \.element.id) { index, elevator in
                        StationElevatorRow(elevator: elevator)

                        if index < snapshot.items.count - 1 {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }

                if let sourceDate = snapshot.sourceUpdatedAt ?? snapshot.importedAt {
                    Text("Île-de-France Mobilités · mise à jour \(RelativeTimeFormatting.short(sourceDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .contain)
    }

    private var unavailableCount: Int {
        snapshot.items.filter { $0.status == .unavailable }.count
    }

    private var unknownCount: Int {
        snapshot.items.filter { $0.status == .unknown }.count
    }

    private var summaryTitle: String {
        if unavailableCount > 0 {
            return "\(unavailableCount) hors service"
        }
        if unknownCount > 0 {
            return "\(unknownCount) sans état"
        }
        return "Tous disponibles"
    }

    private var summarySystemImage: String {
        if unavailableCount > 0 { return "xmark.octagon.fill" }
        if unknownCount > 0 { return "questionmark.circle.fill" }
        return "checkmark.circle.fill"
    }

    private var summaryColor: Color {
        if unavailableCount > 0 { return .red }
        if unknownCount > 0 { return .orange }
        return .green
    }
}
