import SwiftUI

/// A person without a profile image still needs a stable visual identity.
/// Initials remain legible at every Dynamic Type size while the optional live
/// dot carries presence without changing the avatar itself into a control.
struct InitialsAvatarView: View {
    let name: String
    var initials: String? = nil
    var size: CGFloat = 48
    var tint: Color = .blue
    var isLive = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(resolvedInitials)
                .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(
                    LinearGradient(
                        colors: [tint.opacity(0.22), tint.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .overlay {
                    Circle().stroke(.white.opacity(0.7), lineWidth: 1)
                }

            if isLive {
                Circle()
                    .fill(.green)
                    .frame(width: max(10, size * 0.23), height: max(10, size * 0.23))
                    .overlay { Circle().stroke(.background, lineWidth: 2) }
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(name)
    }

    private var resolvedInitials: String {
        if let initials, !initials.isEmpty { return initials }
        return name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}
