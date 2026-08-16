import SwiftUI

struct MapSearchSheet: View {
    @Binding var text: String
    let authViewModel: AuthSessionViewModel
    let account: AccountModel
    @State private var isAccountPresented = false

    var body: some View {
        NavigationStack {
            Color.clear
                .searchable(text: $text, prompt: "Où est-ce que tu veux aller ?")
                .toolbar {
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)

                    ToolbarSpacer(placement: .bottomBar)

                    ToolbarItem(placement: .bottomBar) {
                        Button("Compte", systemImage: "person.crop.circle.fill") {
                            isAccountPresented = true
                        }
                        .labelStyle(.iconOnly)
                    }
                }
                .sheet(isPresented: $isAccountPresented) {
                    AccountView(
                        authViewModel: authViewModel,
                        account: account
                    )
                }
        }
    }
}

#Preview {
    @Previewable @State var text = ""
    let dependencies = AppDependencies.preview

    ZStack {
        Color.blue
        MapSearchSheet(
            text: $text,
            authViewModel: dependencies.authSession,
            account: dependencies.root.account
        )
    }
}
