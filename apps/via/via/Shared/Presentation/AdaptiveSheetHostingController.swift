import UIKit

@MainActor
final class AdaptiveSheetHostingController: UIViewController {
    private let layout = AdaptiveSheetLayoutCoordinator()
    private var maximumWidth: CGFloat
    private var isActive: Bool

    init(width: CGFloat, isActive: Bool) {
        maximumWidth = width
        self.isActive = isActive
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyLayout()
    }

    func update(width: CGFloat, isActive: Bool) {
        let needsLayout = maximumWidth != width || self.isActive != isActive
        maximumWidth = width
        self.isActive = isActive

        guard needsLayout || !layout.hasSheet else { return }
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.applyLayout()
        }
    }

    func restoreSystemLayout() {
        layout.restore(in: view.window)
    }

    private func applyLayout() {
        guard let sheetController = sheetPresentationController,
              let sheet = sheetController.containerView,
              let window = view.window else { return }

        sheetController.animateChanges { [layout, maximumWidth, isActive] in
            layout.apply(
                to: sheet,
                in: window,
                maximumWidth: maximumWidth,
                isActive: isActive
            )
        }
    }
}
