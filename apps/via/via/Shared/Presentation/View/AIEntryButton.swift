import SwiftUI

/// The way into natural search, shared by the search field and the Stations
/// toolbar so the beam, the tint and the accessibility copy stay identical.
struct AIEntryButton: View {
    enum Shape {
        case capsule(title: String)
        case circle
    }

    let shape: Shape
    let isDiscoverable: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            label
                .foregroundStyle(Color.aiAccent)
                .aiBeam(cornerRadius: cornerRadius, isEnabled: isDiscoverable && !reduceMotion)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NaturalJourneyPresentationPolicy.entryAccessibilityLabel)
        .accessibilityHint(NaturalJourneyPresentationPolicy.entryAccessibilityHint)
    }

    @ViewBuilder
    private var label: some View {
        switch shape {
        case let .capsule(title):
            Label(title, systemImage: "sparkles")
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
                .background(Color.aiSurface, in: Capsule())
        case .circle:
            Image(systemName: "sparkles")
                .frame(width: 36, height: 36)
                .background(Color.aiSurface, in: Circle())
        }
    }

    private var cornerRadius: CGFloat {
        switch shape {
        case .capsule: 999
        case .circle: 18
        }
    }
}
