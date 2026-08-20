import SwiftUI

/// The way into natural search, shared by the search field and the Stations
/// toolbar so the tint and the accessibility copy stay identical.
struct AIEntryButton: View {
    /// A toolbar already draws its own Liquid Glass container, so the button
    /// there is a bare glyph; next to the search field it brings its own.
    enum Surface {
        case toolbar
        case standalone
    }

    var surface: Surface = .standalone
    let isDiscoverable: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch surface {
            case .toolbar:
                Button(action: action) {
                    glyph
                        .font(ToolbarGlyphMetrics.glyphFont)
                        .frame(
                            width: ToolbarGlyphMetrics.slot,
                            height: ToolbarGlyphMetrics.slot,
                        )
                }
                .tint(Color.aiAccent)
            case .standalone:
                Button(action: action) {
                    Image(systemName: "apple.intelligence")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.aiAccent)
                        .frame(width: 48, height: 48)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(Color.aiSurface).interactive(), in: .circle)
                .aiBeam(in: Circle(), isEnabled: isDiscoverable && !reduceMotion)
            }
        }
        .accessibilityLabel(NaturalJourneyPresentationPolicy.entryAccessibilityLabel)
        .accessibilityHint(NaturalJourneyPresentationPolicy.entryAccessibilityHint)
    }

    /// Discovery pulses the glyph rather than tracing a halo: a beam behind a
    /// toolbar item reads as a smudge over the glass, and a breathing glyph
    /// keeps changing size next to the account avatar.
    private var glyph: some View {
        Image(systemName: "apple.intelligence")
            .symbolEffect(
                .pulse,
                options: .repeat(.continuous),
                isActive: isDiscoverable && !reduceMotion,
            )
    }
}
