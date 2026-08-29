import SwiftUI

struct ReportConfirmationView: View {
    let submission: ReportSubmission
    let onDone: () -> Void

    var body: some View {
        confirmation
            // The report left the device with nothing else to show for it.
            .hapticOnAppear(Haptic.saved)
    }

    private var confirmation: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.green.opacity(0.14))
                            .frame(width: 96, height: 96)

                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.green)
                            .frame(width: 68, height: 68)

                        Image(systemName: "checkmark")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)
                    }

                    Text("Signalement envoyé")
                        .font(.largeTitle.weight(.bold))

                    HStack(spacing: 12) {
                        Image(systemName: submission.category.systemImage)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(submission.category.tint)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(submission.category.title)
                                .font(.headline)

                            Text(submission.context.station.name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        .secondary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )

                    Label("Votre identité n’est pas affichée", systemImage: "hand.raised.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHint("Via utilise votre compte uniquement pour prévenir les abus.")
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height, alignment: .center)
                .padding(24)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("Terminé", systemImage: "checkmark", action: onDone)
                .font(.headline)
                .primaryAction(tint: .blue)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.bar)
        }
    }
}
