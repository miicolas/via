import Foundation

/// What the traveller narrowed the Lines tab to. One value so the menu that
/// sets it, the screen that reports it, and the view model that applies it
/// cannot each hold their own idea of what is filtered.
struct LineStatusFilter: Sendable, Equatable {
  var mode: TransitMode?
  var disruptionsOnly = false

  var isActive: Bool {
    mode != nil || disruptionsOnly
  }

  func matches(_ status: LineStatus) -> Bool {
    (mode == nil || status.route.mode == mode)
      && (!disruptionsOnly || status.condition != .normal)
  }

  mutating func reset() {
    self = LineStatusFilter()
  }
}
