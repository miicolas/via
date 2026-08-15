import SwiftUI
import UIKit

enum ViaTheme {
    static let ground = Color(light: "F6F5F0", dark: "101512")
    static let ink = Color(light: "161A18", dark: "F1F5F2")
    static let body = Color(light: "4C5450", dark: "C2CCC6")
    static let muted = Color(light: "6C716D", dark: "ABB4AE")
    static let primary = Color(light: "2F6B5B", dark: "7FCDB5")
    static let critical = Color(light: "8E2F2A", dark: "FFB4AB")
    static let line = Color(light: "DDD9CE", dark: "343B36")
    static let accentSoft = Color(light: "E5EFEB", dark: "18352D")
}

enum ViaFont {
    static let body = Font.custom("Inter-Regular", size: 15, relativeTo: .body)
    static let bodyMedium = Font.custom("Inter-Medium", size: 15, relativeTo: .body)
    static let bodySemibold = Font.custom("Inter-SemiBold", size: 15, relativeTo: .body)
    static let button = Font.custom("Inter-SemiBold", size: 15, relativeTo: .body)
    static let caption = Font.custom("Inter-Regular", size: 13, relativeTo: .caption)
    static let captionStrong = Font.custom("Archivo-ExtraBold", size: 13, relativeTo: .caption)
    static let captionSemibold = Font.custom("Inter-SemiBold", size: 13, relativeTo: .caption)
    static let footnote = Font.custom("Inter-Regular", size: 13, relativeTo: .footnote)
    static let headline = Font.custom("Archivo-Bold", size: 17, relativeTo: .headline)
    static let headlineStrong = Font.custom("Archivo-ExtraBold", size: 17, relativeTo: .headline)
    static let largeTitle = Font.custom("Archivo-ExtraBold", size: 34, relativeTo: .largeTitle)
    static let title = Font.custom("Archivo-Bold", size: 28, relativeTo: .title)
    static let title2 = Font.custom("Archivo-Bold", size: 22, relativeTo: .title2)
    static let title3 = Font.custom("Archivo-Bold", size: 20, relativeTo: .title3)
    static let subheadline = Font.custom("Inter-Regular", size: 15, relativeTo: .subheadline)
    static let subheadlineMedium = Font.custom("Inter-Medium", size: 15, relativeTo: .subheadline)
    static let subheadlineSemibold = Font.custom("Inter-SemiBold", size: 15, relativeTo: .subheadline)
    static let display = Font.custom("Archivo-Black", size: 42, relativeTo: .largeTitle)
    static let displayDigit = display.monospacedDigit()
    static let title3Digit = title3.monospacedDigit()
}

extension Color {
    init(light: String, dark: String) {
        self.init(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(viaHex: dark)
                    : UIColor(viaHex: light)
            }
        )
    }

    init(hex: String) {
        self.init(uiColor: UIColor(viaHex: hex))
    }
}

private extension UIColor {
    convenience init(viaHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        switch cleaned.count {
        case 3:
            self.init(
                red: CGFloat((value >> 8) & 0xF) / 15,
                green: CGFloat((value >> 4) & 0xF) / 15,
                blue: CGFloat(value & 0xF) / 15,
                alpha: 1
            )
        case 6:
            self.init(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        case 8:
            self.init(
                red: CGFloat((value >> 24) & 0xFF) / 255,
                green: CGFloat((value >> 16) & 0xFF) / 255,
                blue: CGFloat((value >> 8) & 0xFF) / 255,
                alpha: CGFloat(value & 0xFF) / 255
            )
        default:
            self.init(white: 0.5, alpha: 1)
        }
    }
}
