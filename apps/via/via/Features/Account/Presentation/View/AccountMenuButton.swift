import SwiftUI

struct AccountMenuButton: View {
    let profile: ProfileModel
    let onOpenProfile: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        Menu {
            Button(action: onOpenProfile) {
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(profile.displayName.isEmpty ? "Ajouter ton nom" : profile.displayName)
                        Text("Modifier le profil")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "person.crop.circle")
                }
            }

            Button(action: onOpenSettings) {
                Label("Réglages", systemImage: "gearshape")
            }
        } label: {
            ProfileAvatarView(
                imageData: profile.avatarData,
                displayName: profile.displayName,
                size: ToolbarGlyphMetrics.avatar,
                isBordered: false
            )
            .frame(
                width: ToolbarGlyphMetrics.slot,
                height: ToolbarGlyphMetrics.slot,
            )
        }
        .accessibilityLabel("Compte et réglages")
        .accessibilityHint("Ouvre le menu du profil et des réglages.")
    }
}

#Preview("Menu du compte") {
    let model: ProfileModel = {
        let model = ProfileModel(store: InMemoryProfileStore())
        model.activate(scope: .anonymous, seedName: "Alex Martin")
        return model
    }()
    AccountMenuButton(profile: model, onOpenProfile: {}, onOpenSettings: {})
        .padding()
}
