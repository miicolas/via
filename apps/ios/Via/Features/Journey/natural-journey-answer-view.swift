import SwiftUI

struct NaturalJourneyAnswerView: View {
    let response: NaturalJourneyReady

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Trajet compris", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(ViaTheme.primary)
            Text(response.answer)
                .font(.body)
                .foregroundStyle(ViaTheme.body)
            Text("Depuis \(response.interpretation.originLabel) vers \(response.interpretation.destination.name)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ViaTheme.ink)
            if let preferenceNotice = response.preferenceNotice {
                Text(preferenceNotice)
                    .font(.caption)
                    .foregroundStyle(ViaTheme.muted)
            }
        }
        .padding(16)
        .background(ViaTheme.accentSoft)
        .clipShape(.rect(cornerRadius: 18))
    }
}
