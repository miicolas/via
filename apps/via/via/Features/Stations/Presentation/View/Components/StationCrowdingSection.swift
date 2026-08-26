import SwiftUI

/// Habitual crowding under the departures board: one 24-hour chart per day of
/// the current week, swiped or stepped a day at a time, opening on today.
struct StationCrowdingSection: View {
    let crowding: StationCrowding?
    let isLoaded: Bool

    private let calendar: Calendar
    private let days: [StationCrowdingPresentation.CrowdingDay]
    private let todayIndex: Int
    private let currentHour: Int

    @State private var focusedDayIndex: Int?
    /// Where the focus sat when a horizontal drag latched on, so stepping is
    /// measured from a fixed origin. Resets itself if the drag is cancelled.
    @GestureState private var dragBaseIndex: Int?
    @State private var hapticTick = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        crowding: StationCrowding?,
        isLoaded: Bool,
        calendar: Calendar = .current,
        now: Date = .now
    ) {
        self.crowding = crowding
        self.isLoaded = isLoaded
        self.calendar = calendar
        days = StationCrowdingPresentation.days(containing: now, calendar: calendar)
        todayIndex = StationCrowdingPresentation.defaultIndex(for: now, calendar: calendar)
        currentHour = calendar.component(.hour, from: now)
        _focusedDayIndex = State(initialValue: todayIndex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Affluence habituelle")
                .font(.headline)

            if let crowding {
                dayHeader
                pager(for: crowding)
                Text("Profil habituel IDFM, pas du temps réel.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                SkeletonGate(isLoading: true) {
                    skeleton
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
        .sensoryFeedback(.selection, trigger: hapticTick)
    }

    private var focusedIndex: Int {
        focusedDayIndex ?? todayIndex
    }

    private var focusedDay: StationCrowdingPresentation.CrowdingDay {
        days[min(max(focusedIndex, 0), days.count - 1)]
    }

    // MARK: - Day header

    private var dayHeader: some View {
        HStack(spacing: 0) {
            Button {
                step(to: focusedIndex - 1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(focusedIndex == 0)
            .accessibilityLabel("Jour précédent")

            Text(StationCrowdingPresentation.title(for: focusedDay.date, calendar: calendar))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .contentTransition(reduceMotion ? .identity : .opacity)
                .animation(reduceMotion ? nil : .default, value: focusedIndex)

            Button {
                step(to: focusedIndex + 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(focusedIndex == days.count - 1)
            .accessibilityLabel("Jour suivant")
        }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Jour affiché")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Balayez vers la gauche ou la droite pour changer de jour")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(to: focusedIndex + 1)
            case .decrement: step(to: focusedIndex - 1)
            @unknown default: break
            }
        }
    }

    private var accessibilityValue: String {
        var parts = [StationCrowdingPresentation.title(for: focusedDay.date, calendar: calendar)]
        if let crowding {
            parts.append(
                StationCrowdingPresentation.accessibilitySummary(
                    for: StationCrowdingPresentation.hours(for: focusedDay.dayType, in: crowding)
                )
            )
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Week pager

    private func pager(for crowding: StationCrowding) -> some View {
        GeometryReader { proxy in
            let pageWidth = proxy.size.width

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(days) { day in
                        StationCrowdingChart(
                            hours: StationCrowdingPresentation.hours(
                                for: day.dayType,
                                in: crowding
                            ),
                            isTodayPage: day.index == todayIndex,
                            currentHour: currentHour
                        )
                        .frame(width: pageWidth)
                        .id(day.index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focusedDayIndex)
            .scrollDisabled(true)
            .contentShape(.rect)
            .gesture(stepGesture(pageWidth: pageWidth))
        }
        .frame(height: 132)
        .accessibilityHidden(true)
    }

    /// The pager never scrolls on its own: an interactive horizontal scroll
    /// inside the detail sheet claims vertical drags that begin on it and pins
    /// the sheet. A clearly horizontal drag steps the day instead, and the
    /// scroll position only ever moves programmatically.
    private func stepGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragBaseIndex) { value, state, _ in
                guard state == nil,
                    abs(value.translation.width) > abs(value.translation.height)
                else { return }
                state = focusedIndex
            }
            .onChanged { value in
                guard let dragBaseIndex else { return }
                let steps = Int((-value.translation.width / (pageWidth / 2)).rounded())
                step(to: dragBaseIndex + steps)
            }
    }

    private func step(to target: Int) {
        let clamped = min(max(target, 0), days.count - 1)
        guard clamped != focusedDayIndex else { return }
        hapticTick += 1
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
            focusedDayIndex = clamped
        }
    }

    // MARK: - Skeleton

    /// The bars shimmer as one group — geometry is theirs, the animation is not.
    private var skeleton: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(0..<24) { hour in
                Skeleton(.roundedRectangle(cornerRadius: 2.5))
                    .frame(height: 24 + CGFloat((hour * 37) % 60))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .bottom)
        .skeletonGroup(label: "Chargement de l’affluence habituelle…")
    }
}

#Preview("Profil chargé") {
    ScrollView {
        VStack(spacing: 24) {
            StationCrowdingSection(crowding: .preview, isLoaded: true)
            StationCrowdingSection(crowding: nil, isLoaded: false)
        }
        .padding(20)
    }
}
