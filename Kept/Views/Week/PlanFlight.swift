import SwiftUI

/// Frames of the week's task rows and of the send button, in global coordinates,
/// so newly planned tasks can fly from their row into the button.
struct FlightFramesKey: PreferenceKey {
    static let commitButton = "commitButton"
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Holds the latest frames without making the screen redraw when they change.
final class FlightFrameStore {
    var frames: [String: CGRect] = [:]
}

extension View {
    /// Reports this view's frame under `key` for the planning flight.
    func flightFrame(_ key: String) -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(key: FlightFramesKey.self, value: [key: proxy.frame(in: .global)])
        })
    }
}

/// One activity icon on its way into the send button.
struct PlanFlight: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let from: CGPoint
    let to: CGPoint
    let delay: Double

    static let duration = 0.75
}

/// The icon itself: an arc from the row down into the button, shrinking and fading as it lands.
struct FlyingIcon: View {
    let flight: PlanFlight
    let origin: CGPoint
    @State private var progress: Double = 0

    var body: some View {
        Image(systemName: flight.icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.onPrimary)
            .frame(width: 34, height: 34)
            .background(Theme.textPrimary)
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.25), radius: 6, y: 3)
            .modifier(ArcPosition(progress: progress, from: local(flight.from), to: local(flight.to)))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                try? await Task.sleep(for: .seconds(flight.delay))
                withAnimation(.easeInOut(duration: PlanFlight.duration)) { progress = 1 }
            }
    }

    private func local(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - origin.x, y: point.y - origin.y)
    }
}

/// Places a view along a curve that first lifts a little, then drops into the target.
private struct ArcPosition: ViewModifier, Animatable {
    var progress: Double
    let from: CGPoint
    let to: CGPoint

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = progress
        let control = CGPoint(x: (from.x + to.x) / 2 + (from.x < to.x ? -40 : 40), y: min(from.y, to.y) - 80)
        let x = pow(1 - t, 2) * from.x + 2 * (1 - t) * t * control.x + pow(t, 2) * to.x
        let y = pow(1 - t, 2) * from.y + 2 * (1 - t) * t * control.y + pow(t, 2) * to.y
        return content
            .scaleEffect(1 - 0.45 * t)
            .opacity(t < 0.85 ? 1 : (1 - t) / 0.15)
            .position(x: x, y: y)
    }
}
