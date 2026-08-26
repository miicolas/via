import SwiftUI

/// What Via gives back to the finger, named once so two screens cannot answer
/// the same gesture with two different intensities.
///
/// Via bans the UIKit generators: `.sensoryFeedback` is the only path that
/// honours Réglages › Sons et haptique › Retour haptique système, so a
/// traveller who turned vibration off has nothing to turn off a second time.
enum Haptic {
  /// A value moved one notch under the finger — a picker row, a day of the
  /// crowding chart, a card taking the centre, a filter.
  static let selection: SensoryFeedback = .selection

  /// A tap the screen barely acknowledges: retry, recentre, open an
  /// explanation. Without the notch the traveller reads the tap as missed.
  static let tap: SensoryFeedback = .impact(weight: .light)

  /// A decision that opens or replaces a screen: a result chosen, an
  /// itinerary kept, a search sent, a journey asked for.
  static let commit: SensoryFeedback = .impact(weight: .medium)

  /// It moved on its own under the traveller — a leg passed, a page turning, a
  /// sheet jumping one detent. Nobody asked for it, so it is the softest impact
  /// Via has.
  static let advanced: SensoryFeedback = .impact(flexibility: .soft)

  /// Turned on, kept, sent, arrived.
  static let saved: SensoryFeedback = .success

  /// Turned off, removed, reset. Deliberately unlike `saved`: switching the
  /// same thing on and off has to be told apart without looking.
  static let cleared: SensoryFeedback = .impact(flexibility: .rigid)

  /// Guidance starts.
  static let started: SensoryFeedback = .start

  /// Guidance stops.
  static let ended: SensoryFeedback = .stop

  /// To be read before carrying on: a disruption, another route offered
  /// mid-journey, a destructive confirmation.
  static let warned: SensoryFeedback = .warning

  /// What was asked for could not be done.
  static let failed: SensoryFeedback = .error
}

extension View {
  /// Plays `feedback` when `value` changes — but only once the screen has
  /// settled.
  ///
  /// `.sensoryFeedback(_:trigger:)` cannot tell a value the traveller moved
  /// from one that arrives out of storage or out of a `task`: without this
  /// guard, filters restored at launch buzz a screen nobody touched. Where the
  /// state can also land from the network long after the first frame, do not
  /// rely on it — increment a counter inside the action closure and pass that
  /// instead, since only a gesture can move it.
  ///
  /// `when` narrows it further: the transition worth feeling is not always any
  /// change at all.
  func haptic<Value: Equatable>(
    _ feedback: SensoryFeedback,
    on value: Value,
    when condition: @escaping (Value, Value) -> Bool = { _, _ in true }
  ) -> some View {
    modifier(SettledHaptic(feedback: feedback, value: value, condition: condition))
  }

  /// A switch that does not feel the same in both directions.
  ///
  /// The favourite star, a follow bell, a filter chip: turning on confirms,
  /// turning off detaches. The same notch on both sides would force a look at
  /// the screen to know what just happened.
  func toggleHaptic(on value: Bool) -> some View {
    modifier(ToggleHaptic(value: value))
  }

  /// `refreshable`, with the pull acknowledged.
  ///
  /// iOS plays nothing when the spring engages, and a list that reloads exactly
  /// the same rows — departures at the same minute, an unchanged line plan —
  /// reads as a pull that did not take.
  func hapticRefreshable(action: @escaping @MainActor () async -> Void) -> some View {
    modifier(HapticRefreshable(action: action))
  }

  /// The screen itself is the event: arriving at the end of a journey, the
  /// confirmation that a report went out.
  ///
  /// Plays once, on appearance — so without the settle guard, which exists
  /// precisely to silence that moment everywhere else.
  func hapticOnAppear(_ feedback: SensoryFeedback) -> some View {
    modifier(AppearHaptic(feedback: feedback))
  }
}

private struct SettledHaptic<Value: Equatable>: ViewModifier {
  let feedback: SensoryFeedback
  let value: Value
  let condition: (Value, Value) -> Bool

  @State private var hasSettled = false

  func body(content: Content) -> some View {
    content
      .sensoryFeedback(feedback, trigger: value) { previous, current in
        hasSettled && condition(previous, current)
      }
      .task {
        // One render pass: what a sibling `task` or a store restores lands in
        // the same turn as the first body, and must not be felt.
        await Task.yield()
        hasSettled = true
      }
  }
}

private struct ToggleHaptic: ViewModifier {
  let value: Bool

  @State private var hasSettled = false

  func body(content: Content) -> some View {
    content
      .sensoryFeedback(trigger: value) { _, isOn in
        guard hasSettled else { return nil }
        return isOn ? Haptic.saved : Haptic.cleared
      }
      .task {
        await Task.yield()
        hasSettled = true
      }
  }
}

private struct HapticRefreshable: ViewModifier {
  /// `@MainActor` rather than `@Sendable`: the refresh a caller hands over
  /// reads its own view model, so it cannot be asked to leave the main actor —
  /// and a main-actor closure is Sendable anyway, which is what `refreshable`
  /// needs from us.
  let action: @MainActor () async -> Void

  @State private var tick = 0

  func body(content: Content) -> some View {
    content
      .refreshable {
        await MainActor.run { tick += 1 }
        await action()
      }
      .haptic(Haptic.advanced, on: tick)
  }
}

private struct AppearHaptic: ViewModifier {
  let feedback: SensoryFeedback

  @State private var hasAppeared = false

  func body(content: Content) -> some View {
    content
      .sensoryFeedback(feedback, trigger: hasAppeared)
      .onAppear { hasAppeared = true }
  }
}