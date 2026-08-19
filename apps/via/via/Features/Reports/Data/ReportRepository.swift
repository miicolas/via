import Foundation

protocol ReportRepository: Sendable {
    func submit(_ report: ReportSubmission) async throws
}

/// Local seam for the report flow until the API exposes a report endpoint.
/// Keeping submissions here makes the UI testable and leaves room for an
/// offline queue without coupling the screen to networking.
actor InMemoryReportRepository: ReportRepository {
    private(set) var submissions: [ReportSubmission] = []

    func submit(_ report: ReportSubmission) {
        submissions.append(report)
    }

    func allSubmissions() -> [ReportSubmission] {
        submissions
    }
}
