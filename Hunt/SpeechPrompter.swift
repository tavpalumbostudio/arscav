import AVFoundation
import Foundation

@MainActor
final class SpeechPrompter: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    private(set) var lastText = ""
    private(set) var isSpeaking = false
    private var lastSettings = SillyVoiceSettings(pitch: 1.4, rate: 0.5, voiceIdentifier: nil)

    override init() {
        super.init()
        synth.delegate = self
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    func speak(_ text: String, roundIndex: Int, kind: SillyVoiceBank.Kind) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lastText = trimmed
        lastSettings = SillyVoiceBank.settings(forRoundIndex: roundIndex, kind: kind)
        speakLast()
    }

    func repeatCurrent() {
        guard !lastText.isEmpty else { return }
        speakLast()
    }

    private func speakLast() {
        HuntAudioSession.activate()
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: lastText)
        utterance.pitchMultiplier = lastSettings.pitch
        utterance.rate = lastSettings.rate
        if let id = lastSettings.voiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: id) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        isSpeaking = true
        synth.speak(utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}
