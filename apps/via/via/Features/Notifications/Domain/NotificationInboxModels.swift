import Foundation

struct NotificationInboxItem: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let occurrenceID: String?
    let category: NotificationCategory
    let title: String
    let body: String
    let deepLink: String?
    let topicKind: NotificationAlertSubscription.TopicKind?
    let topicID: String?
    let severity: NotificationSeverity?
    let dropReason: String?
    let createdAt: Date
    let readAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case occurrenceID = "occurrenceId"
        case category, title, body, deepLink, topicKind
        case topicID = "topicId"
        case severity, dropReason, createdAt, readAt
    }
}

struct NotificationInboxPage: Codable, Sendable, Hashable {
    let items: [NotificationInboxItem]
    let nextCursor: String?
    let unreadCount: Int
}

protocol NotificationInboxRemote: Sendable {
    func page(cursor: String?, limit: Int) async throws -> NotificationInboxPage
    func markRead(before date: Date) async throws
}

struct NoOpNotificationInboxRemote: NotificationInboxRemote {
    func page(cursor: String?, limit: Int) async throws -> NotificationInboxPage {
        NotificationInboxPage(items: [], nextCursor: nil, unreadCount: 0)
    }

    func markRead(before date: Date) async throws {}
}
