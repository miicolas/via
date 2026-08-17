import SwiftUI

struct AccountAvatarView: View {
    let user: AuthUser

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.16))

            if let initials = user.initials {
                Text(initials)
                    .font(.title2.bold())
                    .foregroundStyle(.tint)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: 72, height: 72)
        .accessibilityLabel("Avatar de \(user.displayName)")
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    AccountAvatarView(user: AuthUser(
        id: "preview",
        appleUserIdentifier: "apple",
        name: "Camille Martin",
        email: "camille@example.com"
    ))
}
