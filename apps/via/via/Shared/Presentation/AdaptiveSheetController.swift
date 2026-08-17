import SwiftUI

struct AdaptiveSheetController: UIViewControllerRepresentable {
    let width: CGFloat
    let isActive: Bool

    func makeUIViewController(context: Context) -> AdaptiveSheetHostingController {
        AdaptiveSheetHostingController(width: width, isActive: isActive)
    }

    func updateUIViewController(
        _ viewController: AdaptiveSheetHostingController,
        context: Context
    ) {
        viewController.update(width: width, isActive: isActive)
    }

    static func dismantleUIViewController(
        _ viewController: AdaptiveSheetHostingController,
        coordinator: Void
    ) {
        viewController.restoreSystemLayout()
    }
}
