import Foundation
import Observation

struct MeetupInvitationRoute: Identifiable, Sendable, Hashable {
    let token: String
    let key: String?
    var id: String { token }
}

@MainActor
@Observable
final class MeetupsModel {
    private(set) var state: Loadable<[Meetup]> = .idle
    private(set) var pendingInvitations: [MeetupPendingInvitation] = []
    private(set) var selectedMeetup: Meetup?
    private(set) var requestedMeetup: Meetup?
    private(set) var invitationRoute: MeetupInvitationRoute?
    private(set) var invitationState: Loadable<MeetupInvitationPreview> = .idle
    private(set) var searchResults: [SearchResult] = []
    private(set) var isSearching = false
    private(set) var isMutating = false
    private(set) var errorMessage: String?
    var composeDestination: MeetupStation?

    @ObservationIgnored let live: any MeetupLiveSharing
    @ObservationIgnored private let repository: any MeetupRepository
    @ObservationIgnored private let searchRepository: any SearchRepository
    @ObservationIgnored private let locationModel: LocationModel

    init(
        repository: any MeetupRepository,
        searchRepository: any SearchRepository,
        locationModel: LocationModel,
        live: any MeetupLiveSharing
    ) {
        self.repository = repository
        self.searchRepository = searchRepository
        self.locationModel = locationModel
        self.live = live
    }

    var meetups: [Meetup] { state.value ?? [] }

    func load() async {
        state = .loading(previous: state.value)
        do {
            let listing = try await repository.list()
            state = .loaded(listing.meetups)
            pendingInvitations = listing.pendingInvitations
            errorMessage = nil
        } catch {
            state = .failed(error.via, previous: state.value)
        }
    }

    func select(_ meetup: Meetup) async {
        selectedMeetup = meetup
        await attempt {
            let fresh = try await repository.load(meetupId: meetup.id)
            selectedMeetup = fresh
            replace(fresh)
        }
    }

    func open(meetupId: String) async {
        await attempt {
            let meetup = try await repository.load(meetupId: meetupId)
            selectedMeetup = meetup
            requestedMeetup = meetup
            replace(meetup)
        }
    }

    func consumeRequestedMeetup() {
        requestedMeetup = nil
    }

    func create(
        destination: MeetupStation,
        arrival: Date,
        displayName: String,
        origin: MeetupOrigin,
        shareLevel: MeetupShareLevel
    ) async -> Meetup? {
        isMutating = true
        defer { isMutating = false }
        return await attempt {
            let meetup = try await repository.create(
                destination: destination,
                targetArrivalAt: arrival,
                organizerDisplayName: normalizedName(displayName),
                origin: origin,
                shareLevel: shareLevel
            )
            replace(meetup)
            selectedMeetup = meetup
            errorMessage = nil
            return meetup
        }
    }

