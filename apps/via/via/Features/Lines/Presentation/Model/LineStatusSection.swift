import Foundation

struct LineStatusSection: Identifiable, Sendable, Equatable {
  var mode: TransitMode
  var lines: [LineStatus]

  var id: TransitMode { mode }
}
