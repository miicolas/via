import SwiftUI

struct AccountExportLink: View {
    let export: AccountExport

    var body: some View {
        ShareLink(
            item: export,
            preview: SharePreview(Text("Données Via"))
        ) {
            Label("Exporter mes données", systemImage: "square.and.arrow.up")
        }
    }
}
