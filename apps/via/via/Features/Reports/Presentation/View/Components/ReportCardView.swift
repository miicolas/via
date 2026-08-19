import SwiftUI

struct ReportCardView: View {
    let title: String
    let systemImage: String
    let tint: Color
    var subtitle: String?
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(tint)

                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: systemImage)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: dynamicTypeSize.isAccessibilitySize ? 112 : 154,
                alignment: .topLeading
            )
            .padding(18)
            .background(.secondary.opacity(0.08), in: RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            ))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint)
    }

    private var accessibilityHint: String {
        if let subtitle { return subtitle }
        return isEnabled ? "Envoie ce signalement" : "Indisponible"
    }
}
