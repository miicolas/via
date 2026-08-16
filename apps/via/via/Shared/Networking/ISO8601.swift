import Foundation

enum ISO8601 {
    static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    static let plain = Date.ISO8601FormatStyle()

    static func parse(_ value: String) -> Date? {
        (try? fractional.parse(value)) ?? (try? plain.parse(value))
    }

    static func string(_ date: Date) -> String {
        fractional.format(date)
    }
}
