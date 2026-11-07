import SwiftUI

/// A segmented switch made of the same glass as the tab bar: the glass drop slides to the chosen segment,
/// stretches on the way and settles with a small bounce. Before iOS 26 there is no Liquid Glass,
/// so it falls back to the system segmented picker.
struct LiquidSegmented<Value: Hashable>: View {
    let options: [(value: Value, title: LocalizedStringKey)]
    @Binding var selection: Value
    var accessibilityLabel: LocalizedStringKey = ""

    var body: some View {
        if #available(iOS 26, *) {
            GlassSegments(options: options, selection: $selection)
                .accessibilityLabel(accessibilityLabel)
        } else {
            Picker(accessibilityLabel, selection: $selection) {
                ForEach(options.indices, id: \.self) { index in
                    Text(options[index].title).tag(options[index].value)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

@available(iOS 26, *)
private struct GlassSegments<Value: Hashable>: View {
    let options: [(value: Value, title: LocalizedStringKey)]
    @Binding var selection: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Grows for a moment while the drop travels, so it looks like liquid being pulled across.
    @State private var stretch = false

    private static var inset: CGFloat { 3 }

    private var selectedIndex: Int { options.firstIndex { $0.value == selection } ?? 0 }

    var body: some View {
        GeometryReader { proxy in
            let width = (proxy.size.width - Self.inset * 2) / CGFloat(max(options.count, 1))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.clear)
                    .glassEffect(.regular.tint(Theme.textPrimary.opacity(0.06)).interactive(), in: .capsule)
                    .frame(width: width, height: proxy.size.height - Self.inset * 2)
                    .scaleEffect(x: stretch ? 1.16 : 1, y: stretch ? 0.88 : 1)
                    .offset(x: Self.inset + width * CGFloat(selectedIndex))
                HStack(spacing: 0) {
                    ForEach(options.indices, id: \.self) { index in
                        segment(index)
                    }
                }
                .padding(.horizontal, Self.inset)
            }
        }
        .frame(height: 40)
        .background(Theme.cardRaised.opacity(0.7), in: Capsule())
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private func segment(_ index: Int) -> some View {
        let isOn = index == selectedIndex
        return Button {
            guard !isOn else { return }
            Haptics.light()
            if reduceMotion {
                selection = options[index].value
                return
            }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.9)) { stretch = true }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) { selection = options[index].value }
            Task {
                try? await Task.sleep(for: .milliseconds(170))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { stretch = false }
            }
        } label: {
            Text(options[index].title)
                .scaledFont(.caption, weight: .semibold)
                .foregroundStyle(isOn ? Theme.textPrimary : Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
