import MapKit
import SwiftUI

struct MeetupMapView: View {
    let meetup: Meetup
    let live: [MeetupLiveParticipant]
    let preciseLocations: [String: MeetupPreciseLocation]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position: MapCameraPosition = .automatic
    @State private var selection: String?

    var body: some View {
        Map(position: $position, selection: $selection) {
            if let authorizedRoute {
                JourneyRouteMapContent(presentation: authorizedRoute)
            }

            Marker(
                meetup.destination.name,
                systemImage: "flag.checkered",
                coordinate: meetup.destination.coordinate.clLocationCoordinate
            )
            .tint(.blue)
            .tag("destination")

            ForEach(meetup.participants) { participant in
                if let precise = preciseLocations[participant.id] {
                    Marker(
                        participant.displayName,
                        systemImage: "person.crop.circle.fill",
                        coordinate: CLLocationCoordinate2D(
                            latitude: precise.latitude,
                            longitude: precise.longitude
                        )
                    )
                    .tint(.green)
                    .tag(participant.id)
                } else if let station = liveParticipant(participant.id)?.progress?.station {
                    Marker(
                        participant.displayName,
                        systemImage: "tram.fill",
                        coordinate: station.coordinate.clLocationCoordinate
                    )
                    .tint(.secondary)
                    .tag(participant.id)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .frame(height: 340)
        .clipShape(.rect(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            if selection != nil {
                GlassEffectContainer(spacing: 10) {
                    selectionCallout
                        .padding(14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 18))
                }
                .padding(12)
                .transition(reduceMotion ? .identity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: selection)
        .haptic(Haptic.selection, on: selection)
        .accessibilityLabel("Carte du rendez-vous")
        .accessibilityHint("Touchez une personne ou la destination pour afficher son détail")
    }

    @ViewBuilder
    private var selectionCallout: some View {
        if selection == "destination" {
            HStack(spacing: 12) {
                Image(systemName: "flag.checkered")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(meetup.destination.name)
                        .font(.headline)
                    Text("Destination commune")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
            }
        } else if let selection,
                  let participant = meetup.participants.first(where: { $0.id == selection }) {
            HStack(spacing: 12) {
                InitialsAvatarView(
                    name: participant.displayName,
                    size: 38,
                    tint: .blue,
                    isLive: liveParticipant(participant.id)?.freshness == .live
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(participant.displayName)
                        .font(.headline)
                    Text(detail(for: participant))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                Image(systemName: participant.shareLevel.systemImage)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
    }

    private func liveParticipant(_ id: String) -> MeetupLiveParticipant? {
        live.first { $0.participantId == id }
    }

    /// Only the current participant's journey is present in the private API
    /// projection. Other participants remain limited to their first boarding,
    /// common sections and consented live state.
    private var authorizedRoute: JourneyMapPresentation? {
        meetup.plan?.participantJourneys
            .first { $0.participantId == meetup.currentParticipantId }
            .flatMap(\.journey)
            .map { JourneyMapPresentation(journey: $0) }
    }

    private func detail(for participant: MeetupParticipant) -> String {
        if let precise = preciseLocations[participant.id] {
            let accuracy = precise.horizontalAccuracy.map { " · précision ±\(Int($0.rounded())) m" } ?? ""
            return "\(participant.zone.title) · mis à jour \(precise.recordedAt.formatted(.relative(presentation: .named)))\(accuracy)"
        }
        if let station = liveParticipant(participant.id)?.progress?.station {
            return "Progression seule · \(station.name) · \(participant.zone.title)"
        }
        return "Aucune position en direct"
    }
}
