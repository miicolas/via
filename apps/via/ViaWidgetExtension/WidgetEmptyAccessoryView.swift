import SwiftUI
import WidgetKit

/// The empty state on the Lock Screen.
///
/// A separate shape rather than a size of `WidgetEmptyStateView`: an inline
/// accessory renders one `Text` or one `Label` and nothing else, so the
/// centred column the Home Screen shows cannot simply be shrunk into it.
struct WidgetEmptyAccessoryView: View {
    let systemImage: String
    let title: String
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: systemImage)
                    .font(.title3)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)

        default:
            Label(title, systemImage: systemImage)
                .accessibilityLabel(title)
        }
    }
}
