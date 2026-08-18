import SwiftUI

struct SearchDateInput: View {
    let date: Date
    let action: () -> Void

    var body: some View {
        SearchInputToken(
            title: date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)),
            subtitle: nil,
            accessibilityLabel: "Date de départ \(date.formatted(date: .long, time: .omitted))",
            expands: true,
            action: action
        )
    }
}

#Preview {
    SearchDateInput(date: .now, action: {})
        .padding()
}
