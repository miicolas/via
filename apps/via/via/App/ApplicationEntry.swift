import SwiftUI

/// Empty shell kept while the iOS presentation layer is rebuilt.
@main
struct ApplicationEntry: App {
    var body: some Scene {
        WindowGroup {
            Color.clear
        }
    }
}
