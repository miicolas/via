import SwiftUI

struct WinkingEyeShape: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: point(321.1, 423.8, in: rect))
        path.addCurve(
            to: point(319.6, 429.6, in: rect),
            control1: point(320.0, 424.0, in: rect),
            control2: point(319.2, 426.0, in: rect)
        )
        path.addLine(to: point(326.9, 468.6, in: rect))
        path.addLine(to: point(367.4, 462.8, in: rect))
        path.addCurve(
            to: point(422.3, 496.1, in: rect),
            control1: point(389.5, 459.6, in: rect),
            control2: point(411.0, 472.8, in: rect)
        )
        path.addCurve(
            to: point(418.0, 504.8, in: rect),
            control1: point(424.0, 498.8, in: rect),
            control2: point(422.8, 501.6, in: rect)
        )
        path.addLine(to: point(335.5, 519.2, in: rect))
        path.addLine(to: point(350.0, 601.7, in: rect))
        path.addLine(to: point(477.3, 581.4, in: rect))
        path.addCurve(
            to: point(483.1, 574.5, in: rect),
            control1: point(481.4, 580.8, in: rect),
            control2: point(483.8, 578.2, in: rect)
        )
        path.addLine(to: point(468.6, 487.4, in: rect))
        path.addCurve(
            to: point(426.7, 432.5, in: rect),
            control1: point(464.5, 462.5, in: rect),
            control2: point(448.8, 440.1, in: rect)
        )
        path.addCurve(
            to: point(364.5, 416.5, in: rect),
            control1: point(405.1, 418.4, in: rect),
            control2: point(388.5, 414.7, in: rect)
        )
        path.closeSubpath()

        return path
    }

    private func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        let clampedProgress = min(max(progress, 0), 1)
        let eyelidY: CGFloat = 501
        let verticalScale = 1 - (0.94 * clampedProgress)

        // A small downward arc keeps the closed eye organic instead of flattening it.
        let horizontalPosition = min(max((x - 320) / 165, 0), 1)
        let arc = sin(horizontalPosition * .pi) * 6 * clampedProgress
        let morphedY = eyelidY + ((y - eyelidY) * verticalScale) + arc

        return CGPoint(
            x: rect.minX + (x / 1024) * rect.width,
            y: rect.minY + (morphedY / 1024) * rect.height
        )
    }
}
