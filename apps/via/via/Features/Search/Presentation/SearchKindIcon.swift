import SwiftUI

/// One icon vocabulary for the station/address distinction, shared by result
/// rows and quick-destination cards.
extension RecentSearch.Kind {
    var iconSystemImage: String {
        switch self {
        case .station: "tram.fill"
        case .address: "mappin"
        }
    }

    var iconColor: Color {
        switch self {
        case .station: .blue
        case .address: .red
        }
    }
}
