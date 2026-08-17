import SwiftUI

/// Placeholder mirroring the results layout (hero card + alternative rows)
/// while journeys load, instead of a bare spinner.
struct JourneyLoadingSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            card

            VStack(alignment: .leading, spacing: 0) {
                bar(width: 130, height: 11)
                    .padding(.bottom, 14)

                ForEach(0..<3, id: \.self) { index in
                    row
                    if index < 2 {
                        Divider()
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recherche des meilleurs itinéraires")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                chip(width: 44)
                chip(width: 96)
                chip(width: 44)
                Spacer(minLength: 8)
                bar(width: 64, height: 30)
            }

            bar(width: 190, height: 14)

            Divider()

            HStack {
                bar(width: 140, height: 12)
                Spacer(minLength: 8)
                chip(width: 92, height: 34)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
        }
    }

    private var row: some View {
        HStack(spacing: 6) {
            chip(width: 40)
            chip(width: 88)
            chip(width: 40)
            Spacer(minLength: 8)
            bar(width: 52, height: 14)
        }
        .padding(.vertical, 14)
    }

    private func chip(width: CGFloat, height: CGFloat = 30) -> some View {
        ViaSkeleton(.capsule)
            .frame(width: width, height: height)
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        ViaSkeleton(.roundedRectangle(cornerRadius: height / 3))
            .frame(width: width, height: height)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    ScrollView {
        JourneyLoadingSkeleton()
            .padding(16)
    }
    .background(Color.secondary.opacity(0.05))
}
