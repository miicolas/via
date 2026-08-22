import Foundation

enum SelectedStationLoadingState: Sendable, Equatable {
  case idle
  case loading
  case loaded
  case failed(ViaError)
}
