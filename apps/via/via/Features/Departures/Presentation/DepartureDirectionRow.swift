import SwiftUI

struct DepartureDirectionRow: View {
    let destination: String
    let minutes: [Int]
    let source: DepartureBoard.Source

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(destination)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if source == .realtime {
                    Image(systemName: "wave.3.left")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }

                Text(primaryLabel)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()

                if let followingLabel {
                    Text(followingLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(2)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var primaryLabel: String {
        "\(minutes.first ?? 0) min"
    }

    private var followingLabel: String? {
        let following = minutes.dropFirst()
        guard !following.isEmpty else { return nil }
        let values = following.map(String.init)
        let joined = values.count == 1
            ? values[0]
            : "\(values.dropLast().joined(separator: ", ")) et \(values.last!)"
        return "puis \(joined) min"
    }

    private var accessibilityLabel: String {
        let waits = minutes.enumerated().map { index, minute in
            let value = minute == 0
                ? "à quai"
                : "dans \(minute) minute\(minute > 1 ? "s" : "")"
            return index == 0 ? value : "puis \(value)"
        }
        let sourceLabel = switch source {
        case .realtime: "temps réel"
        case .theoretical: "horaires théoriques"
        case .unavailable: "source indisponible"
        }
        return "Direction \(destination), \(waits.joined(separator: ", ")), \(sourceLabel)"
    }
}
