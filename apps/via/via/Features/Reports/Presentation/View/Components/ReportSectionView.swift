import SwiftUI

struct ReportSectionView: View {
    let section: ReportSection
    let categories: [ReportCategory]
    let isSubmitting: Bool
    let onSelect: (ReportCategory) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .kerning(0.8)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(categories) { category in
                    Button {
                        onSelect(category)
                    } label: {
                        ReportCategoryCard(
                            category: category,
                            isDisabled: isSubmitting
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                    .accessibilityLabel(category.title)
                    .accessibilityHint("Envoie un signalement pour cette observation")
                }
            }
        }
    }
}
