import SwiftUI

struct NaturalJourneyAnswerView: View {
    let response: NaturalJourneyReady

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Trajet compris", systemImage: "checkmark.circle.fill")
                .font(ViaFont.headline)
                .foregroundStyle(ViaTheme.primary)
            Text(response.answer)
                .font(ViaFont.body)
                .foregroundStyle(ViaTheme.body)
            Text("Depuis \(response.interpretation.originLabel) vers \(response.interpretation.destination.name)")
                .font(ViaFont.subheadlineSemibold)
                .foregroundStyle(ViaTheme.ink)
            if let preferenceNotice = response.preferenceNotice {
                Text(preferenceNotice)
                    .font(ViaFont.caption)
                    .foregroundStyle(ViaTheme.muted)
            }
        }
        .padding(16)
        .background(ViaTheme.accentSoft)
        .clipShape(.rect(cornerRadius: 18))
    }
}
