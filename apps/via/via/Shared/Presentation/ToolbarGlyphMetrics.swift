import SwiftUI

/// Trailing toolbar items share one Liquid Glass capsule, so the AI glyph and
/// the account avatar have to be laid out on the same square — otherwise the
/// capsule ends up with two segments of different sizes.
enum ToolbarGlyphMetrics {
    /// The square every trailing item is laid out on.
    static let slot: CGFloat = 26
    /// A filled disc reads bigger than a glyph of the same size, so the avatar
    /// sits slightly inside the slot.
    static let avatar: CGFloat = 24
    static let glyphFont: Font = .system(size: 17, weight: .semibold)
}
