import Foundation

/// Turns a fresh, real Core Location fix into the deliberately small plaintext
/// progress projection shared by a Rendez-vous.
///
/// The resolver never advances from the timetable alone and never manufactures
/// a GPS point. A station is exposed only when the fix is physically close to
/// a stop; the sole exception is a missed boarding, where the planned boarding
/// station is required by the server to calculate a replacement plan.
enum MeetupProgressResolver {
    static func resolve(
        meetup: Meetup,
        sample: LocationSample,
        previous: MeetupProgress?,
        now: Date
    ) -> MeetupProgress? {
        guard isFresh(sample, at: now),
              previous?.status != .arrived,
              previous?.status != .stopped,
              let journey = meetup.plan?.participantJourneys.first(where: {
                  $0.participantId == meetup.currentParticipantId
              })?.journey
        else { return nil }

        let schedule = ActiveJourneyRules.schedule(for: journey)
        guard !schedule.isEmpty else { return nil }
        let expectedAt = meetup.currentParticipant?.arrivalAt ?? journey.arrivalAt

        if ActiveJourneyRules.hasArrived(
            journey: journey,
            coordinate: sample.coordinate,
            horizontalAccuracy: sample.horizontalAccuracy,
            now: now
        ) {
            let final = schedule[schedule.index(before: schedule.endIndex)]
            return MeetupProgress(
                status: .arrived,
                sectionId: final.section.id,
                serviceId: final.section.serviceID,
                station: meetup.destination,
                expectedAt: expectedAt,
                updatedAt: now
            )
        }

        let sectionIndex = JourneyLocationMatcher.nearestSectionIndex(
            schedule: schedule,
            to: sample.coordinate,
            horizontalAccuracy: sample.horizontalAccuracy
        )

        if let missed = missedBoarding(
            in: schedule,
            matchedSectionIndex: sectionIndex,
            previous: previous,
            coordinate: sample.coordinate,
            now: now
        ) {
            return MeetupProgress(
                status: .missed,
                sectionId: missed.section.id,
                serviceId: missed.section.serviceID,
                station: station(
                    for: missed.section.from,
                    fallbackID: "meetup-boarding:\(missed.section.id)",
                    meetup: meetup
                ),
                expectedAt: missed.startsAt,
                updatedAt: now
            )
        }

        guard let sectionIndex else { return nil }
        let current = schedule[sectionIndex]
        let status: MeetupProgressStatus
        if previous?.status == .joined || hasReachedJoinPoint(
            meetup: meetup,
            serviceID: current.section.serviceID,
            coordinate: sample.coordinate,
            horizontalAccuracy: sample.horizontalAccuracy,
            now: now
        ) {
            status = .joined
        } else if current.section.kind == .transit && now < current.startsAt {
            status = .waiting
        } else {
            status = .underway
        }

        return MeetupProgress(
            status: status,
            sectionId: current.section.id,
            serviceId: current.section.kind == .transit ? current.section.serviceID : nil,
            station: nearbyStation(
                for: current.section,
                coordinate: sample.coordinate,
                horizontalAccuracy: sample.horizontalAccuracy,
                meetup: meetup
            ),
            expectedAt: current.endsAt,
            updatedAt: now
        )
    }

    static func hasMeaningfulChange(
        from previous: MeetupProgress?,
        to next: MeetupProgress
    ) -> Bool {
        guard let previous else { return true }
        return previous.status != next.status
            || previous.sectionId != next.sectionId
            || previous.serviceId != next.serviceId
            || previous.station?.id != next.station?.id
            || previous.expectedAt != next.expectedAt
    }

    private static func isFresh(_ sample: LocationSample, at now: Date) -> Bool {
        let age = now.timeIntervalSince(sample.recordedAt)
        return age >= -5 && age <= ActiveJourneyRules.locationFreshnessInterval
    }

