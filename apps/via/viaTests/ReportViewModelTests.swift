import XCTest
@testable import Via

@MainActor
final class ReportViewModelTests: XCTestCase {
    func testSubmittingReportPersistsRoundedLocationAndShowsConfirmation() async {
        let coordinate = GeoCoordinate(latitude: 48.85661234, longitude: 2.35229876)
        let locationModel = LocationModel(
            adapter: InMemoryLocationAdapter(coordinate: coordinate)
        )
        let repository = InMemoryReportRepository()
        let observedAt = Date(timeIntervalSince1970: 1_000_000)
        let model = ReportViewModel(
            locationModel: locationModel,
            repository: repository,
            now: { observedAt }
        )

        model.submit(.airConditioningPresent)

        for _ in 0..<5 {
            await Task.yield()
        }

        let submissions = await repository.allSubmissions()
        XCTAssertEqual(submissions.count, 1)
        XCTAssertEqual(submissions.first?.category, .airConditioningPresent)
        XCTAssertEqual(
            submissions.first?.context.coordinate,
            coordinate.roundedForSearch
        )
        XCTAssertEqual(submissions.first?.observedAt, observedAt)
        XCTAssertEqual(
            model.state,
            .completed(submissions[0])
        )
    }

    func testSubmittingWithoutLocationStillCreatesAnObservation() async {
        let locationModel = LocationModel(
            adapter: InMemoryLocationAdapter(
                authorization: .denied,
                coordinate: nil
            )
        )
        let repository = InMemoryReportRepository()
        let model = ReportViewModel(
            locationModel: locationModel,
            repository: repository
        )

        model.submit(.crowding)

        for _ in 0..<5 {
            await Task.yield()
        }

        let submission = await repository.allSubmissions().first
        XCTAssertEqual(submission?.category, .crowding)
        XCTAssertNil(submission?.context.coordinate)
    }
}
