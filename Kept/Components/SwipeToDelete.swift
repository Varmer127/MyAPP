import SwiftUI

/// Lets swipe rows inside another swipe row (sets inside an exercise card) win: while an inner row is being
/// swiped, the outer one stays put.
final class SwipeNest {
    var innerDragging = false
}

private struct SwipeNestKey: EnvironmentKey {
    static let defaultValue: SwipeNest? = nil
}

private extension EnvironmentValues {
    var swipeNest: SwipeNest? {
        get { self[SwipeNestKey.self] }
        set { self[SwipeNestKey.self] = newValue }
    }
}

/// Swiping a row to the left uncovers a red delete button; a long swipe deletes straight away.
/// For rows outside a `List`, where the system swipe actions are not available.
private struct SwipeToDelete: ViewModifier {
    let isEnabled: Bool
    var background: Color
    var cornerRadius: CGFloat
    let label: String
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    /// Where the row sat when the current swipe began.
    @State private var dragStart: CGFloat?
    /// Told by swipe rows inside this one when they are being swiped.
    @State private var nest = SwipeNest()
    /// The swipe row this one sits in, if any.
    @Environment(\.swipeNest) private var parent

    private static let revealWidth: CGFloat = 84

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            if offset < 0 {
                Button {
                    withAnimation(.spring(duration: 0.25)) { offset = 0 }
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .scaledFont(.body, weight: .semibold)
                        .foregroundStyle(Color(hex: 0xFFFFFF))
                        .frame(width: Self.revealWidth - 8)
                        .frame(maxHeight: .infinity)
                        .background(Theme.red)
                        .clipShape(RoundedRectangle(cornerRadius: max(cornerRadius, 8)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
            }
            content
                .environment(\.swipeNest, nest)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .offset(x: offset)
        }
        .clipped()
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard isEnabled, abs(value.translation.width) > abs(value.translation.height) else { return }
                    parent?.innerDragging = true
                    // An inner row is being swiped: this one does not move.
                    if nest.innerDragging {
                        if offset != 0 { withAnimation(.spring(duration: 0.2)) { offset = 0 } }
                        dragStart = nil
                        return
                    }
                    let start = dragStart ?? offset
                    dragStart = start
                    offset = min(0, max(-Self.revealWidth * 1.5, start + value.translation.width))
                }
                .onEnded { value in
                    dragStart = nil
                    parent?.innerDragging = false
                    if nest.innerDragging {
                        nest.innerDragging = false
                        return
                    }
                    guard isEnabled, abs(value.translation.width) > abs(value.translation.height) else { return }
                    withAnimation(.spring(duration: 0.25)) {
                        if offset < -Self.revealWidth * 1.3 {
                            offset = 0
                            onDelete()
                        } else {
                            offset = offset < -Self.revealWidth / 2 ? -Self.revealWidth : 0
                        }
                    }
                }
        )
        .accessibilityAction(named: label) { if isEnabled { onDelete() } }
    }
}

extension View {
    /// Adds swipe-left-to-delete to a row that is not inside a `List`.
    /// `background` must match what is behind the row, so the uncovered button does not show through.
    func swipeToDelete(_ label: String = "Smazat", isEnabled: Bool = true, background: Color = Theme.card,
                       cornerRadius: CGFloat = 0, onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeToDelete(isEnabled: isEnabled, background: background, cornerRadius: cornerRadius,
                               label: label, onDelete: onDelete))
    }

    /// Swipe-left-to-delete for a row inside a `List` or `Form`, with the system look.
    func listSwipeToDelete(_ label: String = "Smazat", isEnabled: Bool = true, onDelete: @escaping () -> Void) -> some View {
        swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if isEnabled {
                Button(role: .destructive, action: onDelete) {
                    Label(label, systemImage: "trash")
                }
                .tint(Theme.red)
            }
        }
    }
}
