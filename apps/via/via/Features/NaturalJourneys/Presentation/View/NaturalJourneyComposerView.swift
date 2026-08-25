import SwiftUI

struct NaturalJourneyComposerView: View {
  var viewModel: SearchViewModel
  var onClose: () -> Void = {}

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @FocusState private var isInputFocused: Bool

  var body: some View {
    @Bindable var viewModel = viewModel

    VStack(spacing: 12) {
      if showsPanel {
        NaturalJourneyStatePanel(viewModel: viewModel)
          .transition(reduceMotion ? .opacity : AnyTransition(.blurReplace))
      }

      if showsField {
        NaturalJourneyInputView(
          query: $viewModel.naturalQuery,
          isFocused: $isInputFocused,
          errorMessage: viewModel.naturalInputErrorMessage,
          isThinking: viewModel.naturalSearchState == .loading,
          onEdit: editQuery,
          onSubmit: viewModel.submitNaturalSearch,
          onDismiss: onClose
        )
      }
    }
    .animation(
      reduceMotion ? nil : .smooth(duration: 0.35),
      value: viewModel.naturalSearchState
    )
    .onChange(of: viewModel.naturalSearchState, initial: true) { _, state in
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
    NaturalJourneyPresentationPolicy.showsPanel(viewModel.naturalSearchState)
  }

  /// The field stays under every conversational panel — the phrase is right
  /// there for « Modifier la demande » — but has nothing to offer while
  /// Apple Intelligence itself is unavailable or the onboarding is showing.
  private var showsField: Bool {
    switch viewModel.naturalSearchState {
    case .availability, .onboarding:
      false
    case .dismissed, .input, .loading, .clarification, .decision, .unsupported, .failed:
      true
    }
  }

  private func editQuery() {
    if viewModel.naturalSearchState != .input {
      viewModel.modifyNaturalQuery()
    }
    viewModel.naturalQueryDidChange()
  }
}
