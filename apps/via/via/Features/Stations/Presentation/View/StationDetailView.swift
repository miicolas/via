import SwiftUI

/// Detail sheet stacked above the tab sheet when a station row is selected.
struct StationDetailView: View {
    let selection: SelectedStationModel
    var isLargeScreen: Bool
    @Binding var detailDetent: PresentationDetent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The sheet's collapsed detent only shows the navigation title, so the
    /// bottom-bar favorite control is hidden until the sheet is expanded.
    private var isCollapsed: Bool {
        detailDetent == .height(80)
    }

    var body: some View {
        NavigationStack {
            if let currentStation = selection.overview {
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        VStack(alignment: .leading, spacing: 6) {
                            AnnotationFlowLayout(spacing: 6, maximumLineWidth: .infinity) {
                                ForEach(currentStation.routes) { route in
                                    LineBadgeView(route: route)
                                }
                            }

                            if let accessibility = currentStation.accessibility {
                                PMRBadgeView(
                                    accessibilityLabel: "Accessibilité PMR, \(accessibilityVoiceOverValue(accessibility))",
                                    size: 24,
                                    tint: accessibilityTint(accessibility.condition)
                                )
                            }

                            if let distanceText = currentStation.distanceText {
                                Text(distanceText)
                            }
                        }
                        .foregroundStyle(.gray)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Prochains passages")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            ForEach(currentStation.routes) { route in
                                let departures = currentStation.departures(for: route)

                                if departures.isEmpty {
                                    DepartureLineRow(
                                        route: route,
                                        departure: nil,
                                        source: currentStation.departureSource
                                    )
                                } else {
                                    ForEach(departures) { departure in
                                        DepartureLineRow(
                                            route: route,
                                            departure: departure,
                                            source: currentStation.departureSource
                                        )
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: .rect(cornerRadius: 20))

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

                                Text(currentStation.distanceText ?? "Vers cette station")
                                    .font(.callout)
                                    .foregroundStyle(.gray)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: .rect(cornerRadius: 20))
                            .compositingGroup()
                            .opacity(0.5)
                        }
                    }
                    .padding([.horizontal, .bottom], 15)
                    .padding(.top, 12)
                }
                .navigationTitle(currentStation.name)
                .toolbarTitleDisplayMode(.inlineLarge)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close) {
                            dismiss()
                        }
                    }

                    if !isCollapsed {
                        ToolbarItem(placement: .bottomBar) {
                            Button {
                                selection.toggleFavorite()
                            } label: {
                                Image(systemName: selection.isFavorite ? "star.fill" : "star")
                                    .contentTransition(
                                        reduceMotion
                                            ? .identity
                                            : .symbolEffect(
                                                .replace.magic(fallback: .offUp.byLayer),
                                                options: .nonRepeating
                                            )
                                    )
                            }
                            .tint(selection.isFavorite ? .orange : .primary)
                            .accessibilityLabel("Favoris")
                            .accessibilityValue(selection.isFavorite ? "Ajoutée" : "Non ajoutée")
                            .accessibilityHint("Ajoute ou retire cette station des favoris.")
                        }

                        ToolbarSpacer(.flexible, placement: .bottomBar)
                    }
                }
            }
        }
        .detailSheetPresentation(isLargeScreen: isLargeScreen, selection: $detailDetent)
    }

    private func accessibilityTint(_ condition: StationAccessibility.Condition) -> Color {
        switch condition {
        case .autonomous: .green
        case .staffAssistance: .blue
        case .reservationRequired: .orange
        }
    }

    private func accessibilityVoiceOverValue(_ accessibility: StationAccessibility) -> String {
        if let comment = accessibility.comment, !comment.isEmpty {
            return "\(accessibility.label). \(comment)"
        }
        return accessibility.label
    }
}

#Preview {
    @Previewable @State var detailDetent: PresentationDetent = .large
    let locationModel = LocationModel(adapter: InMemoryLocationAdapter())
    let accountModel: AccountModel = {
        let model = AccountModel(
            remote: InMemoryAccountRemote(),
            synchronizationEnabled: false
        )
        model.activateAnonymous()
        return model
    }()
    let selection: SelectedStationModel = {
        let model = SelectedStationModel(
            departuresRepository: InMemoryDeparturesRepository.stationsPreview,
            account: accountModel,
            locationModel: locationModel
        )
        model.select(StationOverview.preview)
        return model
    }()

    StationDetailView(
        selection: selection,
        isLargeScreen: false,
        detailDetent: $detailDetent
    )
}
