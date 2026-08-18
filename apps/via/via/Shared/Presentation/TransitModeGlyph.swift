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

    /// SF Symbol shown on journey segment chips next to the line name.
    var chipSystemImage: String {
        switch self {
        case .metro: "tram.fill.tunnel"
        case .rer, .transilien: "train.side.front.car"
        case .tram: "tram.fill"
        case .bus: "bus.fill"
        }
    }

    /// The compact glyph badge views draw for this mode. Métro and RER keep
    /// their lettered badges; the other modes reuse the chip symbol.
    @ViewBuilder var glyph: some View {
        switch self {
        case .metro:
            Text("M")
        case .rer:
            Text("RER")
        case .transilien, .tram, .bus:
            Image(systemName: chipSystemImage)
        }
    }
}
