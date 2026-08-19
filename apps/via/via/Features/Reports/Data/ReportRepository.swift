import Foundation

protocol ReportRepository: Sendable {
    func submit(_ submission: ReportSubmission) async throws
}

actor InMemoryReportRepository: ReportRepository {
    private var storedSubmissions: [ReportSubmission] = []

    func submit(_ submission: ReportSubmission) async throws {
        storedSubmissions.append(submission)
    }

    func submissions() -> [ReportSubmission] {
        storedSubmissions
    }
}
