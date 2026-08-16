import SwiftUI
import MapKit

extension MKCoordinateRegion {
    static let paris = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
        latitudinalMeters: 1_000,
        longitudinalMeters: 1_000
    )
}

// Tab item
enum TabItem: String, Hashable {
    case People = "People"
    case Places = "Places"
    case Me = "Me"
    
    var symbolImage: String {
        switch self {
        case .People:
            return "person.crop.circle.badge.ellipsis"
        case .Places:
            return "map"
        case .Me:
            return "person.crop.circle"
        }
    }
    
    @ContentBuilder var tabLabel: some View {
        Image(systemName: self.symbolImage)
        Text(self.rawValue)
    }
    
}

struct RootView: View {
    @State private var showTabView: Bool = true
    @State private var activeTab: TabItem = .People
    
    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion.paris)
        ).sheet(isPresented: $showTabView) {
            SheetTabView(selection: $activeTab) {
                Tab("People", systemImage: TabItem.People.symbolImage, value: .People) {
                    Text("People")
                }
                Tab("Places", systemImage: TabItem.Places.symbolImage, value: .Places) {
                    Text("Places")
                }
                Tab("Me", systemImage: TabItem.Me.symbolImage, value: .Me) {
                    Text("Me")
                }
                Tab("Me", systemImage: TabItem.Me.symbolImage, value: .Me) {
                    Text("Me")
                }
                Tab("Me", systemImage: TabItem.Me.symbolImage, value: .Me) {
                    Text("Me")
                }
                
            }
        }
        
    }
}

#Preview {
    RootView()
}
