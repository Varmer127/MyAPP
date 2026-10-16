import SwiftUI

/// A simple body seen from the front and the back, with muscles lit by intensity (0...1).
/// Drawn from plain shapes for Kept, no third-party artwork.
struct MuscleMapView: View {
    let intensity: [Muscle: Double]
    var showsLabels = true

    private enum Side { case front, back }

    private struct Region {
        let muscle: Muscle?
        let side: Side
        /// In a 100 × 200 box per figure.
        let rect: CGRect
        let radius: CGFloat
        var isEllipse = false
    }

    private static func r(_ muscle: Muscle?, _ side: Side, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                          _ radius: CGFloat = 6, ellipse: Bool = false) -> Region {
        Region(muscle: muscle, side: side, rect: CGRect(x: x, y: y, width: w, height: h), radius: radius, isEllipse: ellipse)
    }

    /// Each muscle that sits on both sides of the body is listed twice, left and right.
    private static let regions: [Region] = {
        var list: [Region] = []
        for side in [Side.front, .back] {
            list.append(r(nil, side, 40, 2, 20, 22, ellipse: true))               // head
            list.append(r(nil, side, 45, 23, 10, 6, 2))                            // neck
            list.append(r(.shoulders, side, 22, 30, 16, 14, 7, ellipse: true))
            list.append(r(.shoulders, side, 62, 30, 16, 14, 7, ellipse: true))
            list.append(r(.forearms, side, 10, 72, 11, 30, 5))
            list.append(r(.forearms, side, 79, 72, 11, 30, 5))
            list.append(r(.calves, side, 33, 150, 13, 38, 6))
            list.append(r(.calves, side, 54, 150, 13, 38, 6))
        }
        list += [
            r(.traps, .front, 39, 27, 22, 5, 2),
            r(.chest, .front, 36, 32, 14, 16, 5),
            r(.chest, .front, 50, 32, 14, 16, 5),
            r(.biceps, .front, 18, 44, 11, 26, 5),
            r(.biceps, .front, 71, 44, 11, 26, 5),
            r(.abs, .front, 42, 50, 16, 34, 5),
            r(.obliques, .front, 34, 52, 8, 28, 4),
            r(.obliques, .front, 58, 52, 8, 28, 4),
            r(.quads, .front, 31, 92, 17, 50, 7),
            r(.quads, .front, 52, 92, 17, 50, 7),
            r(.adductors, .front, 46, 94, 8, 30, 3),

            r(.traps, .back, 36, 26, 28, 14, 6),
            r(.upperBack, .back, 38, 40, 24, 12, 4),
            r(.lats, .back, 32, 44, 12, 26, 6),
            r(.lats, .back, 56, 44, 12, 26, 6),
            r(.lowerBack, .back, 42, 56, 16, 24, 4),
            r(.triceps, .back, 18, 44, 11, 26, 5),
            r(.triceps, .back, 71, 44, 11, 26, 5),
            r(.glutes, .back, 32, 84, 18, 18, 8),
            r(.glutes, .back, 50, 84, 18, 18, 8),
            r(.hamstrings, .back, 31, 104, 17, 42, 7),
            r(.hamstrings, .back, 52, 104, 17, 42, 7),
        ]
        return list
    }()

    var body: some View {
        HStack(spacing: 20) {
            figure(.front, label: "ZEPŘEDU")
            figure(.back, label: "ZEZADU")
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private func figure(_ side: Side, label: String) -> some View {
        VStack(spacing: 6) {
            Canvas { context, size in
                let scale = min(size.width / 100, size.height / 200)
                let offsetX = (size.width - 100 * scale) / 2
                for region in Self.regions where region.side == side {
                    let rect = CGRect(x: offsetX + region.rect.minX * scale, y: region.rect.minY * scale,
                                      width: region.rect.width * scale, height: region.rect.height * scale)
                    let path = region.isEllipse
                        ? Path(ellipseIn: rect)
                        : Path(roundedRect: rect, cornerRadius: region.radius * scale)
                    context.fill(path, with: .color(color(for: region.muscle)))
                }
            }
            if showsLabels {
                Text(label).font(.system(size: 9, weight: .semibold)).tracking(0.8).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func color(for muscle: Muscle?) -> Color {
        guard let muscle, let value = intensity[muscle], value > 0 else { return Theme.cardRaised }
        return Theme.green.opacity(0.25 + 0.75 * min(value, 1))
    }

    private var accessibilityText: String {
        let lit = Muscle.allCases.filter { (intensity[$0] ?? 0) > 0 }.map(\.title)
        return lit.isEmpty ? "Mapa svalů, nic nezvýrazněno" : "Mapa svalů: \(lit.joined(separator: ", "))"
    }
}
