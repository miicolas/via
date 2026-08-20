import SwiftUI

/// The traveller's own marker: the app mark inside a filled bead.
///
/// This is the one thing on a timeline that wears the app's own glyph. The stops
/// keep their plain beads — a mark on every one of them would stop meaning
/// anything, and the point of the mark is that wherever it shows up, it is *me*.
///
/// The badge animates itself in on first appearance, delayed by
/// `\.appearanceDelay`, so a marker inside a staggered list arrives with its own
/// row rather than popping while the row is still invisible.
struct ViaMarkBadge: View {
    let tint: Color
    var size: CGFloat = 30
    /// A dashed collar marks a position read off the timetable rather than
    /// measured, so live and estimated differ without relying on colour.
    var isEstimated = false
    /// The halo is right on a rail and too loud in a compact header.
    var showsHalo = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appearanceDelay) private var appearanceDelay
    @State private var hasAppeared = false
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            halo
            disc
            mark
        }
        .frame(width: size, height: size)
        .shadow(color: tint.opacity(0.45), radius: size * 0.3, y: 1)
        .scaleEffect(hasAppeared ? 1 : 0.35)
        .opacity(hasAppeared ? 1 : 0)
        .animation(.smooth(duration: 0.35), value: tint)
        .onAppear(perform: appear)
    }

    // MARK: - Layers

    /// Drawn behind the disc and outside the frame, so it widens the marker
    /// without pushing the rail around.
    @ViewBuilder
    private var halo: some View {
        if showsHalo, !isEstimated, !reduceMotion {
            Circle()
                .fill(tint.opacity(0.3))
                .scaleEffect(isPulsing ? 1.75 : 0.9)
                .opacity(isPulsing ? 0 : 1)
                .animation(
                    .easeOut(duration: 1.8).repeatForever(autoreverses: false),
                    value: isPulsing
                )
        }
    }

    /// Collared in the background colour, so the bead keeps punching out of a
    /// rail thick enough to swallow it.
    private var disc: some View {
        Circle()
            .fill(tint.gradient)
            .overlay {
                Circle().strokeBorder(
                    Color(.systemBackground),
                    style: StrokeStyle(
                        lineWidth: size * 0.12,
                        dash: isEstimated ? [size * 0.11, size * 0.11] : []
                    )
                )
            }
    }

    private var mark: some View {
        ViaMark()
            .fill(.white)
            .frame(width: size * 0.56, height: size * 0.56 / ViaMark.aspectRatio)
            .opacity(hasAppeared ? 1 : 0)
            .blur(radius: hasAppeared ? 0 : 1.5)
    }

    // MARK: - Entrance

    private func appear() {
        isPulsing = true
        guard !hasAppeared else { return }

        guard !reduceMotion else {
            hasAppeared = true
            return
        }

        withAnimation(
            .spring(response: 0.42, dampingFraction: 0.62).delay(appearanceDelay)
        ) {
            hasAppeared = true
        }
    }
}

#Preview("Marqueur") {
    HStack(spacing: 28) {
        VStack(spacing: 8) {
            ViaMarkBadge(tint: .blue)
            Text("En direct").font(.caption2)
        }
        VStack(spacing: 8) {
            ViaMarkBadge(tint: .blue, isEstimated: true)
            Text("Estimé").font(.caption2)
        }
        VStack(spacing: 8) {
            ViaMarkBadge(tint: .blue, size: 22, showsHalo: false)
            Text("Compact").font(.caption2)
        }
    }
    .padding(40)
}
