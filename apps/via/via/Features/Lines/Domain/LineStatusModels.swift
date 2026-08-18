import Foundation

/// A serializable design token used by line fixtures and repositories. The
/// view layer turns it into SwiftUI `Color`, keeping domain data Sendable.
struct ColorToken: Codable, Sendable, Hashable, Equatable {
    let name: String
    let hex: String
    let textHex: String

    init(name: String, hex: String, textHex: String = "#FFFFFF") {
        self.name = name
        self.hex = hex
        self.textHex = textHex
    }
}

enum LineCondition: String, Codable, CaseIterable, Sendable, Hashable, Equatable {
    case normal
    case attention
    case disrupted
    case suspended
    case unavailable

    var title: String {
        switch self {
        case .normal: "Normal"
        case .attention: "Attention"
        case .disrupted: "Perturbée"
        case .suspended: "Suspendue"
        case .unavailable: "Indisponible"
        }
    }

    var systemImage: String {
        switch self {
        case .normal: "checkmark.circle.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .disrupted: "exclamationmark.octagon.fill"
        case .suspended: "xmark.octagon.fill"
        case .unavailable: "wifi.exclamationmark"
        }
    }

    /// Lower values are shown first in the Lines tab so disruption is never
    /// buried below healthy services.
    var severity: Int {
        switch self {
        case .suspended: 0
        case .disrupted: 1
        case .attention: 2
        case .unavailable: 3
        case .normal: 4
        }
    }
}

struct LineStatus: Identifiable, Codable, Sendable, Hashable, Equatable {
    let id: String
    let name: String
    let mode: TransitMode
    let color: ColorToken
    let condition: LineCondition
    let summary: String
    let affectedStops: [String]
    let updatedAt: Date?

    // These two fields make the fixture useful for the native filter menus.
    // They can be mapped from the future service/network payload without
    // changing the view contract.
    let network: String
    let direction: String

    init(
        id: String,
        name: String,
        mode: TransitMode,
        color: ColorToken,
        condition: LineCondition,
        summary: String,
        affectedStops: [String],
        updatedAt: Date?,
        network: String = "Île-de-France",
        direction: String = "Toutes directions"
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.color = color
        self.condition = condition
        self.summary = summary
        self.affectedStops = affectedStops
        self.updatedAt = updatedAt
        self.network = network
        self.direction = direction
    }

    func matchesSearch(_ query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return false }

        let fields = [
            name,
            mode.rawValue,
            network,
            direction,
            summary,
            affectedStops.joined(separator: " "),
        ]
        let haystack = fields.joined(separator: " ")
        let foldingOptions: String.CompareOptions = [
            .caseInsensitive,
            .diacriticInsensitive,
        ]
        let foldedHaystack = haystack.folding(
            options: foldingOptions,
            locale: Locale.current
        )
        let foldedQuery = trimmedQuery.folding(
            options: foldingOptions,
            locale: Locale.current
        )
        return foldedQuery
            .split(whereSeparator: \.isWhitespace)
            .allSatisfy { foldedHaystack.contains(String($0)) }
    }
}

protocol LineStatusRepository: Sendable {
    func loadStatuses() async throws -> [LineStatus]
}
