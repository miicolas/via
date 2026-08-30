import SwiftUI

struct MeetupZonePickerView: View {
    let selection: MeetupZone
    let action: (MeetupZone) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectionTick = 0

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                zoneButton(.front, systemImage: "arrow.up.to.line")
                zoneButton(.middle, systemImage: "line.3.horizontal")
                zoneButton(.rear, systemImage: "arrow.down.to.line")
            }
        }
        .animation(reduceMotion ? nil : .default, value: selection)
        .haptic(Haptic.selection, on: selectionTick)
    }

    private func zoneButton(_ zone: MeetupZone, systemImage: String) -> some View {
        VStack(spacing: 7) {
            Button {
                guard selection != zone else { return }
                selectionTick += 1
                action(zone)
            } label: {
                Label {
                    Text(zone.title)
                } icon: {
                    Image(systemName: selection == zone ? "\(systemImage).circle.fill" : systemImage)
                        .stateSymbolTransition(value: selection == zone)
                }
            }
            .iconAction(isProminent: selection == zone)
            .tint(selection == zone ? .blue : nil)
            .accessibilityValue(selection == zone ? "Sélectionné" : "Non sélectionné")

            Text(zone.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(selection == zone ? Color.primary : Color.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
