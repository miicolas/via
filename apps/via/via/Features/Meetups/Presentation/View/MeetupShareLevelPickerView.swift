import SwiftUI

struct MeetupShareLevelPickerView: View {
    @Binding var selection: MeetupShareLevel
    let onSelection: ((MeetupShareLevel) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectionTick = 0
    @State private var focusedLevel: MeetupShareLevel?

    init(
        selection: Binding<MeetupShareLevel>,
        onSelection: ((MeetupShareLevel) -> Void)? = nil
    ) {
        _selection = selection
        self.onSelection = onSelection
    }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    ForEach(MeetupShareLevel.allCases) { level in
                        option(level)
                    }
                }
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(MeetupShareLevel.allCases) { level in
                            option(level)
                                .containerRelativeFrame(
                                    .horizontal,
                                    count: 1,
                                    span: 1,
                                    spacing: 12
                                )
                                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                    content
                                        .scaleEffect(phase.isIdentity ? 1 : 0.95)
                                        .opacity(phase.isIdentity ? 1 : 0.68)
                                }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $focusedLevel, anchor: .center)
                .scrollClipDisabled()
                .accessibilityHint("Balayez horizontalement pour changer le niveau de partage")
            }
        }
        .animation(reduceMotion ? nil : .default, value: selection)
        .haptic(Haptic.selection, on: selectionTick)
        .onAppear { focusedLevel = selection }
        .onChange(of: focusedLevel) { _, level in
            guard let level, level != selection else { return }
            choose(level, scrolls: false)
        }
        .onChange(of: selection) { _, level in
            guard focusedLevel != level else { return }
            withAnimation(reduceMotion ? nil : .snappy) {
                focusedLevel = level
            }
        }
    }

    private func option(_ level: MeetupShareLevel) -> some View {
        let isSelected = selection == level
        let tint = tint(for: level)

        return Button {
            choose(level, scrolls: true)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: level.systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(level.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(level.explanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? tint : Color.secondary)
                    .stateSymbolTransition(value: isSelected)
                    .accessibilityHidden(true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
            .background(
                isSelected ? tint.opacity(0.1) : Color.secondary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.75) : .clear, lineWidth: 2)
            }
            .glassEffect(
                isSelected
                    ? .regular.tint(tint).interactive()
                    : .regular.interactive(),
                in: .rect(cornerRadius: 22)
            )
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(level.title)
        .accessibilityValue(isSelected ? "Sélectionné" : "Non sélectionné")
        .accessibilityHint(level.explanation)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func choose(_ level: MeetupShareLevel, scrolls: Bool) {
        guard selection != level else { return }
        selection = level
        onSelection?(level)
        selectionTick += 1

        if scrolls {
            withAnimation(reduceMotion ? nil : .snappy) {
                focusedLevel = level
            }
        }
    }

    private func tint(for level: MeetupShareLevel) -> Color {
        switch level {
        case .positionAndProgress: .blue
        case .progressOnly: .purple
        case .off: .secondary
        }
    }
}
