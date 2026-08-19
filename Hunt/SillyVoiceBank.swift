import AVFoundation

struct SillyVoiceSettings: Equatable {
    var pitch: Float
    var rate: Float
    var voiceIdentifier: String?
}

enum SillyVoiceBank {
    static func settings(forRoundIndex index: Int, kind: Kind = .prompt) -> SillyVoiceSettings {
        let palettes: [(pitch: Float, rate: Float, ids: [String])] = [
            (1.72, 0.38, ["com.apple.voice.compact.en-US.Samantha", "com.apple.ttsbundle.siri_Nicky_en-US_compact"]),
            (0.62, 0.32, ["com.apple.voice.compact.en-GB.Daniel", "com.apple.ttsbundle.siri_Aaron_en-US_compact"]),
            (1.35, 0.36, ["com.apple.voice.compact.en-AU.Karen", "com.apple.voice.compact.en-IE.Moira"]),
            (1.55, 0.40, ["com.apple.voice.compact.en-US.Fred", "com.apple.speech.synthesis.voice.Fred"]),
            (1.80, 0.39, ["com.apple.voice.compact.en-US.Samantha"]),
            (0.78, 0.34, ["com.apple.voice.compact.en-IN.Rishi", "com.apple.voice.compact.en-GB.Daniel"])
        ]
        let base = palettes[index % palettes.count]
        var pitch = base.pitch
        var rate = base.rate
        switch kind {
        case .prompt:
            break
        case .success:
            pitch = min(1.9, pitch + 0.10)
            rate = min(0.42, rate + 0.02)
        case .decoy:
            pitch = max(0.5, pitch - 0.15)
            rate = max(0.28, rate - 0.04)
        }
        let identifier = base.ids.first { id in
            AVSpeechSynthesisVoice(identifier: id) != nil
        }
        return SillyVoiceSettings(pitch: pitch, rate: rate, voiceIdentifier: identifier)
    }

    enum Kind {
        case prompt
        case success
        case decoy
    }
}
