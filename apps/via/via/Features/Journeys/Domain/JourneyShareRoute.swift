import Foundation

struct JourneyShareRoute: Identifiable, Hashable, Sendable {
    let token: String

    var id: String { token }
}
