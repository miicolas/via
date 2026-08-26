import SwiftUI

struct LinesView: View {
  @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress

  var viewModel: LinesViewModel
  var accountModel: AccountModel?

  @State private var navigationPath = NavigationPath()

  init(viewModel: LinesViewModel, accountModel: AccountModel? = nil) {
    self.viewModel = viewModel
    self.accountModel = accountModel
  }

  var body: some View {
    @Bindable var viewModel = viewModel

    NavigationStack(path: $navigationPath) {
      LinesScreenContent(viewModel: viewModel)
        .navigationTitle("Lignes")
        .toolbarTitleDisplayMode(.inlineLarge)
        .searchable(text: $viewModel.searchText, prompt: "Ligne, mode, bus…")
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            LinesFilterMenu(filter: $viewModel.filter)
          }
        }
        .navigationDestination(for: LineStatus.self) { status in
          LineDetailView(
            viewModel: viewModel.detailViewModel(for: status.route),
            route: status.route,
            accountModel: accountModel,
            isFavorite: Binding(
              get: { viewModel.isFavorite(status.route.id) },
              set: { isFavorite in
                guard isFavorite != viewModel.isFavorite(status.route.id) else { return }
                _ = viewModel.toggleFavorite(route: status.route)
              }
            )
          )
        }
        .onChange(of: viewModel.requestedRouteID) { _, _ in
          openRequestedRoute()
        }
        .onChange(of: viewModel.requestedRoute) { _, _ in
          openRequestedRoute()
        }
        .onChange(of: viewModel.board.value) { _, _ in
          openRequestedRoute()
        }
    }
    .task { await viewModel.runAutomaticRefresh() }
    .task(id: viewModel.searchText) {
      await viewModel.search(query: viewModel.searchText)
    }
    .task { openRequestedRoute() }
    .opacity(tabVisibilityProgress)
    .scrollEdgeEffectStyle(.soft, for: .vertical)
  }

  private func openRequestedRoute() {
    if let status = viewModel.requestedRoute {
      navigationPath.append(status)
      viewModel.consumeRequestedRoute()
      return
    }
    guard let routeID = viewModel.requestedRouteID,
      let status = (viewModel.board.value?.lines ?? viewModel.remoteMatches)
        .first(where: { $0.route.id == routeID })
    else { return }
    navigationPath.append(status)
    viewModel.consumeRequestedRoute()
  }
}
