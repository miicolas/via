import SwiftUI

/// The badge Via shows while Apple Intelligence works: one dotted spinner and
/// one shimmering label on a capsule. A full-screen orb owns the sheet even
/// when the wait is short; a pill says "still going" without claiming the view.
struct ThinkingPill: View {
    var label: String = "Via réfléchit…"

    var body: some View {
        HStack(spacing: 9) {
            ThinkingSpinner(size: 16)

            Text(label)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .aiShimmer()
        }
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .padding(.vertical, 9)
        .glassEffect(.regular.tint(Color.aiSurface), in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    VStack(spacing: 24) {
        ThinkingPill()
        ThinkingPill(label: "Via cherche un itinéraire…")
    }
    .padding(40)
}
