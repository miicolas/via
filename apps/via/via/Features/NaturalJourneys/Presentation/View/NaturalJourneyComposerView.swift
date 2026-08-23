import SwiftUI

struct NaturalJourneyComposerView: View {
  var viewModel: SearchViewModel
  var onClose: () -> Void = {}

  @FocusState private var isInputFocused: Bool

  var body: some View {
    @Bindable var viewModel = viewModel

    NaturalJourneyInputView(
      query: $viewModel.naturalQuery,
      isFocused: $isInputFocused,
      errorMessage: viewModel.naturalInputMessage,
      isEnabled: viewModel.naturalSearchState != .loading,
      onEdit: editQuery,
      onSubmit: viewModel.submitNaturalSearch,
      onDismiss: onClose
    )
    .onChange(of: viewModel.naturalSearchState, initial: true) { _, state in
      switch state {
      case .input, .clarification, .decision, .unsupported, .failed:
        Task { @MainActor in isInputFocused = true }
      case .dismissed, .onboarding, .loading, .availability:
        isInputFocused = false
      }
    }
  }

  private func editQuery() {
    if viewModel.naturalSearchState != .input {
      viewModel.modifyNaturalQuery()
    }
    viewModel.naturalQueryDidChange()
  }
}
