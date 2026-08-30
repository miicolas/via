import Foundation
import Observation

@MainActor
@Observable
final class FriendsModel {
    private(set) var state: Loadable<[ViaFriend]> = .idle
    private(set) var invitationLink: FriendInvitationLink?
    private(set) var invitationPreview: Loadable<FriendInvitationPreview> = .idle
    private(set) var pendingInvitationToken: String?
    private(set) var errorMessage: String?

    @ObservationIgnored private let repository: any FriendsRepository

    init(repository: any FriendsRepository) {
        self.repository = repository
    }

    var friends: [ViaFriend] { state.value ?? [] }

    func load() async {
        state = .loading(previous: state.value)
        do {
            state = .loaded(try await repository.list())
        } catch {
            state = .failed(error.via, previous: state.value)
        }
    }

    func createInvitation() async {
        do {
            invitationLink = try await repository.createInvitation()
        } catch {
            errorMessage = "L’invitation d’ami n’a pas pu être créée."
        }
    }

    func prepareInvitation(token: String) async {
        pendingInvitationToken = token
        invitationPreview = .loading(previous: nil)
        do {
            invitationPreview = .loaded(try await repository.previewInvitation(token: token))
        } catch {
            invitationPreview = .failed(error.via, previous: nil)
        }
    }

    func acceptInvitation() async -> Bool {
        guard let token = pendingInvitationToken else { return false }
        do {
            let friend = try await repository.acceptInvitation(token: token)
            state = .loaded((friends.filter { $0.id != friend.id } + [friend]).sorted {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            })
            pendingInvitationToken = nil
            invitationPreview = .idle
            return true
        } catch {
            errorMessage = "Cette invitation d’ami ne peut pas être acceptée."
            return false
        }
    }

    @discardableResult
    func remove(_ friend: ViaFriend) async -> Bool {
        do {
            try await repository.remove(userId: friend.id)
            state = .loaded(friends.filter { $0.id != friend.id })
            return true
        } catch {
            errorMessage = "Cet ami n’a pas pu être supprimé."
            return false
        }
    }

    func clearInvitationLink() { invitationLink = nil }
    func clearError() { errorMessage = nil }
}
