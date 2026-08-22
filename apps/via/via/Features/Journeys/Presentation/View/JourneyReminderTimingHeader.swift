import SwiftUI

struct JourneyReminderTimingHeader: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Combien de temps avant le départ ?")
        .font(.system(.largeTitle, design: .rounded, weight: .bold))

      Text("Faites glisser la règle pour choisir quand Metyro doit vous prévenir.")
        .font(.body)
        .foregroundStyle(.secondary)
    }
  }
}
