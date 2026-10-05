import SwiftUI
import AVFoundation

/// Full-screen intro video shown over the app on a cold start.
/// Starts muted so it never interrupts music; a tap anywhere skips it once the app underneath is ready.
struct IntroView: View {
    let isReady: Bool
    let onFinish: () -> Void

    @State private var player: AVPlayer
    @State private var isMuted = true
    @State private var hasEnded = false

    init(url: URL, isReady: Bool, onFinish: @escaping () -> Void) {
        self.isReady = isReady
        self.onFinish = onFinish
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PlayerLayerView(player: player)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    if isReady { finish() }
                }
            VStack {
                HStack {
                    Button(action: toggleSound) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                Spacer()
                Text(isReady ? "Aplikace je načtená · klepni pro přeskočení" : "Načítám aplikaci…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.35))
                    .clipShape(Capsule())
                    .animation(.easeInOut(duration: 0.3), value: isReady)
            }
            .padding(Theme.screenPadding)
        }
        .onAppear {
            configureAudio()
            player.isMuted = true
            player.play()
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)) { _ in
            hasEnded = true
            if isReady { finish() }
        }
        .onChange(of: isReady) { _, ready in
            if ready, hasEnded { finish() }
        }
    }

    private func toggleSound() {
        isMuted.toggle()
        configureAudio()
        player.isMuted = isMuted
    }

    /// Muted playback mixes with whatever is already playing; turning sound on takes over the audio output.
    private func configureAudio() {
        let session = AVAudioSession.sharedInstance()
        if isMuted {
            try? session.setCategory(.ambient, options: [.mixWithOthers])
        } else {
            try? session.setCategory(.playback)
        }
        try? session.setActive(true)
    }

    private func finish() {
        player.pause()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        onFinish()
    }
}

/// Bare video surface without the system playback controls.
private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {}

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
