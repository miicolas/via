import SwiftUI

struct ViaButton<Content: View>: View {
    private let action: () -> Void
    private let content: () -> Content

    init(
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.action = action
        self.content = content
    }

    var body: some View {
        Button(action: action, label: content)
            .buttonStyle(.glass)
    }
}

extension ViaButton where Content == Label<Text, Image> {
    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        action: @escaping () -> Void
    ) {
        self.init(action: action) {
            Label(title, systemImage: systemImage)
        }
    }
}
