import SwiftUI
import UIKit

/// Colours of the widgets. Like the app, they follow the phone's light or dark appearance.
enum WidgetStyle {
    static let background = dynamic(dark: 0x0A0A0A, light: 0xF4F4F6)
    static let card = dynamic(dark: 0x1C1C1E, light: 0xFFFFFF)
    static let text = dynamic(dark: 0xFFFFFF, light: 0x0A0A0A)
    static let onText = dynamic(dark: 0x000000, light: 0xFFFFFF)
    static let secondary = dynamic(dark: 0x8E8E93, light: 0x6A6A70)
    static let track = dynamic(dark: 0x333336, light: 0xDCDCE2)
    static let green = dynamic(dark: 0x30D158, light: 0x1E9E48)
    static let orange = dynamic(dark: 0xFF9F0A, light: 0xD97800)

    private static func dynamic(dark: UInt32, light: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? color(dark) : color(light) })
    }

    private static func color(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    static func label(_ text: String, color: Color = secondary) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(color)
    }

    static func clock(_ seconds: Double) -> String {
        let total = Int(abs(seconds))
        let rest = String(format: "%02d:%02d", (total % 3600) / 60, total % 60)
        let text = total >= 3600 ? "\(total / 3600):\(rest)" : rest
        return seconds < 0 ? "+\(text)" : text
    }
}
