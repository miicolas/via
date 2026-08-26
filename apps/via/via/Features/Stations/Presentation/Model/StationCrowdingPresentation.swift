import SwiftUI

/// Pure decisions behind the crowding chart. The view owns the paging state;
/// the week layout, day-type mapping, colours and wording live here where they
/// can be table-tested.
enum StationCrowdingPresentation {
    enum DayType: Hashable {
        case weekday
        case saturday
        case sunday
    }

    /// One page of the pager: a real date of the current calendar week, mapped
    /// onto the only day shape the IDFM dataset knows for it.
    struct CrowdingDay: Identifiable, Hashable {
        let index: Int
        let date: Date
        let dayType: DayType

        var id: Int { index }
    }

    /// Monday→Sunday of the week containing `today`, whatever the traveller's
    /// first-weekday setting. Public holidays are not resolved on device; a
    /// habitual profile tolerates a férié drawn as its weekday shape.
    static func days(containing today: Date, calendar: Calendar) -> [CrowdingDay] {
        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2
        let start =
            mondayFirst.dateInterval(of: .weekOfYear, for: today)?.start
            ?? mondayFirst.startOfDay(for: today)
        return (0..<7).map { index in
            CrowdingDay(
                index: index,
                date: mondayFirst.date(byAdding: .day, value: index, to: start) ?? start,
                dayType: index == 5 ? .saturday : index == 6 ? .sunday : .weekday
            )
        }
    }

    /// The pager opens on today's page.
    static func defaultIndex(for today: Date, calendar: Calendar) -> Int {
        // `weekday` is 1 = Sunday whatever `firstWeekday` says.
        (calendar.component(.weekday, from: today) + 5) % 7
    }

    /// "Mercredi 26 août" — the sentence case belongs to the title position,
    /// which the French lowercase weekday would otherwise leave dangling.
    static func title(for date: Date, calendar: Calendar) -> String {
        var style = Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide)
        style.calendar = calendar
        style.locale = Locale(identifier: "fr_FR")
        let title = date.formatted(style)
        return title.prefix(1).uppercased() + title.dropFirst()
    }

    static func hours(for dayType: DayType, in crowding: StationCrowding) -> [CrowdingHour] {
        switch dayType {
        case .weekday: crowding.weekday
        case .saturday: crowding.saturday
        case .sunday: crowding.sunday
        }
    }

    /// Only the quarters of the day are labelled; 24 ticks would be noise.
    static func axisLabel(for hour: Int) -> String? {
        switch hour {
        case 0, 6, 12, 18: "\(hour)h"
        default: nil
        }
    }

    /// Every bar wears the same muted accent so the one red bar — the current
    /// hour, and only on today's page — is the sole thing that pops.
    static func barColor(hour: Int, isTodayPage: Bool, currentHour: Int) -> Color {
        isTodayPage && hour == currentHour ? .red : Color.accentColor.opacity(0.45)
    }

    /// Spoken stand-in for the whole chart: the busy hours, or the quiet truth.
    static func accessibilitySummary(for hours: [CrowdingHour]) -> String {
        let peaks = hours.filter { $0.level == .peak }.map(\.hour)
        if !peaks.isEmpty {
            return "Affluence maximale vers \(spelled(peaks))"
        }
        let moderate = hours.filter { $0.level == .moderate }.map(\.hour)
        if !moderate.isEmpty {
            return "Fréquentation soutenue vers \(spelled(moderate))"
        }
        return "Fréquentation faible toute la journée"
    }

    private static func spelled(_ hours: [Int]) -> String {
        let words = hours.map { "\($0) h" }
        guard words.count > 1 else { return words[0] }
        return words.dropLast().joined(separator: ", ") + " et " + words[words.count - 1]
    }
}