    /// Detects a missed transit only while that service should still be in
    /// progress. A fix already matched farther along the same or a later
    /// section is evidence that the traveller boarded, not that they missed it.
    private static func missedBoarding(
        in schedule: [JourneySectionSchedule],
        matchedSectionIndex: Int?,
        previous: MeetupProgress?,
        coordinate: GeoCoordinate,
        now: Date
    ) -> JourneySectionSchedule? {
        let previousIndex = previous?.sectionId.flatMap { sectionID in
            schedule.firstIndex { $0.section.id == sectionID }
        }

        for (index, entry) in schedule.enumerated() where entry.section.kind == .transit {
            guard now >= entry.startsAt.addingTimeInterval(
                ActiveJourneyRules.missedConnectionGracePeriod
            ), now <= entry.endsAt.addingTimeInterval(
                ActiveJourneyRules.missedConnectionGracePeriod
            ) else { continue }
            if let previousIndex, previousIndex > index { continue }
            if let matchedSectionIndex, matchedSectionIndex > index { continue }

            if matchedSectionIndex == index {
                let distanceFromBoarding = ActiveJourneyRules.distance(
                    from: coordinate,
                    to: entry.section.from.coordinate
                )
                if distanceFromBoarding > 250 { continue }
            }
            return entry
        }
        return nil
    }

    private static func hasReachedJoinPoint(
        meetup: Meetup,
        serviceID: String?,
        coordinate: GeoCoordinate,
        horizontalAccuracy: Double?,
        now: Date
    ) -> Bool {
        guard let serviceID else { return false }
        let radius = max(
            250,
            ActiveJourneyRules.arrivalRadius(horizontalAccuracy: horizontalAccuracy)
        )
        return meetup.plan?.joinPoints.contains { point in
            point.participantIds.contains(meetup.currentParticipantId)
                && point.serviceId == serviceID
                && now >= point.meetAt
                && ActiveJourneyRules.distance(
                    from: coordinate,
                    to: point.station.coordinate
                ) <= radius
        } == true
    }

    private static func nearbyStation(
        for section: JourneySection,
        coordinate: GeoCoordinate,
        horizontalAccuracy: Double?,
        meetup: Meetup
    ) -> MeetupStation? {
        guard section.kind == .transit else { return nil }
        let radius = ActiveJourneyRules.arrivalRadius(horizontalAccuracy: horizontalAccuracy)
        var stations = section.stops.map { stop in
            MeetupStation(
                id: stop.stationID?.rawValue ?? stop.id,
                name: stop.name,
                coordinate: stop.coordinate
            )
        }
        stations.append(station(
            for: section.from,
            fallbackID: "meetup-boarding:\(section.id)",
            meetup: meetup
        ))
        stations.append(station(
            for: section.to,
            fallbackID: "meetup-alighting:\(section.id)",
            meetup: meetup
        ))

        return stations.min {
            ActiveJourneyRules.distance(from: coordinate, to: $0.coordinate)
                < ActiveJourneyRules.distance(from: coordinate, to: $1.coordinate)
        }.flatMap { nearest in
            ActiveJourneyRules.distance(from: coordinate, to: nearest.coordinate) <= radius
                ? nearest
                : nil
        }
    }

    private static func station(
        for place: JourneyPlace,
        fallbackID: String,
        meetup: Meetup
    ) -> MeetupStation {
        let known = [meetup.currentParticipant?.firstBoardingStation]
            .compactMap { $0 }
            + (meetup.plan?.joinPoints.map(\.station) ?? [])
            + [meetup.destination]
        if let nearest = known.min(by: {
            ActiveJourneyRules.distance(from: place.coordinate, to: $0.coordinate)
                < ActiveJourneyRules.distance(from: place.coordinate, to: $1.coordinate)
        }), ActiveJourneyRules.distance(from: place.coordinate, to: nearest.coordinate) <= 300 {
            return nearest
        }
        return MeetupStation(id: fallbackID, name: place.name, coordinate: place.coordinate)
    }
}
