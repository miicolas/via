import SwiftUI

/// A Flighty-inspired, vertically scrolling calendar for choosing a departure
/// date. The sheet owns the confirmation action; this view only updates the
/// bound day when a valid calendar cell is selected.
struct SearchCalendarView: View {
    @Binding var date: Date

    let selectionIsConfirmed: Bool
    let minimumDate: Date

    private let calendar: Calendar
    private let monthsToDisplay: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        date: Binding<Date>,
        selectionIsConfirmed: Bool,
        minimumDate: Date,
        monthsToDisplay: Int = 18
    ) {
        _date = date

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        calendar.timeZone = .current
        calendar.firstWeekday = 1
        calendar.minimumDaysInFirstWeek = 1

        self.calendar = calendar
        self.selectionIsConfirmed = selectionIsConfirmed
        self.minimumDate = calendar.startOfDay(for: minimumDate)
        self.monthsToDisplay = max(monthsToDisplay, 1)
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 38) {
            ForEach(months, id: \.self) { month in
                monthView(month)
            }
        }
        .padding(.horizontal, 20)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: date)
    }

    private var months: [Date] {
        let components = calendar.dateComponents([.year, .month], from: minimumDate)
        guard let firstMonth = calendar.date(from: components) else { return [] }

        return (0..<monthsToDisplay).compactMap {
            calendar.date(byAdding: .month, value: $0, to: firstMonth)
        }
    }

    @ViewBuilder
    private func monthView(_ month: Date) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            monthHeader(month)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.55))
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .accessibilityHidden(true)
                }

                ForEach(Array(days(in: month).enumerated()), id: \.offset) { _, day in
                    dayCell(day)
                }
            }
        }
    }

    private func monthHeader(_ month: Date) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(month.formatted(.dateTime.month(.wide)))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(month.formatted(.dateTime.year()))
                .font(.system(size: 32, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(month.formatted(.dateTime.month(.wide).year()))
    }

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day {
            let isSelected = selectionIsConfirmed && calendar.isDate(day, inSameDayAs: date)
            let isToday = calendar.isDateInToday(day)
            let isSelectable = day >= minimumDate

            Button {
                date = calendar.startOfDay(for: day)
            } label: {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(selectionBlue)
                    } else if isToday {
                        Circle()
                            .stroke(selectionBlue, lineWidth: 4)
                    }

                    Text(day.formatted(.dateTime.day()))
                        .font(.system(size: 22, weight: .regular, design: .rounded))
                        .foregroundStyle(
                            isSelected
                                ? Color.white
                                : isSelectable
                                    ? Color.primary
                                    : Color.secondary.opacity(0.28)
                        )
                }
                .frame(width: 52, height: 52)
                .frame(maxWidth: .infinity, minHeight: 60)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isSelectable)
            .accessibilityLabel(accessibilityLabel(for: day, isSelected: isSelected, isToday: isToday))
            .accessibilityValue(isSelected ? "Sélectionnée" : "")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 60)
                .accessibilityHidden(true)
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let firstWeekdayIndex = calendar.firstWeekday - 1
        let locale = calendar.locale ?? .current

        return (0..<symbols.count).map { offset in
            symbols[(firstWeekdayIndex + offset) % symbols.count]
                .uppercased(with: locale)
        }
    }

    private func days(in month: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let dayRange = calendar.range(of: .day, in: .month, for: month)
        else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingDays = (firstWeekday - calendar.firstWeekday + 7) % 7

        let blankDays = Array(repeating: Optional<Date>.none, count: leadingDays)
        let monthDays = dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }

        return blankDays + monthDays.map(Optional.some)
    }

    private func accessibilityLabel(for day: Date, isSelected: Bool, isToday: Bool) -> String {
        var label = day.formatted(date: .complete, time: .omitted)

        if isToday {
            label += ", aujourd’hui"
        }

        if isSelected {
            label += ", sélectionnée"
        }

        return label
    }

    private var selectionBlue: Color {
        Color(red: 0.23, green: 0.52, blue: 0.95)
    }
}

#Preview {
    @Previewable @State var date = Calendar.current.date(byAdding: .day, value: 10, to: .now)!

    ScrollView {
        SearchCalendarView(
            date: $date,
            selectionIsConfirmed: true,
            minimumDate: .now,
            monthsToDisplay: 2
        )
    }
}
