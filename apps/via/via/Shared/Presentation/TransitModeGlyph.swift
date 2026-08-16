import SwiftUI

extension TransitMode {
    /// French display name shared by mode labels and accessibility strings.
    var displayName: String {
        switch self {
        case .metro: "Métro"
        case .rer: "RER"
        case .transilien: "Transilien"
        case .tram: "Tram"
        case .bus: "Bus"
        }
    }

    /// The compact glyph badge views draw for this mode.
    @ViewBuilder var glyph: some View {
        switch self {
        case .metro:
            Text("M")
        case .rer:
            Text("RER")
        case .transilien:
            Image(systemName: "train.side.front.car")
        case .tram:
            Image(systemName: "tram.fill")
        case .bus:
            Image(systemName: "bus.fill")
        }
    }
}
