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
        ZStack(alignment: .bottom) {
            Color.black
                .ignoresSafeArea()

            screenshotCarousel
                .compositingGroup()
                .scaleEffect(
                    currentPage.zoomScale,
                    anchor: currentPage.zoomAnchor
                )
                .padding(.top, 35)
                .padding(.horizontal, 30)
                .padding(.bottom, panelHeight + 10)
                .accessibilityHidden(true)

            bottomPanel

            backButton
        }
        .preferredColorScheme(.dark)
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

    private var bottomPanel: some View {
        VStack(spacing: 10) {
            textCarousel
            pageIndicator
            continueButton
        }
        .padding(.top, 20)
        .padding(.horizontal, 15)
        .frame(height: panelHeight)
        .background {
            variableGlassBlur(15)
        }
    }

    private var textCarousel: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        let isActive = currentIndex == index

                        VStack(spacing: 6) {
                            Text(page.title)
                                .font(.title2.weight(.semibold))
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(.white)

                            Text(page.subtitle)
                                .font(.callout)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .frame(width: proxy.size.width)
                        .compositingGroup()
                        .blur(radius: reduceMotion || isActive ? 0 : 30)
                        .opacity(isActive ? 1 : 0)
                        .accessibilityElement(children: .combine)
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

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { index in
                let isActive = currentIndex == index

                Capsule()
                    .fill(.white.opacity(isActive ? 1 : 0.4))
                    .frame(width: isActive ? 25 : 6, height: 6)
            }
        }
        .padding(.bottom, 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Étape \(currentIndex + 1) sur \(pages.count)")
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
                ? "Termine la présentation et ouvre Via"
                : "Affiche l’étape suivante"
        )
    }

    private var backButton: some View {
        Button("Étape précédente", systemImage: "chevron.left", action: goBack)
            .iconAction()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 15)
            .padding(.top, 5)
            .opacity(currentIndex == 0 ? 0 : 1)
            .disabled(currentIndex == 0)
            .accessibilityHidden(currentIndex == 0)
            .accessibilityHint("Revient à l’étape précédente de la présentation")
    }

    private func variableGlassBlur(_ radius: CGFloat) -> some View {
        Rectangle()
            .fill(.black.opacity(0.5))
            .glassEffect(.clear, in: .rect)
            .blur(radius: radius)
            .padding([.horizontal, .bottom], -radius * 2)
            .padding(.top, -radius / 2)
            .opacity(currentPage.zoomScale > 1 ? 1 : 0)
            .ignoresSafeArea()
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

    private var currentPage: OnboardingPage {
        pages[currentIndex]
    }

    private var panelHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 300 : 210
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
