import SwiftUI

/// The two-glyph mark from the app icon, as a resolution-independent `Shape`.
///
/// The outlines are the ones Icon Composer draws for `AppIcon.icon`, transcribed
/// here rather than imported as an image: on the rail the mark has to take the
/// colour of the line it sits on, and an image asset would freeze both its tint
/// and its resolution.
///
/// Coordinates stay in the icon's 1024 canvas and are aspect-fitted, centred,
/// into whatever rect the caller hands over.
struct ViaMark: Shape {
    /// Tight bounds of the transcribed outlines inside the 1024 icon canvas.
    private static let source = CGRect(x: 319.495, y: 382.993, width: 363.205, height: 218.707)

    /// Width relative to height — useful to size a frame that fits the mark exactly.
    static let aspectRatio: CGFloat = source.width / source.height

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / Self.source.width, rect.height / Self.source.height)
        let fitted = CGSize(width: Self.source.width * scale, height: Self.source.height * scale)

        var transform = CGAffineTransform(
            translationX: rect.midX - fitted.width / 2,
            y: rect.midY - fitted.height / 2
        )
        transform = transform.scaledBy(x: scale, y: scale)
        transform = transform.translatedBy(x: -Self.source.minX, y: -Self.source.minY)

        return Self.outlines.applying(transform)
    }

    /// Rebuilt per call rather than cached in a `static let`: `Path` wraps a
    /// reference type, so a stored one would not survive strict concurrency.
    private static var outlines: Path {
        var path = Path()

        path.move(to: CGPoint(x: 321.1, y: 423.8))
        path.addCurve(
            to: CGPoint(x: 319.6, y: 429.6),
            control1: CGPoint(x: 320.0, y: 424.0),
            control2: CGPoint(x: 319.2, y: 426.0)
        )
        path.addLine(to: CGPoint(x: 326.9, y: 468.6))
        path.addLine(to: CGPoint(x: 367.4, y: 462.8))
        path.addCurve(
            to: CGPoint(x: 422.3, y: 496.1),
            control1: CGPoint(x: 389.5, y: 459.6),
            control2: CGPoint(x: 411.0, y: 472.8)
        )
        path.addCurve(
            to: CGPoint(x: 418.0, y: 504.8),
            control1: CGPoint(x: 424.0, y: 498.8),
            control2: CGPoint(x: 422.8, y: 501.6)
        )
        path.addLine(to: CGPoint(x: 335.5, y: 519.2))
        path.addLine(to: CGPoint(x: 350.0, y: 601.7))
        path.addLine(to: CGPoint(x: 477.3, y: 581.4))
        path.addCurve(
            to: CGPoint(x: 483.1, y: 574.5),
            control1: CGPoint(x: 481.4, y: 580.8),
            control2: CGPoint(x: 483.8, y: 578.2)
        )
        path.addLine(to: CGPoint(x: 468.6, y: 487.4))
        path.addCurve(
            to: CGPoint(x: 426.7, y: 432.5),
            control1: CGPoint(x: 464.5, y: 462.5),
            control2: CGPoint(x: 448.8, y: 440.1)
        )
        path.addCurve(
            to: CGPoint(x: 364.5, y: 416.5),
            control1: CGPoint(x: 405.1, y: 418.4),
            control2: CGPoint(x: 388.5, y: 414.7)
        )
        path.closeSubpath()

        path.move(to: CGPoint(x: 519.2, y: 392.0))
        path.addLine(to: CGPoint(x: 526.5, y: 435.3))
        path.addLine(to: CGPoint(x: 562.6, y: 429.6))
        path.addCurve(
            to: CGPoint(x: 621.9, y: 464.3),
            control1: CGPoint(x: 584.3, y: 426.5),
            control2: CGPoint(x: 610.0, y: 441.1)
        )
        path.addCurve(
            to: CGPoint(x: 616.1, y: 471.5),
            control1: CGPoint(x: 623.5, y: 467.5),
            control2: CGPoint(x: 620.3, y: 470.9)
        )
        path.addLine(to: CGPoint(x: 535.1, y: 484.5))
        path.addLine(to: CGPoint(x: 549.6, y: 568.4))
        path.addLine(to: CGPoint(x: 682.7, y: 545.3))
        path.addLine(to: CGPoint(x: 668.2, y: 455.6))
        path.addCurve(
            to: CGPoint(x: 637.8, y: 407.9),
            control1: CGPoint(x: 664.0, y: 432.3),
            control2: CGPoint(x: 652.0, y: 414.0)
        )
        path.addCurve(
            to: CGPoint(x: 581.4, y: 383.3),
            control1: CGPoint(x: 620.0, y: 393.0),
            control2: CGPoint(x: 601.0, y: 385.0)
        )
        path.addCurve(
            to: CGPoint(x: 523.6, y: 389.1),
            control1: CGPoint(x: 568.0, y: 382.0),
            control2: CGPoint(x: 548.0, y: 385.0)
        )
        path.addLine(to: CGPoint(x: 519.2, y: 392.0))
        path.closeSubpath()

        return path
    }
}

#Preview("Mark") {
    VStack(spacing: 24) {
        ViaMark()
            .fill(Color.accentColor)
            .frame(width: 160, height: 160 / ViaMark.aspectRatio)

        ViaMark()
            .fill(.white)
            .frame(width: 60, height: 60 / ViaMark.aspectRatio)
            .padding(24)
            .background(Color.blue.gradient, in: Circle())
    }
    .padding()
}
