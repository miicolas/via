import SwiftUI

enum SkeletonShape: Shape {
    case roundedRectangle(cornerRadius: CGFloat)
    case capsule
    case circle

    func path(in rect: CGRect) -> Path {
        switch self {
        case .roundedRectangle(let cornerRadius):
            RoundedRectangle(
                cornerRadius: min(cornerRadius, min(rect.width, rect.height) / 2),
                style: .continuous
            )
            .path(in: rect)
        case .capsule:
            Capsule().path(in: rect)
        case .circle:
            Circle().path(in: rect)
        }
    }
}

/// A single neutral placeholder block.
///
/// Deliberately inert: the moving highlight belongs to the enclosing
/// `skeletonGroup(label:)` so one loading screen runs one animation instead of
/// one per bar.
struct Skeleton: View {
    let shape: SkeletonShape

    init(_ shape: SkeletonShape = .roundedRectangle(cornerRadius: 8)) {
        self.shape = shape
    }

    var body: some View {
        shape
            .fill(Color.primary.opacity(0.08))
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        Skeleton(.circle)
            .frame(width: 46, height: 46)

        Skeleton(.capsule)
            .frame(width: 180, height: 14)

        Skeleton()
            .frame(height: 28)
    }
    .padding()
}
