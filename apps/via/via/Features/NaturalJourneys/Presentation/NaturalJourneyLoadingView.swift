import SwiftUI

struct NaturalJourneyLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            assistantCard
            alternatives
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Via comprend la demande et prépare les itinéraires")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var assistantCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViaAIBadge()

            ViaLoadingStatus(label: "Via comprend ta demande…")

            VStack(alignment: .leading, spacing: 9) {
                bar(widthFraction: 0.88, height: 22)
                bar(widthFraction: 0.66, height: 22)
            }

            HStack(spacing: 8) {
                chip(width: 46)
                chip(width: 104)
                chip(width: 46)
            }

            bar(widthFraction: 0.58, height: 18)

            HStack(spacing: 10) {
                chip(width: 112, height: 44)
                chip(width: 126, height: 44)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .viaAISurface()
    }

    private var alternatives: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViaSkeleton(.roundedRectangle(cornerRadius: 4))
                .frame(width: 125, height: 12)

            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: 8) {
                    chip(width: 42)
                    chip(width: 92)
                    Spacer(minLength: 8)
                    ViaSkeleton(.roundedRectangle(cornerRadius: 4))
                        .frame(width: 54, height: 16)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func chip(width: CGFloat, height: CGFloat = 30) -> some View {
        ViaSkeleton(.capsule)
            .frame(width: width, height: height)
    }

    private func bar(widthFraction: CGFloat, height: CGFloat) -> some View {
        GeometryReader { proxy in
            ViaSkeleton(.roundedRectangle(cornerRadius: height / 3))
                .frame(width: proxy.size.width * widthFraction, height: height)
        }
        .frame(height: height)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    NaturalJourneyLoadingView()
        .padding()
        .background(Color(uiColor: .systemBackground))
}
