import SwiftUI

/// One criterion of an interpreted journey, shown as a capsule. A `nil` action
/// leaves it non-interactive, which is what the preserved-criteria recap wants.
struct NaturalJourneyCriteriaChip: View {
    let title: String
    let systemImage: String
    var action: (() -> Void)? = nil

    var body: some View {
        if let action {
            Button(action: action) {
                label
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .accessibilityHint("Modifier ce critère")
        } else {
            label
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .glassEffect(.regular, in: .capsule)
        }
    }

    private var label: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
    }
}

extension NaturalJourneyCriteria {
    /// "Arrivée · 21 août 2026 à 09:00", shared by the live criteria bar and
    /// the recap shown when a search could not complete.
    static func timeLabel(_ date: Date, represents: JourneyDatetimeRepresents) -> String {
        let prefix = represents == .arrival ? "Arrivée" : "Départ"
        return "\(prefix) · \(JourneyFormatting.dateTime(date))"
    }
}
