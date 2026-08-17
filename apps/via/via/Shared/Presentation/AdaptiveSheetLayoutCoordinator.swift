import UIKit

@MainActor
final class AdaptiveSheetLayoutCoordinator {
    private weak var sheet: UIView?
    private var constraints: [NSLayoutConstraint] = []
    private var systemBackgrounds: [(view: UIView, color: UIColor?)] = []

    var hasSheet: Bool { sheet != nil }

    func apply(
        to sheet: UIView,
        in window: UIWindow,
        maximumWidth: CGFloat,
        isActive: Bool
    ) {
        if self.sheet !== sheet {
            restore(in: window)
            self.sheet = sheet
        }

        NSLayoutConstraint.deactivate(constraints)
        constraints.removeAll()

        guard isActive else {
            restoreSystemBackground()
            restoreSystemFrame(of: sheet, in: window)
            return
        }

        if systemBackgrounds.isEmpty {
            clearSystemBackground(in: sheet)
        }

        sheet.translatesAutoresizingMaskIntoConstraints = false
        let equalWidth = sheet.widthAnchor.constraint(equalTo: window.widthAnchor)
        equalWidth.priority = .defaultHigh
        constraints = [
            sheet.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            sheet.topAnchor.constraint(equalTo: window.topAnchor),
            sheet.bottomAnchor.constraint(equalTo: window.bottomAnchor),
            sheet.widthAnchor.constraint(lessThanOrEqualToConstant: maximumWidth),
            equalWidth,
        ]
        NSLayoutConstraint.activate(constraints)
    }

    func restore(in window: UIWindow?) {
        guard let sheet else { return }
        NSLayoutConstraint.deactivate(constraints)
        constraints.removeAll()
        if let window {
            restoreSystemFrame(of: sheet, in: window)
        }
        restoreSystemBackground()
        self.sheet = nil
    }

    private func restoreSystemFrame(of sheet: UIView, in window: UIWindow) {
        sheet.translatesAutoresizingMaskIntoConstraints = true
        sheet.frame = window.bounds
        sheet.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    private func clearSystemBackground(in sheet: UIView) {
        guard let background = sheet.subviews.first(where: { candidate in
            candidate.subviews.contains(where: { $0.backgroundColor != nil })
        }) else { return }

        for subview in background.subviews {
            systemBackgrounds.append((subview, subview.backgroundColor))
            subview.backgroundColor = .clear
        }
    }

    private func restoreSystemBackground() {
        for background in systemBackgrounds {
            background.view.backgroundColor = background.color
        }
        systemBackgrounds.removeAll()
    }
}
