import SwiftUI

/// A fixed point size that follows the reader's text size setting (Dynamic Type).
/// Every size in the app was a fixed number, so larger system text changed nothing. The sizes here are the same
/// numbers at the default setting and grow from there. Small text grows up to about 1.5×, big display numbers only
/// a little, so cards and tiles that were designed around them do not break.
struct ScaledFont: ViewModifier {
    @Environment(\.dynamicTypeSize) private var typeSize
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(size: size * Self.scale(for: typeSize, size: size), weight: weight, design: design))
    }

    /// How much bigger than at the default setting, from the sizes iOS uses for body text.
    static func scale(for typeSize: DynamicTypeSize, size: CGFloat) -> CGFloat {
        let raw: CGFloat = switch typeSize {
        case .xSmall: 14.0 / 17
        case .small: 15.0 / 17
        case .medium: 16.0 / 17
        case .large: 1
        case .xLarge: 19.0 / 17
        case .xxLarge: 21.0 / 17
        case .xxxLarge: 23.0 / 17
        case .accessibility1: 28.0 / 17
        case .accessibility2: 33.0 / 17
        case .accessibility3: 40.0 / 17
        case .accessibility4: 47.0 / 17
        case .accessibility5: 53.0 / 17
        @unknown default: 1
        }
        // Display numbers (hero scores, big timers) hardly grow; ordinary text grows to 1.5×.
        let limit: CGFloat = size >= 34 ? 1.15 : (size >= 22 ? 1.3 : 1.5)
        return raw < 1 ? max(raw, 0.9) : min(raw, limit)
    }
}

extension View {
    func scaledFont(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design))
    }
}

/// The five text sizes of the app. Everything that is not a big display number uses one of them,
/// so screens speak in the same few voices instead of 29 slightly different sizes.
enum TextLevel: CGFloat {
    case caption = 12   // small print, labels, hints
    case body = 15      // ordinary text and buttons
    case heading = 18   // card titles, task titles
    case title = 28     // screen titles, dates, the main figure of a card
    case hero = 56      // the one big number on a screen
}

extension View {
    func scaledFont(_ level: TextLevel, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        scaledFont(level.rawValue, weight: weight, design: design)
    }
}
