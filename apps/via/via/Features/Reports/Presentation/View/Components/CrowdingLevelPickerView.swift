import SwiftUI

struct CrowdingLevelPickerView: View {
    let onSelect: (CrowdingLevel) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Affluence")
                        .font(.largeTitle.weight(.bold))

                    Spacer(minLength: 16)

                    ReportCloseButton {
                        onCancel()
                        dismiss()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

                ScrollView {
                    GlassEffectContainer(spacing: 10) {
                        VStack(spacing: 0) {
                            ForEach(CrowdingLevel.allCases, id: \.self) { level in
                                ReportCardView(
                                    title: level.title,
                                    systemImage: level.systemImage,
                                    tint: level.tint,
                                    accessibilityHint: level.explanation,
                                    accessibilityActionLabel: "Choisir \(level.title)"
                                ) {
                                    onSelect(level)
                                }

                                if level != CrowdingLevel.allCases.last {
                                    Divider()
                                        .padding(.leading, 14)
                                        .padding(.trailing, 58)
                                }
                            }
                        }
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(
                            cornerRadius: 18,
                            style: .continuous
                        ))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .frame(maxWidth: 640, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
