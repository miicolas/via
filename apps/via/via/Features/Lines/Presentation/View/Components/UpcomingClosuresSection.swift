import SwiftUI

struct UpcomingClosuresSection: View {
  var days: [UpcomingClosureDay]

  var body: some View {
    ForEach(days) { entry in
      Section(
        "À venir · \(entry.day.formatted(.dateTime.weekday(.wide).day().month(.wide)))"
      ) {
        ForEach(entry.lines) { status in
          NavigationLink(value: status) {
            UpcomingClosureCard(status: status)
          }
          .linesCardRow()
        }
      }
    }
  }
}
