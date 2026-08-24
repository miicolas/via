import SwiftUI

/// A minute-by-minute wheel that recentres its finite backing store before the
/// traveller can reach an edge. The recenter keeps the same `Date`, making the
/// native inertial scroll feel continuous in either direction without an
/// unbounded collection.
struct InfiniteJourneyTimePicker: View {
    @Binding private var selection: Date
    let tint: Color

    @State private var anchorDate: Date
    @State private var focusedIndex: Int?
    @State private var hapticTick = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let rowHeight: CGFloat = 58
    private static let minuteCount = 15 * 24 * 60
    private static let centerIndex = minuteCount / 2
    private static let recenterThreshold = 2 * 24 * 60

    init(selection: Binding<Date>, tint: Color) {
        _selection = selection
        self.tint = tint
        let rounded = Calendar.autoupdatingCurrent.dateInterval(
            of: .minute,
            for: selection.wrappedValue
        )?.start ?? selection.wrappedValue
        _anchorDate = State(initialValue: rounded)
        _focusedIndex = State(initialValue: Self.centerIndex)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .stroke(tint.opacity(0.28), lineWidth: 1)
                    .frame(height: Self.rowHeight)
                    .padding(.horizontal, 18)
                    .allowsHitTesting(false)

                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(0 ..< Self.minuteCount, id: \.self) { index in
                            timeRow(at: index)
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $focusedIndex)
                .contentMargins(
                    .vertical,
                    max(0, (proxy.size.height - Self.rowHeight) / 2),
                    for: .scrollContent
                )
                .onScrollPhaseChange { _, newPhase in
                    if newPhase == .idle { recenterIfNeeded() }
                }
            }
        }
        .frame(height: 224)
        .sensoryFeedback(.selection, trigger: hapticTick)
        .onAppear { selection = anchorDate }
        .onChange(of: focusedIndex) { _, index in
            guard let index else { return }
            selection = date(at: index)
            hapticTick += 1
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heure")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Balayez vers le haut ou le bas pour changer l’heure minute par minute")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                moveSelection(by: 1)
            case .decrement:
                moveSelection(by: -1)
            @unknown default:
                break
            }
        }
    }

    private func timeRow(at index: Int) -> some View {
        let isFocused = focusedIndex == index
        return Text(JourneyFormatting.time(date(at: index)))
            .font(
                .system(
                    size: isFocused ? 34 : 25,
                    weight: isFocused ? .bold : .semibold,
                    design: .rounded
                )
                .monospacedDigit()
            )
            .foregroundStyle(isFocused ? tint : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: Self.rowHeight)
            .scrollTransition(.interactive, axis: .vertical) { content, phase in
                content
                    .scaleEffect(phase.isIdentity ? 1 : 0.78)
                    .opacity(phase.isIdentity ? 1 : 0.34)
            }
            .animation(reduceMotion ? nil : .default, value: isFocused)
            .accessibilityHidden(true)
    }

    private func date(at index: Int) -> Date {
        anchorDate.addingTimeInterval(TimeInterval(index - Self.centerIndex) * 60)
    }

    private func moveSelection(by delta: Int) {
        guard let focusedIndex else { return }
        let destination = min(
            max(0, focusedIndex + delta),
            Self.minuteCount - 1
        )
        withAnimation(reduceMotion ? nil : .default) {
            self.focusedIndex = destination
        }
    }

    private func recenterIfNeeded() {
        guard let focusedIndex,
              focusedIndex < Self.recenterThreshold
                || focusedIndex > Self.minuteCount - Self.recenterThreshold
        else { return }

        let selectedDate = date(at: focusedIndex)
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            anchorDate = selectedDate
            self.focusedIndex = Self.centerIndex
        }
    }

    private var accessibilityValue: String {
        selection.formatted(date: .complete, time: .shortened)
    }
}
