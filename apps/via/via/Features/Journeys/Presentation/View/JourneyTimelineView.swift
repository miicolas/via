import SwiftUI

struct JourneyTimelineView: View {
    let journey: Journey
    @Binding var expandedSectionIDs: Set<String>
    let highlightedSectionID: String?
    let onSelectSection: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Votre trajet")
                .font(.title2.weight(.bold))

            ForEach(ActiveJourneyRules.schedule(for: journey)) { schedule in
                JourneyTimelineRow(
                    schedule: schedule,
                    isExpanded: Binding(
                        get: { expandedSectionIDs.contains(schedule.id) },
                        set: { expanded in
                            if expanded {
                                expandedSectionIDs.insert(schedule.id)
                            } else {
                                expandedSectionIDs.remove(schedule.id)
                            }
                        }
                    ),
                    isHighlighted: highlightedSectionID == schedule.id,
                    onSelect: { onSelectSection(schedule.id) }
                )
            }
        }
    }
}
