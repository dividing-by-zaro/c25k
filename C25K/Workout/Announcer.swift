import AVFoundation
import UIKit

/// Spoken and haptic cues while the app is on screen. Music keeps playing,
/// ducked under the voice.
///
/// Plays the Cartesia clips from `Tools/make_voice.py` when they're bundled,
/// and falls back to the built-in iOS voice for any cue without one.
@MainActor
final class Announcer: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    static let shared = Announcer()

    private let synth = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private let haptics = UINotificationFeedbackGenerator()

    override init() {
        super.init()
        synth.delegate = self
    }

    func announce(_ segment: Segment) {
        haptics.notificationOccurred(.warning)
        say(clip: Self.clipName(segment), else: "\(segment.kind.command). \(Self.spoken(segment.seconds)).")
    }

    func finished(final: Bool) {
        haptics.notificationOccurred(.success)
        say(clip: final ? "finished-final" : "finished", else: "Workout complete. Great job!")
    }

    private func say(clip: String, else text: String) {
        guard UIApplication.shared.applicationState == .active else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? session.setActive(true)
        synth.stopSpeaking(at: .immediate)
        player?.stop()

        if let url = Self.clipURL(clip), let player = try? AVAudioPlayer(contentsOf: url) {
            player.delegate = self
            player.play()
            self.player = player
        } else {
            synth.speak(AVSpeechUtterance(string: text))
        }
    }

    // Either way, hand the volume back to whatever music was playing.
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Voice clips

    /// "run-90", matching the files `Tools/make_voice.py` writes.
    nonisolated static func clipName(_ segment: Segment) -> String {
        "\(segment.kind.rawValue)-\(segment.seconds)"
    }

    nonisolated static func clipURL(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "wav")
    }

    // MARK: - Wording

    /// "Jog for 90 sec, then walk 2 min"
    nonisolated static func detail(_ segment: Segment, next: Segment?) -> String {
        let text = "\(segment.kind.label) for \(Fmt.duration(segment.seconds))"
        guard let next else { return text + ". Nice work!" }
        return text + ", then \(next.kind.label.lowercased()) \(Fmt.duration(next.seconds))"
    }

    /// "90 seconds", "3 minutes", "2 and a half minutes"
    private static func spoken(_ seconds: Int) -> String {
        if seconds < 120 && seconds % 60 != 0 { return "\(seconds) seconds" }
        let m = seconds / 60
        let half = seconds % 60 == 30
        if half { return "\(m) and a half minutes" }
        return m == 1 ? "1 minute" : "\(m) minutes"
    }
}

enum Fmt {
    /// "4:59", or "1:04:59" past the hour. Countdowns round up, so they
    /// read 0:01 until the very end; elapsed time rounds down.
    static func clock(_ seconds: TimeInterval, roundingUp: Bool = true) -> String {
        let s = Int(seconds.rounded(roundingUp ? .up : .down))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    /// "90 sec", "3 min", "2½ min"
    static func duration(_ seconds: Int) -> String {
        if seconds < 120 && seconds % 60 != 0 { return "\(seconds) sec" }
        let m = seconds / 60
        return seconds % 60 == 30 ? "\(m)½ min" : "\(m) min"
    }

    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}
