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
        let starts = workout.segmentStarts

        for (i, start) in starts.enumerated() where TimeInterval(start) > elapsed {
            let segment = segments[i]
            let next = i + 1 < segments.count ? segments[i + 1] : nil
            let content = UNMutableNotificationContent()
            content.title = segment.kind.command
            content.body = Announcer.detail(segment, next: next)
            add(content, in: TimeInterval(start) - elapsed, id: "segment-\(i)",
                clip: Announcer.clipName(segment))
        }

        let content = UNMutableNotificationContent()
        content.title = workout.isFinal ? "You did it — 5K ready! 🎉" : "Workout complete! 🎉"
        content.body = "\(workout.title) is done. Open the app to celebrate."
        add(content, in: TimeInterval(workout.totalSeconds) - elapsed, id: "finished",
            clip: workout.isFinal ? "finished-final" : "finished")
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
