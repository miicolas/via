import Foundation

/// The French mode name a widget shows beside a line.
///
/// One mapping for both sides: the app projects it into the snapshot, and the
/// extension applies it to the statuses it reads from the API itself. A second
/// copy would let a Home Screen tile and a Lock Screen tile name the same mode
/// differently. `WidgetFavoritesProjectionTests` pins it to the app's own
/// `TransitMode.displayName`.
enum WidgetTransitModeName {
    static func french(forMode rawValue: String) -> String {
        switch rawValue {
        case "metro": "Métro"
        case "rer": "RER"
        case "transilien": "Transilien"
        case "tram": "Tram"
        case "bus": "Bus"
        default: "Ligne"
        }
    }
}
