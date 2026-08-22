import SwiftUI
import UIKit

struct OnboardingView: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var currentIndex = 0
    @State private var screenshotSize: CGSize = .zero
    @State private var deviceCornerRadius: CGFloat = 0

    private let pages = OnboardingPage.allCases

    var body: some View {
        OnboardingScaffold(
            onBack: backAction,
            backHint: "Revient à l’étape précédente de la présentation",
            showsPanelBackground: currentPage.zoomScale > 1
        ) {
            screenshotCarousel
                .compositingGroup()
                .scaleEffect(
                    currentPage.zoomScale,
                    anchor: currentPage.zoomAnchor
                )
                .accessibilityHidden(true)
        } panel: {
            VStack(spacing: 10) {
                textCarousel
                    .frame(height: textCarouselHeight)
                OnboardingStepIndicator(count: pages.count, currentIndex: currentIndex)
                continueButton
            }
        }
    }

    private var screenshotCarousel: some View {
        let shape = ConcentricRectangle(corners: .concentric, isUniform: true)

        return GeometryReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        screenshot(for: page, at: index, shape: shape)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollDisabled(true)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollPosition(id: pagePosition)
        }
        .clipShape(shape)
        .overlay {
            if screenshotSize != .zero {
                ZStack {
                    shape.stroke(.white, lineWidth: 6)
                    shape.stroke(.black, lineWidth: 4)
                    shape
                        .stroke(.black, lineWidth: 6)
                        .padding(4)
                }
                .padding(-7)
            }
        }
        .frame(
            maxWidth: screenshotSize.width == 0 ? nil : screenshotSize.width,
            maxHeight: screenshotSize.height == 0 ? nil : screenshotSize.height
        )
        .containerShape(RoundedRectangle(cornerRadius: deviceCornerRadius))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func screenshot(
        for page: OnboardingPage,
        at index: Int,
        shape: ConcentricRectangle
    ) -> some View {
        Group {
            if let screenshot = page.screenshot {
                Image(uiImage: screenshot)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onGeometryChange(for: CGSize.self) {
                        $0.size
                    } action: { newValue in
                        guard index == 0, screenshotSize == .zero else { return }
                        screenshotSize = newValue
                        // 180 pt of device corner in the screenshot's own
                        // pixel space, scaled to how it is actually drawn.
                        let height = screenshot.size.height
                        deviceCornerRadius = height == 0 ? 0 : 180 * (newValue.height / height)
                    }
                    .clipShape(shape)
            } else {
                Rectangle()
                    .fill(.black)
            }
        }
    }

    private var textCarousel: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        let isActive = currentIndex == index

                        OnboardingHeadline(title: page.title, subtitle: page.subtitle)
                            .frame(width: proxy.size.width)
                            .compositingGroup()
                            .blur(radius: reduceMotion || isActive ? 0 : 30)
                            .opacity(isActive ? 1 : 0)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(true)
            .scrollTargetBehavior(.paging)
            .scrollClipDisabled()
            .scrollPosition(id: pagePosition)
        }
    }

    private var continueButton: some View {
        Button(action: advance) {
            Text(currentPage.isFinal ? "Commencer" : "Continuer")
                .fontWeight(.medium)
                .contentTransition(reduceMotion ? .identity : .numericText())
        }
        .primaryAction(tint: .blue)
        .padding(.horizontal, 30)
        .accessibilityHint(
            currentPage.isFinal
                ? "Termine la présentation et ouvre la connexion"
                : "Affiche l’étape suivante"
        )
    }

    private func advance() {
        guard !currentPage.isFinal else {
            onComplete()
            return
        }

        withAnimation(pageAnimation) {
            currentIndex += 1
        }
    }

    private func goBack() {
        guard currentIndex > 0 else { return }
        withAnimation(pageAnimation) {
            currentIndex -= 1
        }
    }

    private var pagePosition: Binding<Int?> {
        Binding(
            get: { currentIndex },
            set: { newValue in
                guard let newValue, pages.indices.contains(newValue) else { return }
                currentIndex = newValue
            }
        )
    }

    /// Spelled out rather than inlined in the ternary: the carousel's first
    /// page has nowhere to go back to, and the scaffold reads that as `nil`.
    private var backAction: (() -> Void)? {
        guard currentIndex > 0 else { return nil }
        return goBack
    }

    private var currentPage: OnboardingPage {
        pages[currentIndex]
    }

    /// The text is the only part of the panel that has to be pinned: it rides a
    /// `GeometryReader`, and a panel that resized page by page would shove the
    /// screenshot up and down as the traveller advances.
    private var textCarouselHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 200 : 110
    }

    private var pageAnimation: Animation? {
        reduceMotion
            ? nil
            : .interpolatingSpring(duration: 0.65, bounce: 0, initialVelocity: 0)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
