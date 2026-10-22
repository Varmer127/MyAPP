import SwiftUI

/// Small drawings for screens that have nothing to show yet, in the spirit of the logo:
/// a tile, a check that draws itself and a green line. All of it is drawn here, nothing is borrowed.
struct EmptyStateArt: View {
    enum Kind { case plan, stats, week }

    let kind: Kind
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false

    var body: some View {
        Group {
            switch kind {
            case .plan: plan
            case .stats: stats
            case .week: week
            }
        }
        .frame(width: 150, height: 104)
        .accessibilityHidden(true)
        .onAppear {
            guard !drawn else { return }
            if reduceMotion { drawn = true } else {
                withAnimation(.easeOut(duration: 0.9).delay(0.2)) { drawn = true }
            }
        }
    }

    // MARK: Plan: a tile with a check waiting to be drawn

    private var plan: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.card)
                .frame(width: 96, height: 96)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
            CheckStroke()
                .trim(from: 0, to: drawn ? 1 : 0)
                .stroke(Theme.textPrimary, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .frame(width: 52, height: 40)
                .offset(y: -6)
            Capsule()
                .fill(Theme.green)
                .frame(width: drawn ? 44 : 0, height: 5)
                .offset(y: 26)
        }
    }

    // MARK: Stats: bars that will grow, with a dashed line over them

    private var stats: some View {
        ZStack(alignment: .bottom) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array([0.35, 0.55, 0.8].enumerated()), id: \.offset) { index, height in
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(index == 2 ? Theme.green.opacity(0.85) : Theme.cardRaised)
                        .frame(width: 28, height: drawn ? 80 * height : 6)
                }
            }
            Path { path in
                path.move(to: CGPoint(x: 8, y: 70))
                path.addQuadCurve(to: CGPoint(x: 142, y: 14), control: CGPoint(x: 70, y: 60))
            }
            .trim(from: 0, to: drawn ? 1 : 0)
            .stroke(Theme.textTertiary, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 6]))
        }
    }

    // MARK: Week: seven days, one of them waiting

    private var week: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { day in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(day == 2 ? Color.clear : Theme.cardRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(day == 2 ? Theme.green : .clear, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    )
                    .frame(width: 16, height: drawn ? (day == 2 ? 62 : 38 + CGFloat(day % 3) * 8) : 8)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(day) * 0.05), value: drawn)
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

/// The check of the logo as an open path, so it can be drawn with `trim`.
struct CheckStroke: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY - rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.02, y: rect.minY + rect.height * 0.04))
        return path
    }
}
