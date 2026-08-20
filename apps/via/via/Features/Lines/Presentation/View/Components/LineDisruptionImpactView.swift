import SwiftUI

struct LineDisruptionImpactView: View {
    let sections: [LineImpactedSection]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if sections.isEmpty {
                impactRow(for: nil)
            } else {
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    impactRow(for: section)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func impactRow(for section: LineImpactedSection?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            if let section, let names = validNames(for: section) {
                Text(names.from)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(names.to)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Zone concernée non précisée")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: section))
        .padding(.vertical, 6)
    }

    private func validNames(for section: LineImpactedSection) -> (from: String, to: String)? {
        guard !section.fromName.isEmpty,
              !section.toName.isEmpty,
              section.fromName != section.toName else {
            return nil
        }
        return (section.fromName, section.toName)
    }

    private func accessibilityLabel(for section: LineImpactedSection?) -> String {
        guard let section, let names = validNames(for: section) else {
            return "Zone concernée non précisée"
        }
        return "Entre \(names.from) et \(names.to)"
    }
}
