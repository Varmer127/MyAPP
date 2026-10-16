import SwiftUI

/// A body seen from the front and the back, covered in its main muscles like an anatomy chart,
/// with muscles lit by intensity (0...1). The most trained muscles glow. Drawn for Kept, no third-party artwork.
/// Several shapes can belong to one muscle group (three parts of the thigh, eight fields of the abs);
/// they always light up together.
struct MuscleMapView: View {
    let intensity: [Muscle: Double]
    var showsLabels = true

    private enum Side { case front, back }

    private enum Outline {
        case path(String)
        case rect(CGFloat, CGFloat, CGFloat, CGFloat, radius: CGFloat)
        case ellipse(CGFloat, CGFloat, CGFloat, CGFloat)

        func path() -> Path {
            switch self {
            case .path(let data): MuscleMapView.parse(data)
            case let .rect(x, y, w, h, radius): Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius)
            case let .ellipse(cx, cy, rx, ry): Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
            }
        }
    }

    /// A shape on the left half of the body (as seen), mirrored onto the right. 
    private struct Region {
        let muscle: Muscle?
        let outline: Outline
    }

    // MARK: Drawing data, in a 200 × 400 box per figure

    private static let head = parse("M100 8 C110 8 116 16 116 28 C116 38 112 46 106 50 L94 50 C88 46 84 38 84 28 C84 16 90 8 100 8 Z")

    private static let body = parse("""
        M100 50 L93 50 C93 56 92 60 90 62 C84 65 72 66 64 69 C54 72 48 80 47 92 C46 104 45 116 44 128 C43 138 42 146 42 152 \
        C39 162 37 186 36 206 C35 214 32 222 33 232 C34 240 38 242 41 238 C43 232 44 222 44 212 C46 196 50 176 52 160 \
        C55 140 58 120 62 106 C64 103 66 104 67 108 C68 124 70 146 72 164 C71 176 67 190 66 204 C64 226 65 258 70 288 \
        C70 296 68 306 68 316 C68 334 72 350 76 362 C77 370 77 376 76 380 C74 386 76 392 84 392 L95 392 C96 386 95 378 94 372 \
        C96 356 97 336 95 318 C94 308 95 300 96 292 C98 270 99 240 100 222 C101 240 102 270 104 292 C105 300 106 308 105 318 \
        C103 336 104 356 106 372 C105 378 104 386 105 392 L116 392 C124 392 126 386 124 380 C123 376 123 370 124 362 \
        C128 350 132 334 132 316 C132 306 130 296 130 288 C135 258 136 226 134 204 C133 190 129 176 128 164 \
        C130 146 132 124 133 108 C134 104 136 103 138 106 C142 120 145 140 148 160 C150 176 154 196 156 212 \
        C156 222 157 232 159 238 C162 242 166 240 167 232 C168 222 165 214 164 206 C163 186 161 162 158 152 \
        C158 146 157 138 156 128 C155 116 154 104 153 92 C152 80 146 72 136 69 C128 66 116 65 110 62 \
        C108 60 107 56 107 50 L100 50 Z
        """)

    private static let front: [Region] = [
        Region(muscle: .traps, outline: .path("M92 58 C88 63 78 66 66 68 C76 71 88 70 96 68 C95 64 93 61 92 58 Z")),
        Region(muscle: .chest, outline: .path("M99 70 C90 69 80 70 72 73 C68 80 64 90 63 98 C68 106 78 110 88 110 C94 110 99 108 99 106 Z")),
        Region(muscle: .shoulders, outline: .path("M66 68 C56 69 48 78 47 92 C46 100 47 108 50 114 C54 108 58 100 62 96 C66 88 70 78 72 72 Z")),
        Region(muscle: .biceps, outline: .path("M50 116 C47 128 46 140 47 150 L54 152 C58 140 61 124 62 106 C57 106 53 110 50 116 Z")),
        Region(muscle: .forearms, outline: .path("M43 156 C40 172 37 190 36 206 L44 210 C46 194 50 176 53 160 C50 156 46 154 43 156 Z")),
        Region(muscle: .obliques, outline: .path("M66 108 C72 112 78 116 82 120 L84 176 C80 186 74 192 68 196 C70 186 72 176 72 164 C70 146 68 126 66 108 Z")),
        Region(muscle: .abs, outline: .rect(86, 112, 13, 16, radius: 3)),
        Region(muscle: .abs, outline: .rect(86, 130, 13, 16, radius: 3)),
        Region(muscle: .abs, outline: .rect(86, 148, 13, 16, radius: 3)),
        Region(muscle: .abs, outline: .rect(86, 166, 13, 16, radius: 3)),
        Region(muscle: .abs, outline: .path("M86 184 L99 184 L99 206 C93 202 88 194 86 184 Z")),
        Region(muscle: .quads, outline: .path("M68 204 C64 224 64 252 68 280 C72 288 78 290 82 288 C80 260 78 232 76 208 Z")),
        Region(muscle: .quads, outline: .path("M77 206 C80 230 82 258 84 288 C88 290 92 286 92 278 C92 252 90 230 86 212 C84 206 80 204 77 206 Z")),
        Region(muscle: .adductors, outline: .path("M87 210 C92 214 98 220 100 224 C99 240 97 252 93 256 C91 238 89 222 87 210 Z")),
        Region(muscle: .quads, outline: .path("M93 256 C97 266 97 280 95 290 L86 291 C90 286 93 272 93 256 Z")),
        Region(muscle: .calves, outline: .path("M69 304 C68 322 70 342 75 362 L80 362 C80 340 80 320 79 302 Z")),
        Region(muscle: .calves, outline: .path("M82 300 C90 304 95 316 95 330 C94 344 92 356 88 366 L82 366 C83 344 83 320 82 300 Z")),
    ]

    private static let back: [Region] = [
        Region(muscle: .lats, outline: .path("M66 112 C76 112 86 108 92 104 C95 120 96 140 94 160 C90 172 84 182 76 190 C74 176 72 164 72 160 C70 140 68 126 66 112 Z")),
        Region(muscle: .lowerBack, outline: .path("M93 140 C96 150 99 160 99 170 L99 196 C94 196 88 192 82 190 C88 180 92 166 93 140 Z")),
        Region(muscle: .upperBack, outline: .path("M68 80 C76 82 84 90 90 100 C86 106 78 110 68 110 C65 100 65 90 68 80 Z")),
        Region(muscle: .traps, outline: .path("M100 52 L94 52 C93 60 86 64 66 68 C76 74 86 84 92 100 C95 110 98 124 100 132 Z")),
        Region(muscle: .shoulders, outline: .path("M66 68 C56 69 48 78 47 92 C46 100 47 108 50 114 C54 106 58 98 64 92 C66 84 68 76 70 72 Z")),
        Region(muscle: .triceps, outline: .path("M50 116 C47 128 46 140 47 150 L55 152 C58 140 61 124 62 106 C57 104 53 108 50 116 Z")),
        Region(muscle: .forearms, outline: .path("M43 156 C40 172 37 190 36 206 L44 210 C46 194 50 176 53 160 C50 156 46 154 43 156 Z")),
        Region(muscle: .glutes, outline: .path("M100 198 C90 194 78 196 68 202 C64 214 66 228 72 238 C82 244 92 244 100 240 Z")),
        Region(muscle: .hamstrings, outline: .path("M68 244 C66 260 68 276 72 288 L82 290 C82 274 81 258 82 244 Z")),
        Region(muscle: .hamstrings, outline: .path("M84 244 C84 260 86 276 88 290 L95 290 C97 276 99 260 99 244 C94 246 88 246 84 244 Z")),
        Region(muscle: .calves, outline: .path("M70 300 C66 316 67 332 72 346 C76 350 80 346 82 340 C82 326 82 312 81 298 Z")),
        Region(muscle: .calves, outline: .path("M83 298 C90 302 96 314 96 330 C95 342 90 350 85 350 C83 336 83 316 83 298 Z")),
        Region(muscle: .calves, outline: .path("M74 352 C80 356 88 356 93 352 C92 362 90 370 88 376 L80 376 C78 368 76 360 74 352 Z")),
    ]

    /// Shapes are parsed once, left half and its mirror together.
    private static let frontPaths = prepare(front)
    private static let backPaths = prepare(back)

    private static func prepare(_ regions: [Region]) -> [(muscle: Muscle?, path: Path)] {
        let mirror = CGAffineTransform(translationX: 200, y: 0).scaledBy(x: -1, y: 1)
        return regions.flatMap { region -> [(muscle: Muscle?, path: Path)] in
            let path = region.outline.path()
            return [(region.muscle, path), (region.muscle, path.applying(mirror))]
        }
    }

    // MARK: View

    var body: some View {
        HStack(spacing: 20) {
            figure(Self.frontPaths, label: "ZEPŘEDU")
            figure(Self.backPaths, label: "ZEZADU")
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private func figure(_ shapes: [(muscle: Muscle?, path: Path)], label: String) -> some View {
        VStack(spacing: 6) {
            Canvas { context, size in
                let scale = min(size.width / 200, size.height / 400)
                let transform = CGAffineTransform(translationX: (size.width - 200 * scale) / 2, y: 0).scaledBy(x: scale, y: scale)
                let lineWidth = max(0.5, 0.8 * scale)
                // Skin underneath; the muscles cover most of it, gaps read as tendons and joints.
                context.fill(Self.head.applying(transform), with: .color(Theme.figureSkin))
                context.fill(Self.body.applying(transform), with: .color(Theme.figureSkin))
                for shape in shapes {
                    let path = shape.path.applying(transform)
                    guard let muscle = shape.muscle else { continue }
                    let value = min(intensity[muscle] ?? 0, 1)
                    context.fill(path, with: .color(Theme.figure))
                    if value > 0 {
                        let fill = Theme.green.opacity(0.35 + 0.65 * value)
                        if value >= 0.6 {
                            // The most trained muscles glow.
                            context.drawLayer { layer in
                                layer.addFilter(.shadow(color: Theme.green.opacity(0.55 * value), radius: 4 * scale))
                                layer.fill(path, with: .color(fill))
                            }
                        } else {
                            context.fill(path, with: .color(fill))
                        }
                    }
                    context.stroke(path, with: .color(Theme.figureLine), style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
                }
            }
            if showsLabels {
                Text(label).font(.system(size: 9, weight: .semibold)).tracking(0.8).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var accessibilityText: String {
        let lit = Muscle.allCases.filter { (intensity[$0] ?? 0) > 0 }.map(\.title)
        return lit.isEmpty ? "Mapa svalů, nic nezvýrazněno" : "Mapa svalů: \(lit.joined(separator: ", "))"
    }

    // MARK: Path data

    /// Reads the absolute M, L, C and Z commands the shapes above are written in.
    private static func parse(_ data: String) -> Path {
        var path = Path()
        var command: Character = "M"
        var numbers: [CGFloat] = []
        var token = ""

        func flushToken() {
            if let value = Double(token) { numbers.append(CGFloat(value)) }
            token = ""
        }
        func run() {
            switch command {
            case "M" where numbers.count >= 2:
                path.move(to: CGPoint(x: numbers[0], y: numbers[1]))
            case "L" where numbers.count >= 2:
                path.addLine(to: CGPoint(x: numbers[0], y: numbers[1]))
            case "C" where numbers.count >= 6:
                path.addCurve(to: CGPoint(x: numbers[4], y: numbers[5]),
                              control1: CGPoint(x: numbers[0], y: numbers[1]),
                              control2: CGPoint(x: numbers[2], y: numbers[3]))
            default:
                break
            }
            numbers = []
        }

        for character in data {
            if character.isLetter {
                flushToken()
                run()
                command = character
                if character == "Z" { path.closeSubpath() }
            } else if character == " " || character == "," || character == "\n" {
                flushToken()
                let needed = command == "C" ? 6 : 2
                if numbers.count == needed { run() }
            } else {
                token.append(character)
            }
        }
        flushToken()
        run()
        return path
    }
}
