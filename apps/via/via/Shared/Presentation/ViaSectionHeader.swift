import SwiftUI

/// Uppercased, letter-spaced section title shared by list and card sections.
struct ViaSectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .kerning(1.2)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    ViaSectionHeader("Récents")
        .padding()
}
