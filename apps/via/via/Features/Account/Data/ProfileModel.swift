import Foundation
import Observation

@MainActor
@Observable
final class ProfileModel {
    private(set) var scope: ProfileScope = .anonymous
    private(set) var snapshot: ProfileSnapshot = .empty
    private(set) var errorMessage: String?

    var draftName = ""
    var draftAvatarData: Data?

    @ObservationIgnored private let store: any ProfileStoring
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var hasActivated = false

    init(
        store: any ProfileStoring = LocalProfileStore(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.store = store
        self.now = now
    }

    var displayName: String { snapshot.normalizedDisplayName }
    var avatarData: Data? { snapshot.avatarData }
    var initials: String? { snapshot.initials }

    var canSaveDraft: Bool {
        !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func activate(scope: ProfileScope, seedName: String? = nil) {
        guard !hasActivated || self.scope != scope else { return }
        hasActivated = true
        self.scope = scope
        do {
            if let stored = try store.load(scope: scope) {
                snapshot = stored
            } else {
                snapshot = ProfileSnapshot(
                    displayName: seedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    avatarData: nil,
                    updatedAt: .distantPast
                )
            }
            errorMessage = nil
        } catch {
            snapshot = .empty
            errorMessage = "Le profil enregistré n’a pas pu être chargé."
        }
        beginEditing()
    }

    func beginEditing() {
        draftName = snapshot.displayName
        draftAvatarData = snapshot.avatarData
        errorMessage = nil
    }

    func discardEditing() {
        beginEditing()
    }

    func setAvatarData(_ data: Data?) {
        draftAvatarData = data
        errorMessage = nil
    }

    func importContact(_ contact: ProfileContact) {
        if let displayName = contact.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            draftName = displayName
        }
        if let avatarData = contact.avatarData {
            draftAvatarData = avatarData
        }
        errorMessage = nil
    }

    @discardableResult
    func saveEditing() -> Bool {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        let next = ProfileSnapshot(displayName: name, avatarData: draftAvatarData, updatedAt: now())
        do {
            try store.save(next, scope: scope)
            snapshot = next
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Le profil n’a pas pu être enregistré. Réessaie."
            return false
        }
    }

    func eraseCurrentProfile() {
        eraseProfile(scope: scope)
    }

    func eraseProfile(scope: ProfileScope) {
        do {
            try store.erase(scope: scope)
            if self.scope == scope {
                snapshot = .empty
                beginEditing()
            }
        } catch {
            errorMessage = "Le profil local n’a pas pu être supprimé."
        }
    }

    func eraseAllProfiles() {
        do {
            try store.eraseAll()
            snapshot = .empty
            beginEditing()
        } catch {
            errorMessage = "Les profils locaux n’ont pas pu être supprimés."
        }
    }
}
