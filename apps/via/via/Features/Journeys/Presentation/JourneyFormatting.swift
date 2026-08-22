import Foundation

enum JourneyFormatting {
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func dateTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    static func duration(_ seconds: Int) -> String {
        let minutes = max(0, Int(ceil(Double(seconds) / 60)))
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let remaining = minutes % 60
        guard remaining > 0 else { return "\(hours) h" }
        return String(format: "%d h %02d", hours, remaining)
    }

    static func countdown(_ interval: TimeInterval) -> String {
        let minutes = max(1, Int(ceil(interval / 60)))
        return minutes >= 60 ? duration(minutes * 60) : "\(minutes) min"
    }
}
