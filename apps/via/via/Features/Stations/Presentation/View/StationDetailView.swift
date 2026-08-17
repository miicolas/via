import SwiftUI

/// Detail sheet stacked above the tab sheet when a station row is selected.
struct StationDetailView: View {
    var station: StationPlaceholder
    var isLargeScreen: Bool
    @Binding var detailDetent: PresentationDetent

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(station.detail)

                        Text(station.distance)
                    }
                    .foregroundStyle(.gray)

                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.title)
                                .foregroundStyle(.blue)

                            Text("Départs")
                                .fontWeight(.bold)

                            Text("Prochains passages")
                                .font(.callout)
                                .foregroundStyle(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: .rect(cornerRadius: 20))

                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                .font(.title)
                                .foregroundStyle(.blue)

                            Text("Itinéraire")
                                .fontWeight(.bold)

                            Text(station.distance)
                                .font(.callout)
                                .foregroundStyle(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: .rect(cornerRadius: 20))
                        .compositingGroup()
                        .opacity(0.5)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "star.circle.fill")
                            .font(.title)
                            .foregroundStyle(.orange)

                        Text("Favoris")
                            .fontWeight(.bold)

                        Divider()
                            .padding(.vertical, 4)

                        Toggle("Ajouter aux stations favorites", isOn: .constant(false))
                            .font(.callout)
                            .foregroundStyle(.gray)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: .rect(cornerRadius: 20))
                }
                .padding([.horizontal, .bottom], 15)
                .padding(.top, 12)
            }
            .navigationTitle(station.name)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents(detents, selection: $detailDetent)
        .presentationCornerRadius(isLargeScreen ? 45 : nil)
        .adaptiveSheet(380, isActive: isLargeScreen)
        .presentationBackgroundInteraction(.enabled)
        .interactiveDismissDisabled()
    }

    private var detents: Set<PresentationDetent> {
        if isLargeScreen {
            return [.height(80), .fraction(0.97)]
        }

        return [.height(80), .large]
    }
}
