import Foundation

/// The planned closures that start on one calendar day, in the order they
/// begin.
struct UpcomingClosureDay: Identifiable, Sendable, Equatable {
  var day: Date
  var lines: [LineStatus]

  var id: Date { day }
}
