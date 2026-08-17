import SwiftUI

struct SearchLoadingSkeleton: View {
    let rowCount: Int

    init(rowCount: Int = 4) {
        self.rowCount = rowCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<rowCount, id: \.self) { index in
                HStack(spacing: 12) {
                    ViaSkeleton(.circle)
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 7) {
                        ViaSkeleton(.capsule)
                            .frame(width: index.isMultiple(of: 2) ? 164 : 132, height: 13)

                        ViaSkeleton(.capsule)
                            .frame(width: index.isMultiple(of: 3) ? 104 : 78, height: 10)
                    }

                    Spacer(minLength: 8)

                    ViaSkeleton(.capsule)
                        .frame(width: 42, height: 11)
                }
                .padding(.vertical, 13)

                if index < rowCount - 1 {
                    Divider()
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recherche des lieux…")
        .accessibilityAddTraits(.updatesFrequently)
    }
}
