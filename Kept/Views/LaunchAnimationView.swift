import SwiftUI

/// The short welcome on every cold start: the tile pops in with a warm glow, the check draws itself,
/// the green line slides in, then the name and the promise. About two seconds; a tap skips it.
struct LaunchAnimationView: View {
    let onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tile = false
    @State private var check: CGFloat = 0
    @State private var line = false
    @State private var word = false
    @State private var finished = false

    private static let tileSize: CGFloat = 112

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color(hex: 0x0A0A0A))
                        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color(hex: 0xFFFFFF).opacity(0.12), lineWidth: 1))
                        // The warm glow, as in the flame variant.
                        .shadow(color: Theme.orange.opacity(tile ? 0.35 : 0), radius: 24)
                    VStack(spacing: 8) {
                        CheckShape()
                            .trim(from: 0, to: check)
                            .stroke(Color(hex: 0xFFFFFF), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                            .frame(width: 56, height: 36)
                        Capsule()
                            .fill(Color(hex: 0x30D158))
                            .frame(width: 50, height: 4)
                            .scaleEffect(x: line ? 1 : 0, anchor: .leading)
                    }
                }
                .frame(width: Self.tileSize, height: Self.tileSize)
                .scaleEffect(tile ? 1 : 0.6)
                .opacity(tile ? 1 : 0)
                VStack(spacing: 10) {
                    Text("KEPT")
                        .font(.system(size: 30, weight: .heavy))
                        .tracking(word ? 6 : 14)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Keep what you promise.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                }
                .opacity(word ? 1 : 0)
                .offset(y: word ? 0 : 8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: finish)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Kept. Keep what you promise.")
        .task { await play() }
    }

    private func play() async {
        if reduceMotion {
            tile = true; check = 1; line = true; word = true
            try? await Task.sleep(for: .milliseconds(900))
            return finish()
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { tile = true }
        try? await Task.sleep(for: .milliseconds(420))
        withAnimation(.easeOut(duration: 0.45)) { check = 1 }
        try? await Task.sleep(for: .milliseconds(400))
        withAnimation(.easeOut(duration: 0.35)) { line = true }
        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(.easeOut(duration: 0.6)) { word = true }
        // Let the finished logo sit for a moment before the app takes over.
        try? await Task.sleep(for: .milliseconds(1350))
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

/// The check from the app icon, drawn as one stroke so it can be traced.
private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.33, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
