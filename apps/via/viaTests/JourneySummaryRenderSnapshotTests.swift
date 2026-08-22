import SwiftUI
import XCTest

@testable import Via

@MainActor
final class JourneySummaryRenderSnapshotTests: XCTestCase {
  private let outputDirectory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["VIA_SNAPSHOT_DIR"] ?? NSTemporaryDirectory())

  func testRenderSummaryCard() throws {
    let base = JourneyResult.mapPreview.journeys[0]
    let longNames = try renamedEndpoints(
      of: base,
      origin: "43 Rue de Chabrol (Paris)",
      destination: "7 Allée des Chevaux-Rû (Chatou)"
    )

    try render(name: "summary-light", scheme: .light) {
      VStack(spacing: 20) {
        JourneyDetailSummaryView(journey: base, source: .realtime)
        JourneyDetailSummaryView(journey: longNames, source: .theoretical)
      }
    }

    try render(name: "summary-dark", scheme: .dark) {
      VStack(spacing: 20) {
        JourneyDetailSummaryView(journey: base, source: .realtime)
        JourneyDetailSummaryView(journey: longNames, source: .theoretical)
      }
    }
  }

  private func render<Content: View>(
    name: String,
    scheme: ColorScheme,
    @ViewBuilder content: () -> Content
  ) throws {
    let renderer = ImageRenderer(
      content: content()
        .padding(16)
        .frame(width: 393)
        .background(Color(uiColor: .systemBackground))
        .environment(\.colorScheme, scheme)
    )
    renderer.scale = 3
    guard let image = renderer.uiImage, let data = image.pngData() else {
      return XCTFail("render failed for \(name)")
    }
    let url = outputDirectory.appendingPathComponent("\(name).png")
    try data.write(to: url)
    print("SNAPSHOT \(url.path)")
  }

  private func renamedEndpoints(of journey: Journey, origin: String, destination: String) throws -> Journey {
    let data = try JSONEncoder().encode(journey)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var sections = try XCTUnwrap(object["sections"] as? [[String: Any]])
    var first = sections[0]
    var from = try XCTUnwrap(first["from"] as? [String: Any])
    from["name"] = origin
    first["from"] = from
    sections[0] = first
    var last = sections[sections.count - 1]
    var to = try XCTUnwrap(last["to"] as? [String: Any])
    to["name"] = destination
    last["to"] = to
    sections[sections.count - 1] = last
    object["sections"] = sections
    let patched = try JSONSerialization.data(withJSONObject: object)
    return try JSONDecoder().decode(Journey.self, from: patched)
  }
}
