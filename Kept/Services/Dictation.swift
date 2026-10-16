import AVFoundation
import Speech
import SwiftUI

/// Speech to text for the diary. One field listens at a time; what is heard is appended to that field.
@MainActor
final class Dictation: ObservableObject {
    static let shared = Dictation()

    /// Identifies the field that is listening right now.
    @Published private(set) var activeField: String?
    @Published var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "cs-CZ"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Starts listening for `field`, or stops if it is already listening.
    func toggle(field: String, text: Binding<String>) {
        if activeField == field {
            stop()
            return
        }
        stop()
        Task {
            guard await Self.requestPermissions() else {
                errorMessage = "Kept nemá přístup k mikrofonu nebo k rozpoznávání řeči. Povol je v Nastavení iPhonu → Aplikace → Kept."
                return
            }
            start(field: field, text: text)
        }
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        activeField = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func start(field: String, text: Binding<String>) {
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Rozpoznávání češtiny teď není dostupné."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            let input = engine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()
            // What was typed before stays; the dictated part is replaced as recognition improves.
            let prefix = text.wrappedValue.isEmpty ? "" : text.wrappedValue + " "
            self.request = request
            activeField = field
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    if let result {
                        text.wrappedValue = prefix + result.bestTranscription.formattedString
                    }
                    if error != nil || result?.isFinal == true, self?.activeField == field {
                        self?.stop()
                    }
                }
            }
        } catch {
            errorMessage = "Nahrávání se nepodařilo spustit."
            stop()
        }
    }

    private static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}

/// The microphone button shown next to a diary field when voice entry is switched on.
struct DictationButton: View {
    let field: String
    @Binding var text: String
    @ObservedObject private var dictation = Dictation.shared

    var body: some View {
        let isListening = dictation.activeField == field
        Button {
            dictation.toggle(field: field, text: $text)
        } label: {
            Image(systemName: isListening ? "stop.circle.fill" : "mic.fill")
                .font(.system(size: 17))
                .foregroundStyle(isListening ? Theme.red : Theme.textSecondary)
                .symbolEffect(.pulse, isActive: isListening)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isListening ? "Zastavit diktování" : "Diktovat")
    }
}
