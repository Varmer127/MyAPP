import SwiftUI
import UIKit

/// Black / white / grey by default. Green, orange and red only ever signal state.
/// Every colour has a dark and a light variant and follows the appearance chosen in Settings.
enum Theme {
    static let background = Color(dark: 0x0A0A0A, light: 0xF4F4F6)
    static let card = Color(dark: 0x141414, light: 0xFFFFFF)
    static let cardRaised = Color(dark: 0x1E1E1E, light: 0xE9E9ED)
    static let border = Color(dark: 0xFFFFFF, light: 0x000000).opacity(0.08)
    /// The muscle map: untrained muscles, the skin showing between them, and the thin lines around each muscle.
    static let figure = Color(dark: 0x2C2C31, light: 0xDCDCE2)
    static let figureSkin = Color(dark: 0x1C1C1F, light: 0xEEEEF1)
    static let figureLine = Color(dark: 0x3C3C43, light: 0xC6C6CE)

    static let textPrimary = Color(dark: 0xFFFFFF, light: 0x0A0A0A)
    /// Text or icon placed on a `textPrimary` or accent-coloured fill.
    static let onPrimary = Color(dark: 0x000000, light: 0xFFFFFF)
    static let textSecondary = Color(dark: 0x8E8E93, light: 0x6A6A70)
    /// Meant for icons and thin lines. Text in this colour was under 3 : 1 against the cards, so it now sits at about 5 : 1,
    /// right next to `textSecondary`: there are two readable text levels, not three.
    static let textTertiary = Color(dark: 0x8A8A90, light: 0x6F6F76)

    // Deeper on a light background so they reach 4.5 : 1 as text on both the cards and the page.
    static let green = Color(dark: 0x30D158, light: 0x16803A)
    static let orange = Color(dark: 0xFF9F0A, light: 0xA35B00)
    static let red = Color(dark: 0xFF453A, light: 0xD92D20)

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

extension Color {
    /// A colour that switches with the interface style.
    init(dark: UInt32, light: UInt32) {
        self.init(UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case dark, light, system

    static let storageKey = "appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: "Tmavý"
        case .light: "Světlý"
        case .system: "Automaticky"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}

/// Applies the appearance chosen in Settings. Sheets and covers need it too, as they do not inherit it.
private struct AppAppearanceModifier: ViewModifier {
    @AppStorage(AppAppearance.storageKey) private var raw = AppAppearance.dark.rawValue

    func body(content: Content) -> some View {
        content.preferredColorScheme((AppAppearance(rawValue: raw) ?? .dark).colorScheme)
    }
}

extension View {
    func appAppearance() -> some View { modifier(AppAppearanceModifier()) }

    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.border, lineWidth: 1))
            .modifier(CardHighlight())
    }

    /// Small uppercase label used above values and sections.
    func labelStyle(_ color: Color = Theme.textSecondary) -> some View {
        self.scaledFont(.caption, weight: .semibold)
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

    /// "82,5 kg"
    var kilogramText: String {
        "\(formatted(.number.precision(.fractionLength(0...1)).locale(.app))) kg"
    }
}

extension Optional where Wrapped == Double {
    var percentText: String { self?.percentText ?? "—" }
}


/// In the dark appearance a card is almost the colour of the page (1.07 : 1), so a thin light on its top edge,
/// fading out towards the middle, lifts it off the background. Invisible in the light appearance.
private struct CardHighlight: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.overlay {
            if scheme == .dark {
                RoundedRectangle(cornerRadius: Theme.radius)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.12), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
    }
}
