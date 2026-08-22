import Foundation

struct LiveNotificationInboxRemote: NotificationInboxRemote {
    let transport: APITransport

    func page(cursor: String?, limit: Int) async throws -> NotificationInboxPage {
        try await transport.perform("notifications_inbox") { client in
            let query = Operations.notifications_period_inbox.Input.Query(
                cursor: cursor,
                limit: limit
            )
            switch try await client.notifications_period_inbox(.init(query: query)) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: NotificationInboxPage.self)
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func markRead(before date: Date) async throws {
        try await transport.perform("notifications_mark_inbox_read") { client in
            let payload = Operations.notifications_period_markInboxRead.Input.Body.jsonPayload(
                readBefore: date
            )
            switch try await client.notifications_period_markInboxRead(.init(body: .json(payload))) {
            case .ok:
                return
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }
}
