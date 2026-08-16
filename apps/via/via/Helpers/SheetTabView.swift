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
        if #available(iOS 27.0, *) {
            tabView
        } else {
            iOS26TabView
        }
    }

    @available(iOS 27.0, *)
    private var tabView: some View {
        TabView(selection: $selection) {
            tabs
        }
        .navigationTransition(.crossFade)
        .presentationDetents(Detents)
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
        .presentationContentInteraction(.resizes)
        .interactiveDismissDisabled()
    }

    private var iOS26TabView: some View {
        TabView(selection: $selection) {
            tabs
        }
        .presentationDetents(iOS26Detents)
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
        .presentationContentInteraction(.resizes)
        .interactiveDismissDisabled()
    }

    private var Detents: Set<PresentationDetent> {
        [.height(95), .fraction(0.45), .large]
    }

    private var iOS26Detents: Set<PresentationDetent> {
        [.fraction(0.45), .large]
    }
}

#Preview {
 RootView()
}
