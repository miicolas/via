import SwiftUI

struct UpcomingClosureLabel: View {
  var closure: UpcomingClosure

  var body: some View {
    Label(text, systemImage: "clock.badge.exclamationmark")
      .font(.caption.weight(.semibold))
      .foregroundStyle(.orange)
      .fixedSize(horizontal: false, vertical: true)
  }

  private var text: String {
    let time = closure.beginsAt.formatted(date: .omitted, time: .shortened)
    if Calendar.current.isDateInToday(closure.beginsAt) {
      return "Fermeture prévue à \(time)"
    }
    let day = closure.beginsAt.formatted(.dateTime.weekday(.wide).day())
    return "Fermeture prévue \(day) à \(time)"
  }
}
