import SwiftUI

struct DepartureLoadingView: View {
    let routeCount: Int

    init(routeCount: Int) {
        self.routeCount = max(routeCount, 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ViaSkeleton(.capsule)
                        .frame(width: 164, height: 18)

                    Spacer(minLength: 8)

                    ViaSkeleton(.capsule)
                        .frame(width: 76, height: 13)
                }

                ViaSkeleton(.capsule)
                    .frame(width: 190, height: 11)
            }

            ForEach(0..<routeCount, id: \.self) { index in
                lineSkeleton(index: index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chargement des prochains passages…")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func lineSkeleton(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ViaSkeleton(.capsule)
                    .frame(width: index.isMultiple(of: 2) ? 44 : 56, height: 30)

                Spacer(minLength: 8)

                ViaSkeleton(.capsule)
                    .frame(width: index.isMultiple(of: 2) ? 104 : 128, height: 16)
            }

            Divider()

            ForEach(0..<2, id: \.self) { direction in
                HStack {
                    ViaSkeleton(.capsule)
                        .frame(width: direction == 0 ? 154 : 126, height: 14)

                    Spacer(minLength: 8)

                    ViaSkeleton(.capsule)
                        .frame(width: 68, height: 23)
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
        }
    }
}
