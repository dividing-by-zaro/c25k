import Foundation
import UserNotifications

/// Local notifications for every segment change, so the cues reach the lock
/// screen (and a paired watch) when the app isn't in front.
enum Notifier {
    private static var center: UNUserNotificationCenter { .current() }

    static func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    /// Replaces any pending cues with ones for the rest of the workout,
    /// counted from `elapsed` seconds in.
    static func schedule(workout: Workout, elapsed: TimeInterval) {
        cancelAll()
        let segments = workout.segments
        var cues: [Cue] = []

        for (i, start) in workout.segmentStarts.enumerated() {
            let segment = segments[i]
            if TimeInterval(start) > elapsed {
                let next = i + 1 < segments.count ? segments[i + 1] : nil
                let content = UNMutableNotificationContent()
                content.title = segment.kind.command
                content.body = Announcer.detail(segment, next: next)
                cues.append(Cue(at: start, id: "segment-\(i)", content: content,
                                clip: Announcer.clipName(segment)))
            }
            for offset in segment.checkInOffsets where TimeInterval(start + offset) > elapsed {
                let content = UNMutableNotificationContent()
                content.title = "\(offset / 60) minutes"
                content.body = "Great job. Keep running!"
                cues.append(Cue(at: start + offset, id: "checkin-\(i)-\(offset)", content: content,
                                clip: Announcer.checkInClip(offset)))
            }
        }

        let content = UNMutableNotificationContent()
        content.title = workout.isFinal ? "You did it — 5K ready! 🎉" : "Workout complete! 🎉"
        content.body = "\(workout.title) is done. Open the app to celebrate."
        cues.append(Cue(at: workout.totalSeconds, id: "finished", content: content,
                        clip: workout.isFinal ? "finished-final" : "finished"))

        // iOS keeps at most 64 pending; the session tops them up when the
        // app comes back to the front.
        for cue in cues.sorted(by: { $0.at < $1.at }).prefix(60) {
            add(cue.content, in: TimeInterval(cue.at) - elapsed, id: cue.id, clip: cue.clip)
        }
    }

    private struct Cue {
        var at: Int
        var id: String
        var content: UNMutableNotificationContent
        var clip: String
    }

    /// The cue's voice clip doubles as the notification sound, so it's spoken
    /// on the lock screen too; without one it's the standard chime.
    private static func add(_ content: UNMutableNotificationContent, in seconds: TimeInterval,
                            id: String, clip: String) {
        content.sound = Announcer.clipURL(clip) != nil
            ? UNNotificationSound(named: UNNotificationSoundName("\(clip).wav"))
            : .default
        content.interruptionLevel = .active
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        center.add(UNNotificationRequest(identifier: "c25k.\(id)", content: content, trigger: trigger))
    }

    static func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}

/// Keeps workout cues out of the banner while the app is open — the
/// `Announcer` already speaks them there.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        []
    }
}
