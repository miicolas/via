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

    /// Official Île-de-France Mobilités mode mark used wherever the network
    /// mode itself is being identified, including map annotations and filters.
    ///
    /// Keep this separate from `chipSystemImage`: journey chips intentionally
    /// use compact SF Symbols, while mode-identifying surfaces use the official
    /// vector marks bundled in the asset catalog.
    var logoAssetName: String {
        switch self {
        case .metro: "TransitModeMetro"
        case .rer: "TransitModeRER"
        case .transilien: "TransitModeTransilien"
        case .tram: "TransitModeTram"
        case .bus: "TransitModeBus"
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
