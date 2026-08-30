import SwiftUI

struct MeetupPhaseBadgeView: View {
    let phase: MeetupPhase
    var isStale = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .background(tint.opacity(0.12), in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel(title)
    }

    private var title: String {
        if isStale { return "À actualiser" }
        return phase.presentationTitle
    }

    private var systemImage: String {
        if isStale { return "clock.badge.exclamationmark" }
        return phase.presentationSystemImage
    }

    private var tint: Color {
        if isStale { return .orange }
        return phase.presentationTint
    }
}

extension MeetupPhase {
    var presentationTitle: String {
        switch self {
        case .draft: "Brouillon"
        case .planning: "Calcul en cours"
        case .ready: "Prêt"
        case .live: "En direct"
        case .completed: "Terminé"
        case .cancelled: "Annulé"
        case .expired: "Expiré"
        }
    }

    var presentationSystemImage: String {
        switch self {
        case .draft: "pencil"
        case .planning: "arrow.trianglehead.2.clockwise.rotate.90"
        case .ready: "checkmark.circle.fill"
        case .live: "location.fill"
        case .completed: "flag.checkered"
        case .cancelled: "xmark.circle.fill"
        case .expired: "clock.badge.xmark"
        }
    }

    var presentationTint: Color {
        switch self {
        case .draft: .secondary
        case .planning: .blue
        case .ready: .green
        case .live: .green
        case .completed: .blue
        case .cancelled: .red
        case .expired: .secondary
        }
    }
}
