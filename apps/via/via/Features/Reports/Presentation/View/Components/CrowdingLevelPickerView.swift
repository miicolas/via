import SwiftUI

struct CrowdingLevelPickerView: View {
    let onSelect: (CrowdingLevel) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(CrowdingLevel.allCases, id: \.self) { level in
                        Button {
                            onSelect(level)
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: level.systemImage)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .accessibilityHidden(true)
                                    .frame(width: 48, height: 48)
                                    .glassEffect(.regular.tint(level.tint), in: .circle)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(level.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(level.explanation)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(.secondary.opacity(0.08), in: RoundedRectangle(
                                cornerRadius: 20,
                                style: .continuous
                            ))
                            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Affluence \(level.title)")
                        .accessibilityHint(level.explanation)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Quel niveau d’affluence ?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }
}
