import SwiftUI

// Each adopted iOS 27 SDK API lives behind one modifier holding both guards:
// `#if compiler(>=6.4)` keeps builds on stable Xcode (Swift 6.2, e.g. Xcode
// Cloud) compiling, and `if #available` keeps older runtimes on the fallback.
// Call sites apply these unconditionally.

extension View {
    /// `.navigationTransition(.crossFade)` on the iOS 27 SDK; unchanged otherwise.
    @ViewBuilder
    func crossFadeNavigationTransition() -> some View {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            navigationTransition(.crossFade)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// `.swipeActionsContainer()` on the iOS 27 SDK; unchanged otherwise.
    @ViewBuilder
    func swipeActionsContainerIfAvailable() -> some View {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            swipeActionsContainer()
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// A trailing destructive full-swipe action on the iOS 27 SDK; a plain
    /// row without swipe actions otherwise.
    @ViewBuilder
    func trailingSwipeToDelete(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            swipeActions(
                edge: .trailing,
                allowsFullSwipe: true,
                content: {
                    Button(title, systemImage: systemImage, role: .destructive, action: action)
                },
                onPresentationChanged: { _ in }
            )
        } else {
            self
        }
        #else
        self
        #endif
    }
}
