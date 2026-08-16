import SwiftUI

extension Color {
    init(transitHex value: String, fallback: Color) {
        let hexadecimal = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hexadecimal.count == 6, let rawValue = UInt64(hexadecimal, radix: 16) else {
            self = fallback
            return
        }

        self.init(
            .sRGB,
            red: Double((rawValue >> 16) & 0xFF) / 255,
            green: Double((rawValue >> 8) & 0xFF) / 255,
            blue: Double(rawValue & 0xFF) / 255,
            opacity: 1
        )
    }
}
