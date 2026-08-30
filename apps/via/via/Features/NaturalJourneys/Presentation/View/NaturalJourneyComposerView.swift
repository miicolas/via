import SwiftUI

struct NaturalJourneyComposerView: View {
  var dialogue: NaturalJourneyDialogue
  /// The criteria the last finished answer produced, shown by the failure
  /// panel so an offline retry keeps what was already understood.
  var criteria: NaturalJourneyCriteria?
  var onClose: () -> Void = {}

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @FocusState private var isInputFocused: Bool

  var body: some View {
    @Bindable var dialogue = dialogue

    VStack(spacing: 12) {
      if showsPanel {
        NaturalJourneyStatePanel(dialogue: dialogue, criteria: criteria)
          .transition(reduceMotion ? .opacity : AnyTransition(.blurReplace))
      }

      if showsField {
        NaturalJourneyInputView(
          query: $dialogue.query,
          isFocused: $isInputFocused,
          errorMessage: dialogue.inputErrorMessage,
          isThinking: dialogue.state == .loading,
          onEdit: editQuery,
          onSubmit: dialogue.submit,
          onDismiss: onClose
        )
      }
    }
    .animation(
      reduceMotion ? nil : .smooth(duration: 0.35),
      value: dialogue.state
    )
    .onChange(of: dialogue.state, initial: true) { _, state in
      // Only the typing state owns the keyboard: raised anywhere else it
      // would cover the very panel asking the question.
      if NaturalJourneyPresentationPolicy.expandsForInput(state) {
        Task { @MainActor in isInputFocused = true }
      } else {
        isInputFocused = false
      }
    }
  }

  /// Which states have an answer or a question to show above the field.
  private var showsPanel: Bool {
    NaturalJourneyPresentationPolicy.showsPanel(dialogue.state)
  }

  /// The field stays under every conversational panel — the phrase is right
  /// there for « Modifier la demande » — but has nothing to offer while
  /// Apple Intelligence itself is unavailable or the onboarding is showing.
  private var showsField: Bool {
    switch dialogue.state {
    case .availability, .onboarding:
      false
    case .dismissed, .input, .loading, .clarification, .decision, .unsupported, .failed:
      true
    }
  }

  private func editQuery() {
    if dialogue.state != .input {
      dialogue.modifyQuery()
    }
    dialogue.queryDidChange()
  }
}
