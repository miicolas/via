import SwiftUI

struct ReportCategoryCard: View {
    let category: ReportCategory
    let isDisabled: Bool

    init(category: ReportCategory, isDisabled: Bool = false) {
        self.category = category
        self.isDisabled = isDisabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: category.systemImage)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(category.tint, in: RoundedRectangle(cornerRadius: 22))
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            Text(category.title)
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityElement(children: .combine)
    }
}

private extension ReportCategory {
    var tint: Color {
        switch self {
        case .pickpocket:
            .indigo
        case .crowding:
            .red
        case .restroomsClosed,
             .ticketMachineUnavailable,
             .elevatorsUnavailable:
            .blue
        case .stopMoved,
             .stopNotServed:
            .orange
        case .airConditioningPresent:
            .teal
        }
    }
}
