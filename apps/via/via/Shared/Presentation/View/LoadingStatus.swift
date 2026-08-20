import SwiftUI

struct LoadingStatus: View {
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            // Plain dots: at 5pt the skeleton shimmer is invisible, and each
            // Skeleton would run its own never-ending mask animation.
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 5, height: 5)
                        .opacity(index == 1 ? 0.7 : 1)
                }
            }

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
