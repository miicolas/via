import Foundation
import UIKit

func appleMapsDirectionsURL(to coordinate: GeoCoordinate) -> URL? {
    var components = URLComponents(string: "http://maps.apple.com/")
    components?.queryItems = [
        URLQueryItem(
            name: "daddr",
            value: "\(coordinate.latitude),\(coordinate.longitude)"
        ),
        URLQueryItem(name: "dirflg", value: "r"),
    ]
    return components?.url
}

@MainActor
func openAppleMapsDirections(to coordinate: GeoCoordinate) {
    guard let url = appleMapsDirectionsURL(to: coordinate) else { return }
    UIApplication.shared.open(url)
}
