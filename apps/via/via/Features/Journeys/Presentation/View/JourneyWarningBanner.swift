import SwiftUI

struct JourneyWarningBanner: View {
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("À savoir avant de partir", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)

            ForEach(warnings, id: \.self) { warning in
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
