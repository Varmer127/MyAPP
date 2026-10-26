import SwiftUI

/// A way into the friends screen from other places (Today, Statistics, the profile). It opens the screen as a sheet,
/// so no extra tab is needed.
struct FriendsEntryCard: View {
    private let account = AccountService.shared
    private let friends = FriendsService.shared
    @State private var isOpen = false

    private var subtitle: LocalizedStringKey {
        guard case .ready = account.state else { return "Odemkni přátele, pošťouchávejte se a sázejte se o body." }
        let waiting = friends.incoming.count
        if waiting > 0 { return "Máš nové žádosti: \(waiting)" }
        return friends.friends.isEmpty ? "Přidej první kamarády." : "Přátelé: \(friends.friends.count)"
    }

    var body: some View {
        Button { isOpen = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.2")
                    .scaledFont(.heading)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Theme.cardRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("PŘÁTELÉ").labelStyle(Theme.textPrimary)
                    Text(subtitle)
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: account.isSignedIn ? "chevron.right" : "lock.fill")
                    .foregroundStyle(Theme.textTertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isOpen) {
            NavigationStack {
                FriendsView()
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zavřít") { isOpen = false } } }
            }
            .appAppearance()
        }
        .task { if account.isSignedIn { await friends.reload() } }
    }
}

/// A thin bar under a horizontal row that shows there is more to scroll to, and how far along it is.
struct ScrollHintBar: ViewModifier {
    private struct Metrics: Equatable {
        var offset: CGFloat
        var content: CGFloat
        var container: CGFloat
    }

    @State private var metrics = Metrics(offset: 0, content: 1, container: 1)

    private var overflows: Bool { metrics.content > metrics.container + 1 }

    func body(content: Content) -> some View {
        VStack(spacing: 8) {
            content
                .onScrollGeometryChange(for: Metrics.self) {
                    Metrics(offset: $0.contentOffset.x, content: $0.contentSize.width, container: $0.containerSize.width)
                } action: { _, new in
                    metrics = new
                }
            if overflows {
                GeometryReader { proxy in
                    let thumb = max(36, proxy.size.width * metrics.container / metrics.content)
                    let travel = proxy.size.width - thumb
                    let maxOffset = max(1, metrics.content - metrics.container)
                    let progress = min(max(metrics.offset / maxOffset, 0), 1)
                    Capsule().fill(Theme.cardRaised)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Theme.textSecondary)
                                .frame(width: thumb)
                                .offset(x: travel * progress)
                        }
                }
                .frame(height: 4)
                .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    func scrollHintBar() -> some View { modifier(ScrollHintBar()) }
}