    func search(_ query: String, stationsOnly: Bool) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        let response = await attempt {
            try await searchRepository.search(
                query: trimmed,
                near: locationModel.coordinate
            )
        }
        guard let response else {
            searchResults = []
            return
        }
        searchResults = response.results.filter { result in
            if case .bikeStation = result { return false }
            if stationsOnly, case .address = result { return false }
            return true
        }
    }

    func currentOrigin() async -> MeetupOrigin? {
        guard let coordinate = await locationModel.requestCurrentLocation() else {
            errorMessage = "La position actuelle est indisponible."
            return nil
        }
        return .currentLocation(coordinate)
    }

    func prepareInvitation(token: String, key: String?) async {
        let route = MeetupInvitationRoute(token: token, key: key)
        invitationRoute = route
        invitationState = .loading(previous: nil)
        do {
            invitationState = .loaded(try await repository.previewInvitation(token: token))
        } catch {
            invitationState = .failed(error.via, previous: nil)
        }
    }

    func dismissInvitation() {
        invitationRoute = nil
        invitationState = .idle
    }

    func acceptInvitation(
        displayName: String,
        origin: MeetupOrigin,
        shareLevel: MeetupShareLevel
    ) async -> Bool {
        guard let invitationRoute else { return false }
        let invitationToken = invitationRoute.token
        isMutating = true
        defer { isMutating = false }
        let accepted: Void? = await attempt {
            let meetup = try await repository.acceptInvitation(
                token: invitationRoute.token,
                groupKey: invitationRoute.key,
                displayName: normalizedName(displayName),
                origin: origin,
                shareLevel: shareLevel
            )
            replace(meetup)
            selectedMeetup = meetup
            pendingInvitations.removeAll { $0.token == invitationToken }
            dismissInvitation()
        }
        return accepted != nil
    }

    func declineInvitation() async {
        guard let invitationRoute else { return }
        let invitationToken = invitationRoute.token
        await attempt {
            try await repository.declineInvitation(token: invitationRoute.token)
            pendingInvitations.removeAll { $0.token == invitationToken }
            dismissInvitation()
        }
    }

    func setShareLevel(_ level: MeetupShareLevel) async {
        guard let fresh = await mutateSelected(
            .configure(origin: nil, shareLevel: level, zone: nil)
        ) else { return }
        await live.applyShareLevelChange(fresh)
    }

    func setZone(_ zone: MeetupZone) async {
        // Deliberately does not notify `live`: the zone changes where the
        // group meets on the platform, never what this participant shares,
        // and the coordinator picks the refreshed meetup up from polling.
        await mutateSelected(.configure(origin: nil, shareLevel: nil, zone: zone))
    }

    func createInvitation(invitedUserId: String? = nil) async -> MeetupInvitationLink? {
        guard let meetup = selectedMeetup else { return nil }
        isMutating = true
        defer { isMutating = false }
        let link = await attempt {
            try await repository.invitation(
                meetupId: meetup.id,
                invitedUserId: invitedUserId
            )
        }
        guard let link else { return nil }
        selectedMeetup = try? await repository.load(meetupId: meetup.id)
        return link
    }

    func update(destination: MeetupStation, arrival: Date) async -> Bool {
        isMutating = true
        defer { isMutating = false }
        guard await mutateSelected(
            .update(destination: destination, targetArrivalAt: arrival)
        ) != nil else { return false }
        errorMessage = nil
        return true
    }

    func revoke(_ invitation: MeetupInvitation) async {
        await mutateSelected(.revokeInvitation(id: invitation.id))
    }

    func remove(_ participant: MeetupParticipant) async {
        await mutateSelected(.removeParticipant(id: participant.id))
    }

    func leave() async -> Bool {
        guard let meetup = selectedMeetup else { return false }
        await stopLiveIfActive(for: meetup)
        let left: Void? = await attempt {
            try await repository.leave(meetupId: meetup.id)
            remove(meetup.id)
            selectedMeetup = nil
        }
        return left != nil
    }

    func cancel() async -> Bool {
        guard let meetup = selectedMeetup else { return false }
        await stopLiveIfActive(for: meetup)
        return await mutateSelected(.cancel) != nil
    }

    func clearError() { errorMessage = nil }

    /// Every meetup-scoped edit funnels through here: send the change, then
    /// adopt the refreshed meetup as both the selection and the list entry.
    @discardableResult
    private func mutateSelected(_ change: MeetupChange) async -> Meetup? {
        guard let meetup = selectedMeetup else { return nil }
        return await attempt {
            let fresh = try await repository.mutate(meetupId: meetup.id, change: change)
            selectedMeetup = fresh
            replace(fresh)
            return fresh
        }
    }

    /// The one catch body: a failed operation surfaces as `errorMessage` and
    /// answers nil so callers can branch without their own do/catch.
    @discardableResult
    private func attempt<T>(_ operation: @MainActor () async throws -> T) async -> T? {
        do {
            return try await operation()
        } catch {
            errorMessage = message(for: error.via)
            return nil
        }
    }

    private func stopLiveIfActive(for meetup: Meetup) async {
        guard live.activeMeetup?.id == meetup.id else { return }
        await live.stop(publishing: nil)
    }

    private func replace(_ meetup: Meetup) {
        var values = meetups.filter { $0.id != meetup.id }
        values.append(meetup)
        values.sort { $0.targetArrivalAt < $1.targetArrivalAt }
        state = .loaded(values)
    }

    private func remove(_ id: String) {
        state = .loaded(meetups.filter { $0.id != id })
    }

    private func normalizedName(_ name: String) -> String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Invité Via" : value
    }

    private func message(for error: ViaError) -> String {
        switch error {
        case .unauthorized: "Cette action n’est pas autorisée."
        case .rateLimited: "Trop de demandes. Réessayez dans un instant."
        case .unavailable, .transport: "Rendez-vous est momentanément indisponible."
        case .decoding: "La réponse du rendez-vous est illisible."
        case .server(let statusCode) where statusCode == 409: "Le groupe est complet ou vient de changer."
        default: "Cette action n’a pas pu être effectuée."
        }
    }
}
