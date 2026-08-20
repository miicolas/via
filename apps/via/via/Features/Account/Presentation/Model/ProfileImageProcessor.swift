import UIKit

@MainActor
enum ProfileImageProcessor {
    static func normalizedJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return normalizedJPEG(from: image)
    }

    static func normalizedJPEG(from image: UIImage) -> Data? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }

        let orientationRenderer = UIGraphicsImageRenderer(size: image.size)
        let orientedImage = orientationRenderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        guard let cgImage = orientedImage.cgImage else { return nil }

        let side = min(cgImage.width, cgImage.height)
        let cropRect = CGRect(
            x: (cgImage.width - side) / 2,
            y: (cgImage.height - side) / 2,
            width: side,
            height: side
        )
        guard let croppedImage = cgImage.cropping(to: cropRect) else { return nil }

        let squareImage = UIImage(cgImage: croppedImage, scale: 1, orientation: .up)
        let targetSide = min(CGFloat(side), 1024)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: targetSide, height: targetSide),
            format: format
        )
        let normalized = renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(x: 0, y: 0, width: targetSide, height: targetSide))
            squareImage.draw(in: CGRect(x: 0, y: 0, width: targetSide, height: targetSide))
        }
        return normalized.jpegData(compressionQuality: 0.85)
    }
}
