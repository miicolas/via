import SwiftUI

enum AnnotationFlowAlignment {
    case leading
    case center
}

struct AnnotationFlowLayout: Layout {
    let spacing: CGFloat
    let maximumLineWidth: CGFloat
    let alignment: AnnotationFlowAlignment

    init(
        spacing: CGFloat = 4,
        maximumLineWidth: CGFloat = 168,
        alignment: AnnotationFlowAlignment = .leading
    ) {
        self.spacing = spacing
        self.maximumLineWidth = maximumLineWidth
        self.alignment = alignment
    }

    /// Measurements keyed by available width, so `sizeThatFits` and
    /// `placeSubviews` don't each re-measure every subview per layout pass.
    struct MeasurementCache {
        var byWidth: [CGFloat: FlowMeasurement] = [:]
    }

    func makeCache(subviews: Subviews) -> MeasurementCache { MeasurementCache() }

    func updateCache(_ cache: inout MeasurementCache, subviews: Subviews) {
        cache.byWidth.removeAll(keepingCapacity: true)
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout MeasurementCache
    ) -> CGSize {
        measurement(for: subviews, width: availableWidth(for: proposal.width), cache: &cache).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout MeasurementCache
    ) {
        let measurement = measurement(
            for: subviews,
            width: min(maximumLineWidth, max(bounds.width, 1)),
            cache: &cache
        )

        for (index, subview) in subviews.enumerated() {
            let size = measurement.sizes[index]
            let origin = measurement.origins[index]
            subview.place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
        }
    }

    private func availableWidth(for proposedWidth: CGFloat?) -> CGFloat {
        min(maximumLineWidth, max(proposedWidth ?? maximumLineWidth, 1))
    }

    private func measurement(
        for subviews: Subviews,
        width: CGFloat,
        cache: inout MeasurementCache
    ) -> FlowMeasurement {
        if let cached = cache.byWidth[width] { return cached }
        var origins: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var measuredWidth: CGFloat = 0
        var rowStartIndex = 0
        var rowRanges: [Range<Int>] = []
        var rowWidths: [CGFloat] = []

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                rowRanges.append(rowStartIndex..<index)
                rowWidths.append(x - spacing)
                rowStartIndex = index
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            origins.append(CGPoint(x: x, y: y))
            sizes.append(size)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            measuredWidth = max(measuredWidth, min(width, x - spacing))
        }

        if !subviews.isEmpty {
            rowRanges.append(rowStartIndex..<subviews.count)
            rowWidths.append(x - spacing)
        }

        if alignment == .center {
            for (range, rowWidth) in zip(rowRanges, rowWidths) {
                let offset = max(0, (width - rowWidth) / 2)
                for index in range {
                    origins[index].x += offset
                }
            }
        }

        let measuredHeight = subviews.isEmpty ? 0 : y + rowHeight
        let measuredSizeWidth = alignment == .center && !subviews.isEmpty ? width : measuredWidth
        let measured = FlowMeasurement(
            size: CGSize(width: measuredSizeWidth, height: measuredHeight),
            origins: origins,
            sizes: sizes
        )
        cache.byWidth[width] = measured
        return measured
    }
}

struct FlowMeasurement {
    let size: CGSize
    let origins: [CGPoint]
    let sizes: [CGSize]
}
