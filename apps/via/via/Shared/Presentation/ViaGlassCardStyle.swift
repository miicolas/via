import SwiftUI

extension View {
    /// The single Liquid Glass look of every Via card surface, shared by the
    /// home sheet and the station sheet.
    func viaGlassCard(
        cornerRadius: CGFloat = ViaGlassCardStyle.cornerRadius,
        isInteractive: Bool = false
    ) -> some View {
        modifier(ViaGlassCardStyle(cornerRadius: cornerRadius, isInteractive: isInteractive))
    }
}

struct ViaGlassCardStyle: ViewModifier {
    static let cornerRadius: CGFloat = 18

    var cornerRadius: CGFloat
    var isInteractive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .glassEffect(isInteractive ? .regular.interactive() : .regular, in: shape)
            .contentShape(shape)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 16) {
        Text("Carte statique")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .viaGlassCard()

        Text("Carte interactive")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .viaGlassCard(isInteractive: true)
    }
    .padding()
}
