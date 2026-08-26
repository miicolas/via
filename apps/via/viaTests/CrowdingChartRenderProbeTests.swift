import SwiftUI
import UIKit
import XCTest

@testable import Via

@MainActor
final class CrowdingChartRenderProbeTests: XCTestCase {
    func testSnapshotSectionAndChart() throws {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let section = StationCrowdingSection(crowding: .preview, isLoaded: true)
            .padding(20)
            .frame(width: 402)
            .background(Color(white: 0.08))
            .environment(\.colorScheme, .dark)

        let host = UIHostingController(rootView: section)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 420)
        window.rootViewController = host
        window.makeKeyAndVisible()

        func snap(_ name: String) throws {
            let bounds = window.bounds
            let renderer = UIGraphicsImageRenderer(bounds: bounds)
            let image = renderer.image { _ in
                window.drawHierarchy(in: bounds, afterScreenUpdates: true)
            }
            try image.pngData()!.write(to: URL(fileURLWithPath: "/tmp/fluffy-\(name).png"))
        }

        let expectation = XCTestExpectation(description: "frames")
        Task {
            try await Task.sleep(for: .milliseconds(180))
            try snap("growing")
            try await Task.sleep(for: .milliseconds(1200))
            try snap("settled")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10)
        window.isHidden = true
    }
}
