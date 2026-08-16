//
//  SheetTabView.swift
//  via
//
//  Created by Nicolas Becharat on 16/08/2026.
//

import SwiftUI

struct SheetTabView<Selection: Hashable, Content: TabContent>: View where Content.TabValue == Selection {
    @Binding var selection: Selection
    @TabContentBuilder<Selection> var tabs: Content

    @ViewBuilder
    var body: some View {
        // .crossFade requires the iOS 27 SDK; the compiler guard keeps builds
        // on stable Xcode (Swift 6.2, e.g. Xcode Cloud) compiling.
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            baseTabView
                .navigationTransition(.crossFade)
                .presentationDetents([.height(95), .fraction(0.45), .large])
        } else {
            iOS26TabView
        }
        #else
        iOS26TabView
        #endif
    }

    private var iOS26TabView: some View {
        baseTabView
            .presentationDetents([.fraction(0.45), .large])
    }

    private var baseTabView: some View {
        TabView(selection: $selection) {
            tabs
        }
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
        .presentationContentInteraction(.resizes)
        .interactiveDismissDisabled()
    }
}

#Preview {
    let dependencies = AppDependencies.preview
    RootView(
        dependencies: dependencies.root,
        authViewModel: dependencies.authSession
    )
}
