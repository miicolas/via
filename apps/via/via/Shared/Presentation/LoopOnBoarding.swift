import SwiftUI

struct LoopOnBoarding: View {
    let config: Config
    let phases: [Phase]
    private let bottomContent: AnyView

    @State private var startDate: Date = .now

    init<BottomContent: View>(
        config: Config = .init(),
        phases: [Phase],
        @ViewBuilder bottomContent: () -> BottomContent
    ) {
        self.config = config
        self.phases = phases
        self.bottomContent = AnyView(bottomContent())
    }

    var body: some View {
        Group {
            if phases.isEmpty {
                Color.clear
            } else {
                animatedContent
            }
        }
        .background {
            Circle()
                .fill(config.tint.gradient)
                .visualEffect { content, proxy in
                    content
                        .offset(y: proxy.size.height * 1.07)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .blur(radius: 90)
        }
    }

    private var animatedContent: some View {
        let phaseUpdateAfter = max(config.phaseUpdateAfter, 1)
        let timelineDuration = TimeInterval(phaseUpdateAfter) * 3

        return ZStack {
            TimelineView(.periodic(from: startDate, by: timelineDuration)) { context in
                let diff = Int(startDate.distance(to: context.date)) / (phaseUpdateAfter * 3)
                let index = diff % phases.count

                ZStack {
                    Image(systemName: phases[index].symbol)
                        .font(.system(size: config.iconSize - 20))
                        .foregroundStyle(config.tint.gradient)
                        .contentTransition(.symbolEffect(.replace.downUp))
                        .frame(width: config.iconSize, height: config.iconSize)
                        .keyframeAnimator(initialValue: 1.0, repeating: true) { content, scale in
                            content
                                .scaleEffect(scale)
                        } keyframes: { _ in
                            let scale = config.iconScale
                            MoveKeyframe(1)
                            SpringKeyframe(1, duration: 0.25)
                            SpringKeyframe(scale, duration: 0.25)
                            SpringKeyframe(1, duration: 0.25)
                            SpringKeyframe(scale, duration: 0.25)
                            SpringKeyframe(1, duration: 0.25)
                            SpringKeyframe(scale, duration: 0.25)
                            SpringKeyframe(1, duration: 0.25)
                            CubicKeyframe(1, duration: 1.25)
                        }
                        .padding(.bottom, 130)

                    ZStack {
                        ForEach(phases.indices, id: \.self) { phaseIndex in
                            if phaseIndex == index {
                                TextContent(phase: phases[phaseIndex])
                                    .transition(
                                        .asymmetric(
                                            insertion: .push(from: .bottom),
                                            removal: .push(from: .bottom)
                                        )
                                        .combined(with: AnyTransition(.blurReplace))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, config.bottomContentPadding)
                    .animation(.bouncy(duration: 0.8), value: index)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }

            Rectangle()
                .foregroundStyle(.clear)
                .overlay {
                    ZStack {
                        pulseRing(delay: 0, wait: 1)
                        pulseRing(delay: 0.5, wait: 0.5)
                        pulseRing(delay: 1, wait: 0)
                    }
                }
                .padding(.bottom, 130)
        }
        .overlay(alignment: .bottom) {
            bottomContent
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 30)
                .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private func pulseRing(delay: CGFloat, wait: CGFloat) -> some View {
        let size = config.iconSize / 2

        KeyframeAnimator(initialValue: Pulse(), repeating: true) { pulse in
            Circle()
                .stroke(config.pulseTint, lineWidth: config.pulseWidth)
                .frame(width: size * pulse.scale, height: size * pulse.scale)
                .opacity(pulse.opacity)
        } keyframes: { _ in
            let scale = config.pulseScale
            MoveKeyframe(Pulse())
            LinearKeyframe(Pulse(), duration: delay)
            LinearKeyframe(Pulse(scale: scale, opacity: 0), duration: 2)
            LinearKeyframe(Pulse(scale: scale, opacity: 0), duration: wait)
        }
    }

    @ViewBuilder
    private func TextContent(phase: Phase) -> some View {
        VStack(alignment: .center, spacing: 12) {
            Text(phase.title)
                .font(.title2.bold())
                .lineLimit(1)

            Text(phase.description)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(.gray)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(height: 130)
    }

    @Animatable
    struct Pulse {
        var scale: CGFloat = 1
        var opacity: CGFloat = 1
    }

    struct Config {
        var tint: Color = .accentColor
        var pulseTint: Color = Color.accentColor.opacity(0.65)
        var pulseWidth: CGFloat = 1.3
        var pulseScale: CGFloat = 12
        var iconSize: CGFloat = 100
        var iconScale: CGFloat = 1.25
        var phaseUpdateAfter: Int = 1
        var bottomContentPadding: CGFloat = 75
    }

    struct Phase: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let description: String

        init(
            id: String? = nil,
            symbol: String,
            title: String,
            description: String
        ) {
            self.id = id ?? symbol
            self.symbol = symbol
            self.title = title
            self.description = description
        }
    }
}
