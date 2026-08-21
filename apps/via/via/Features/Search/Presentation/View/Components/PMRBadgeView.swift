import SwiftUI

struct PMRBadgeView: View {
    let accessibilityLabel: String
    var size: CGFloat = 22
    var tint: Color = .accentColor

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
    }

    var body: some View {
        Image(systemName: "figure.roll")
            .font(.system(size: size * 0.54, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: shape)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .glassEffect(.regular, in: shape)
    }
}

#Preview {
    PMRBadgeView(accessibilityLabel: "Accessible aux personnes à mobilité réduite")
        .padding()
}
