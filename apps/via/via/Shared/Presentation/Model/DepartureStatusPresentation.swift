import SwiftUI

extension DepartureTimeColorRole {
    /// The one place a role becomes a colour. `DepartureTimingView` and the
    /// journey departure choices both read it, so the same vehicle cannot be
    /// red on the station board and orange one tap deeper.
    var color: Color {
        switch self {
        case .live: .green
        case .theoretical, .attention: .orange
        case .critical: .red
        case .neutral: .secondary
        }
    }
}

extension DepartureStatus {
    /// What the status is called, or `nil` when it adds nothing to a time
    /// already on screen — an on-time departure says so by matching its
    /// schedule.
    ///
    /// The delay itself is not in here: it needs the scheduled and expected
    /// times, which only the caller holds. `delayTitle(scheduledAt:expectedAt:)`
    /// is that variant.
    var title: String? {
        switch self {
        case .cancelled: "Annulé"
        case .missed: "Non desservi"
        case .early: "En avance"
        case .delayed: "En retard"
        case .arrived: "Arrivé"
        case .departed: "Parti"
        case .onTime, .noReport, .scheduled: nil
        }
    }

    /// `+3 min` / `−2 min` where the two times are known, falling back to the
    /// plain wording where they are not.
    func delayTitle(scheduledAt: Date, expectedAt: Date?) -> String? {
        guard self == .delayed || self == .early else { return title }
        guard let expectedAt else { return title }
        let seconds = Int(expectedAt.timeIntervalSince(scheduledAt).rounded())
        let minutes = DepartureTimingMath.roundedDelayMinutes(seconds)
        return seconds >= 0 ? "+\(minutes) min" : "−\(minutes) min"
    }
}

extension JourneyTimingSource {
    /// How a journey names its timing feed — and only the live one has a name.
    ///
    /// A schedule is the ordinary case: badging it says nothing the times do
    /// not already say, and every badge spent on the ordinary case is a badge
    /// the live one no longer stands out from. `nil` means "show nothing",
    /// never "show a placeholder".
    var title: String? {
        switch self {
        case .realtime: "Temps réel"
        case .theoretical: nil
        }
    }

    var systemImage: String? {
        switch self {
        case .realtime: "dot.radiowaves.up.forward"
        case .theoretical: nil
        }
    }

    var isLive: Bool { self == .realtime }
}

extension Optional where Wrapped == JourneyTimingSource {
    /// An unknown feed is not a live one, so it is just as silent.
    var title: String? { flatMap(\.title) }
    var systemImage: String? { flatMap(\.systemImage) }
    var isLive: Bool { self?.isLive == true }
}
