import SwiftUI

struct JourneySegmentStrip: View {
    private let items: [JourneySegmentStripModel.Item]
    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0

    init(journey: Journey) {
        items = JourneySegmentStripModel(journey: journey).items
    }

    var body: some View {
        Group {
            if items.count == 1, items[0].kind == .walkingOnly {
                // A single walking capsule stretches across the row instead of hugging.
                JourneySegmentBlock(item: items[0])
            } else {
                scrollableSegments(items)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Étapes du trajet")
    }

    private var showsTrailingFade: Bool {
        contentWidth > viewportWidth + 1
    }

    private func scrollableSegments(
        _ items: [JourneySegmentStripModel.Item]
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items) { item in
                    JourneySegmentBlock(item: item)
                }
            }
            .padding(.vertical, 1)
            .onGeometryChange(for: CGFloat.self) {
                $0.size.width
            } action: { newValue in
                contentWidth = newValue
            }
        }
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: { newValue in
            viewportWidth = newValue
        }
        .mask {
            if showsTrailingFade {
                HStack(spacing: 0) {
                    Rectangle().fill(.black)
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Rectangle().fill(.black)
            }
        }
    }
}

#Preview("Correspondance", traits: .sizeThatFitsLayout) {
    JourneySegmentStrip(journey: JourneyResult.mapPreview.journeys[0])
        .padding()
}
