import AVFoundation
import SwiftUI
import UIKit

/// The camera inside the app, looking for a friend's Kept QR code. Hands back the friend code and closes;
/// any other QR code gets a short note and the camera keeps looking.
struct QRScannerView: View {
    let onCode: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var access = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var wrongCode = false
    @State private var torchOn = false
    /// The camera reports the same code many times a second; only the first one counts.
    @State private var done = false

    private static let frameSide: CGFloat = 250

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch access {
            case .authorized:
                if AVCaptureDevice.default(for: .video) != nil {
                    CameraPreview(torchOn: torchOn) { handle($0) }
                        .ignoresSafeArea()
                    viewfinder
                } else {
                    notice(symbol: "camera.fill", text: "Fotoaparát tu není k dispozici.")
                }
            case .notDetermined:
                ProgressView().tint(.white)
            default:
                VStack(spacing: 16) {
                    notice(symbol: "camera.fill",
                           text: "Kept nemá přístup k fotoaparátu. Povol ho v Nastavení a QR kód naskenuješ přímo tady.")
                    Button("OTEVŘÍT NASTAVENÍ") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .white, textColor: .black))
                    .padding(.horizontal, 40)
                }
            }
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .scaledFont(.body, weight: .bold)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Zavřít")
                    Spacer()
                    if access == .authorized, AVCaptureDevice.default(for: .video)?.hasTorch == true {
                        Button { torchOn.toggle() } label: {
                            Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .scaledFont(.body, weight: .bold)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel(torchOn ? "Vypnout svítilnu" : "Zapnout svítilnu")
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                Spacer()
            }
        }
        .task {
            guard access == .notDetermined else { return }
            _ = await AVCaptureDevice.requestAccess(for: .video)
            access = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    private var viewfinder: some View {
        VStack(spacing: 22) {
            RoundedRectangle(cornerRadius: 28)
                .stroke(wrongCode ? Theme.orange : .white, lineWidth: 4)
                .frame(width: Self.frameSide, height: Self.frameSide)
                .shadow(color: .black.opacity(0.4), radius: 10)
                .animation(.easeOut(duration: 0.2), value: wrongCode)
            Text(wrongCode ? "Tohle není QR kód z Kept." : "Namiř na QR kód kamaráda.")
                .scaledFont(.body, weight: .semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .contentTransition(.opacity)
        }
        .accessibilityElement(children: .combine)
    }

    private func notice(symbol: String, text: LocalizedStringKey) -> some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .scaledFont(.title)
                .foregroundStyle(.white.opacity(0.7))
            Text(text)
                .scaledFont(.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func handle(_ value: String) {
        guard !done else { return }
        guard let url = URL(string: value), let code = FriendLink.code(from: url) else {
            guard !wrongCode else { return }
            Haptics.warning()
            wrongCode = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                wrongCode = false
            }
            return
        }
        done = true
        Haptics.success()
        onCode(code)
        dismiss()
    }
}

/// The live camera picture with a QR code reader on top of it.
private struct CameraPreview: UIViewRepresentable {
    let torchOn: Bool
    let onValue: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onValue: onValue) }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = context.coordinator.session
        view.previewLayer.videoGravity = .resizeAspectFill
        context.coordinator.start()
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        context.coordinator.onValue = onValue
        context.coordinator.setTorch(torchOn)
    }

    static func dismantleUIView(_ view: PreviewView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let session = AVCaptureSession()
        var onValue: (String) -> Void
        private let queue = DispatchQueue(label: "cz.philipstryka.kept.qrscanner")

        init(onValue: @escaping (String) -> Void) {
            self.onValue = onValue
            super.init()
            configure()
        }

        private func configure() {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.beginConfiguration()
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                if output.availableMetadataObjectTypes.contains(.qr) { output.metadataObjectTypes = [.qr] }
            }
            session.commitConfiguration()
        }

        func start() {
            queue.async { [session] in if !session.isRunning { session.startRunning() } }
        }

        func stop() {
            setTorch(false)
            queue.async { [session] in if session.isRunning { session.stopRunning() } }
        }

        func setTorch(_ on: Bool) {
            guard let device = AVCaptureDevice.default(for: .video), device.hasTorch,
                  device.torchMode != (on ? .on : .off),
                  (try? device.lockForConfiguration()) != nil else { return }
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let value = metadataObjects.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first else { return }
            onValue(value)
        }
    }
}
