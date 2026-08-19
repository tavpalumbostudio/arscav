import AudioToolbox
import AVFoundation
import UIKit

/// Audio session shared by speech and sound effects.
enum HuntAudioSession {
    static func activate() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.defaultToSpeaker, .mixWithOthers]
            )
            try session.setActive(true, options: [])
        } catch {
            try? session.setCategory(
                .playback,
                mode: .default,
                options: [.defaultToSpeaker, .mixWithOthers]
            )
            try? session.setActive(true, options: [])
        }
    }
}

/// Hunt feedback — bundled WAV tones plus alert sounds (audible even with silent switch).
@MainActor
final class HuntSoundFX {
    static let shared = HuntSoundFX()

    private enum Clip: String, CaseIterable {
        case flip
        case success
        case miss
        case complete

        var alertSound: SystemSoundID {
            switch self {
            case .flip: 1306
            case .success: 1057
            case .miss: 1103
            case .complete: 1111
            }
        }
    }

    private var players: [Clip: AVAudioPlayer] = [:]
    private var observers: [NSObjectProtocol] = []

    private init() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { notification in
            Self.handleInterruption(notification)
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { _ in
            HuntAudioSession.activate()
        })
    }

    func prepare() {
        HuntAudioSession.activate()
        for clip in Clip.allCases {
            players[clip] = loadPlayer(for: clip)
        }
    }

    func playFlip() {
        play(.flip)
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.45)
    }

    func playSuccess() {
        play(.success)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func playMiss() {
        play(.miss)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
    }

    func playComplete() {
        play(.complete)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func play(_ clip: Clip) {
        HuntAudioSession.activate()
        AudioServicesPlayAlertSound(clip.alertSound)

        guard let player = players[clip] ?? loadPlayer(for: clip) else { return }
        players[clip] = player
        player.currentTime = 0
        if player.isPlaying {
            player.stop()
            player.currentTime = 0
        }
        player.play()
    }

    private func loadPlayer(for clip: Clip) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: clip.rawValue, withExtension: "wav", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: clip.rawValue, withExtension: "wav") else {
            return nil
        }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.volume = 1.0
        player.prepareToPlay()
        return player
    }

    private static func handleInterruption(_ notification: Notification) {
        guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue),
              type == .ended else { return }
        HuntAudioSession.activate()
        shared.prepare()
    }
}
