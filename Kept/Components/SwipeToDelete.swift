import SwiftUI

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

    private static let revealWidth: CGFloat = 84

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            if offset < 0 {
                Button {
                    withAnimation(.spring(duration: 0.25)) { offset = 0 }
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
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
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .offset(x: offset)
        }
        .clipped()
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard isEnabled, abs(value.translation.width) > abs(value.translation.height) else { return }
                    let start = dragStart ?? offset
                    dragStart = start
                    offset = min(0, max(-Self.revealWidth * 1.5, start + value.translation.width))
                }
                .onEnded { value in
                    dragStart = nil
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
