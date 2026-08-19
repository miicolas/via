import SwiftUI

/// Tabs hosted by the persistent map sheet. `search` is rendered through
/// `Tab(role: .search)`, which gives it the detached magnifier slot in the tab bar.
enum MapShellTab: String, Hashable {
    case stations = "Stations"
    case lines = "Lignes"
    case report = "Signaler"
    case search = "Recherche"

    var symbolImage: String {
        switch self {
        case .stations: return "tram.fill"
        case .lines: return "point.3.connected.trianglepath.dotted"
        case .report: return "exclamationmark.bubble.fill"
        case .search: return "magnifyingglass"
        }
    }

    @ViewBuilder
    var tabLabel: some View {
        Image(systemName: symbolImage)
        Text(rawValue)
    }
}
