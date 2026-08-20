import Foundation

enum NaturalDateReference: Sendable, Hashable {
    case implicitToday
    case today
    case tomorrow
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday
    case calendarDate
    case relative
}

enum NaturalTimePrecision: Sendable, Hashable {
    case unspecified
    case exact
    case morning
    case afternoon
    case evening
}

enum NaturalRelativeUnit: Sendable, Hashable {
    case minute
    case hour
    case day
}

struct NaturalDateTimeParts: Sendable, Hashable {
    let reference: NaturalDateReference
    let year: Int
    let yearWasExplicit: Bool
    let month: Int
    let day: Int
    let timePrecision: NaturalTimePrecision
    let hour: Int
    let minute: Int
    let relativeAmount: Int
    let relativeUnit: NaturalRelativeUnit
}

struct ResolvedNaturalDateTime: Sendable, Hashable {
    let date: Date
    let dateWasExplicit: Bool
    let timeWasExplicit: Bool
}

enum NaturalDateTimeResolutionError: Error, Sendable, Hashable {
    case invalidComponents
}

enum NaturalDateTimeResolver {
    private static let parisCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    static func resolve(
        _ parts: NaturalDateTimeParts,
        now: Date
    ) throws(NaturalDateTimeResolutionError) -> ResolvedNaturalDateTime {
        if parts.reference == .relative {
            let component: Calendar.Component = switch parts.relativeUnit {
            case .minute: .minute
            case .hour: .hour
            case .day: .day
            }
            guard parts.relativeAmount > 0,
                  let date = parisCalendar.date(
                      byAdding: component,
                      value: parts.relativeAmount,
                      to: now
                  )
            else {
                throw .invalidComponents
            }
            return ResolvedNaturalDateTime(
                date: date,
                dateWasExplicit: false,
                timeWasExplicit: true
            )
        }

        let referenceDate = try referenceDate(for: parts, now: now)
        let date = try applyingTime(from: parts, to: referenceDate, now: now)
        return ResolvedNaturalDateTime(
            date: date,
            dateWasExplicit: parts.reference != .implicitToday,
            timeWasExplicit: parts.timePrecision != .unspecified
        )
    }

    private static func referenceDate(
        for parts: NaturalDateTimeParts,
        now: Date
    ) throws(NaturalDateTimeResolutionError) -> Date {
        let startOfToday = parisCalendar.startOfDay(for: now)
        switch parts.reference {
        case .implicitToday, .today:
            return startOfToday
        case .tomorrow:
            guard let tomorrow = parisCalendar.date(byAdding: .day, value: 1, to: startOfToday) else {
                throw .invalidComponents
            }
            return tomorrow
        case .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday:
            guard let date = parisCalendar.nextDate(
                after: startOfToday.addingTimeInterval(-1),
                matching: DateComponents(weekday: parts.reference.weekday),
                matchingPolicy: .nextTime,
                direction: .forward
            ) else {
                throw .invalidComponents
            }
            return parisCalendar.startOfDay(for: date)
        case .calendarDate:
            return try explicitDate(from: parts, now: now)
        case .relative:
            throw .invalidComponents
        }
    }

    private static func explicitDate(
        from parts: NaturalDateTimeParts,
        now: Date
    ) throws(NaturalDateTimeResolutionError) -> Date {
        guard (1 ... 12).contains(parts.month), (1 ... 31).contains(parts.day) else {
            throw .invalidComponents
        }
        let currentYear = parisCalendar.component(.year, from: now)
        let requestedYear = parts.yearWasExplicit ? parts.year : currentYear
        var components = DateComponents(
            calendar: parisCalendar,
            timeZone: parisCalendar.timeZone,
            year: requestedYear,
            month: parts.month,
            day: parts.day,
            hour: 0,
            minute: 0
        )
        guard var date = parisCalendar.date(from: components),
              parisCalendar.component(.year, from: date) == requestedYear,
              parisCalendar.component(.month, from: date) == parts.month,
              parisCalendar.component(.day, from: date) == parts.day
        else {
            throw .invalidComponents
        }

        if !parts.yearWasExplicit, date < parisCalendar.startOfDay(for: now) {
            components.year = currentYear + 1
            guard let nextYear = parisCalendar.date(from: components),
                  parisCalendar.component(.month, from: nextYear) == parts.month,
                  parisCalendar.component(.day, from: nextYear) == parts.day
            else {
                throw .invalidComponents
            }
            date = nextYear
        }
        return date
    }

    private static func applyingTime(
        from parts: NaturalDateTimeParts,
        to referenceDate: Date,
        now: Date
    ) throws(NaturalDateTimeResolutionError) -> Date {
        if parts.timePrecision == .unspecified, parts.reference == .implicitToday {
            return now
        }

        let time: (hour: Int, minute: Int) = switch parts.timePrecision {
        case .unspecified: (12, 0)
        case .exact: (parts.hour, parts.minute)
        case .morning: (9, 0)
        case .afternoon: (15, 0)
        case .evening: (19, 0)
        }
        guard (0 ... 23).contains(time.hour), (0 ... 59).contains(time.minute),
              let date = parisCalendar.date(
                  bySettingHour: time.hour,
                  minute: time.minute,
                  second: 0,
                  of: referenceDate
              )
        else {
            throw .invalidComponents
        }
        return date
    }
}

private extension NaturalDateReference {
    var weekday: Int {
        switch self {
        case .sunday: 1
        case .monday: 2
        case .tuesday: 3
        case .wednesday: 4
        case .thursday: 5
        case .friday: 6
        case .saturday: 7
        case .implicitToday, .today, .tomorrow, .calendarDate, .relative: 0
        }
    }
}
