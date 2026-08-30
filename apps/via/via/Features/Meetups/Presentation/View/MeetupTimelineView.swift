import SwiftUI

struct MeetupTimelineView: View {
    let meetup: Meetup

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let plan = meetup.plan, !plan.joinPoints.isEmpty {
                ForEach(Array(plan.joinPoints.enumerated()), id: \.element.id) { index, point in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(.tint)
                                .frame(width: 12, height: 12)
                            if index < plan.joinPoints.count - 1 {
                                Rectangle()
                                    .fill(.tint.opacity(0.35))
                                    .frame(width: 2, height: 64)
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(point.station.name)
                                .font(.headline)
                            Text(point.meetAt.formatted(date: .omitted, time: .shortened))
                                .foregroundStyle(.secondary)
                            Label(point.zone.title, systemImage: "train.side.front.car")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 20)
                    }
                }
            } else if meetup.plan?.status == .fallbackAtDestination {
                Label("Retrouvailles séparées à la destination", systemImage: "mappin.and.ellipse")
                    .foregroundStyle(.secondary)
            } else {
                EmptyStateView(
                    .unavailable(
                        title: "Plan en préparation",
                        message: "Les jonctions apparaîtront dès que chaque origine peut être calculée."
                    )
                )
            }
        }
    }
}
