import SwiftUI

struct JourneyWarningBanner: View {
    let warnings: [String]

    var body: some View {
        if !visibleWarnings.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("À savoir avant de partir", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)

                ForEach(visibleWarnings, id: \.self) { warning in
                    Text(warning)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(.orange)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    private var visibleWarnings: [String] {
        JourneyWarningPresentation.visibleWarnings(from: warnings)
    }
}

enum JourneyWarningPresentation {
    static func visibleWarnings(from warnings: [String]) -> [String] {
        warnings.filter { !isOfferAdaptationWarning($0) }
    }

    private static func isOfferAdaptationWarning(_ warning: String) -> Bool {
        let normalized = warning
            .replacingOccurrences(of: "’", with: "'")
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "fr-FR")
            )
        return normalized.contains("adaptation de l'offre")
    }
}
