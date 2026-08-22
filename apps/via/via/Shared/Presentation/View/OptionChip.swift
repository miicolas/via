import SwiftUI

/// A compact glass option that can either edit a criterion or simply recap it.
/// Active options keep the same shape while adding Via's accent tint.
struct OptionChip: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    var action: (() -> Void)? = nil

    var body: some View {
        if let action {
            Button(action: action) {
                label
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(isActive ? Color.accentColor : nil)
        } else {
            label
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(
                    isActive ? Color.accentColor.opacity(0.14) : .clear,
                    in: Capsule()
                )
                .glassEffect(.regular, in: .capsule)
        }
    }

    private var label: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isActive ? Color.accentColor : Color.primary)
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
