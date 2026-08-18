import SwiftUI
import UIKit

extension View {
    /// Constrains a sheet to a leading side panel of the given width on wide layouts.
    @ViewBuilder
    func adaptiveSheet(_ width: CGFloat, isActive: Bool) -> some View {
        self
            .presentationCompactAdaptation(.none)
            .background {
                if isActive {
                    AdaptiveSheetHelper(width: width, isActive: true)
                } else {
                    AdaptiveSheetHelper(width: width, isActive: false)
                }
            }
    }
}

private struct AdaptiveSheetHelper: UIViewControllerRepresentable {
    var width: CGFloat
    var isActive: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear

        DispatchQueue.main.async {
            guard let sheetController = controller.sheetPresentationController,
                  let sheet = sheetController.containerView,
                  let window = controller.view.window else {
                return
            }

            // The system sheet chrome would otherwise show behind the narrowed panel.
            if let backgroundView = sheet.subviews.first(where: {
                $0.subviews.contains(where: { $0.backgroundColor != nil })
            }) {
                for subview in backgroundView.subviews {
                    subview.backgroundColor = .clear
                }
            }

            sheetController.animateChanges {
                if isActive {
                    sheet.translatesAutoresizingMaskIntoConstraints = false

                    NSLayoutConstraint.activate([
                        sheet.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                        sheet.topAnchor.constraint(equalTo: window.topAnchor),
                        sheet.bottomAnchor.constraint(equalTo: window.bottomAnchor),
                        sheet.widthAnchor.constraint(lessThanOrEqualToConstant: width),
                        sheet.widthAnchor.constraint(equalTo: window.widthAnchor).priority(.defaultHigh)
                    ])
                } else {
                    sheet.translatesAutoresizingMaskIntoConstraints = true
                    sheet.frame = window.frame
                    sheet.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                }
            }
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private extension NSLayoutConstraint {
    func priority(_ value: UILayoutPriority) -> Self {
        self.priority = value
        return self
    }
}
