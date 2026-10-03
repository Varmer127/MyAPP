import SwiftUI

/// Black / white / grey by default. Green, orange and red only ever signal state.
enum Theme {
    static let background = Color(hex: 0x0A0A0A)
    static let card = Color(hex: 0x141414)
    static let cardRaised = Color(hex: 0x1E1E1E)
    static let border = Color.white.opacity(0.08)

    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0x8E8E93)
    static let textTertiary = Color(hex: 0x5C5C61)

    static let green = Color(hex: 0x30D158)
    static let orange = Color(hex: 0xFF9F0A)
    static let red = Color(hex: 0xFF453A)

    static let radius: CGFloat = 14
    static let screenPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 28

    static let goodThreshold = 0.8
    static let poorThreshold = 0.5

    /// Colour for a 0...1 performance value.
    static func performanceColor(_ value: Double?) -> Color {
        guard let value else { return textTertiary }
        if value >= goodThreshold { return green }
        if value >= poorThreshold { return orange }
        return red
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.border, lineWidth: 1))
    }

    /// Small uppercase label used above values and sections.
    func labelStyle(_ color: Color = Theme.textSecondary) -> some View {
        self.font(.system(size: 12, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(color)
    }

    func screenBackground() -> some View {
        self.background(Theme.background.ignoresSafeArea())
    }
}

extension Double {
    /// "86%"
    var percentText: String { "\(Int((self * 100).rounded()))%" }
}

extension Optional where Wrapped == Double {
    var percentText: String { self?.percentText ?? "—" }
}
