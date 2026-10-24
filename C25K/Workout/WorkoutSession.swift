import Foundation
import Observation
import UIKit

/// The running timer for one workout.
///
/// Time is derived from wall-clock dates rather than counted ticks, so the
/// session stays correct while the app is backgrounded or the phone is locked.
/// Lock-screen cues come from local notifications scheduled for every segment
/// change; in the foreground the `Announcer` speaks them instead.
@Observable
@MainActor
final class WorkoutSession {
    let workout: Workout

    private var startDate: Date
    private var pausedAt: Date?
    private var pausedTotal: TimeInterval = 0
    private(set) var now = Date.now
    private(set) var isFinished = false

    @ObservationIgnored private var lastIndex = -1
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored var onFinish: (() -> Void)?

    /// True when picked up from a session saved before the app was closed.
    private let isRestored: Bool

    init(workout: Workout) {
        self.workout = workout
        self.startDate = .now
        self.isRestored = false
    }

    private init(workout: Workout, saved: Saved) {
        self.workout = workout
        self.startDate = saved.startDate
        self.pausedAt = saved.pausedAt
        self.pausedTotal = saved.pausedTotal
        self.isRestored = true
        // Don't re-announce the segment we're already in.
        let elapsed = (saved.pausedAt ?? .now).timeIntervalSince(saved.startDate) - saved.pausedTotal
        self.lastIndex = workout.segmentStarts.lastIndex { TimeInterval($0) <= elapsed } ?? 0
    }

    // MARK: - Derived state

    var isPaused: Bool { pausedAt != nil }
    var total: TimeInterval { TimeInterval(workout.totalSeconds) }

    var elapsed: TimeInterval {
        let raw = (pausedAt ?? now).timeIntervalSince(startDate) - pausedTotal
        return min(max(raw, 0), total)
    }

    var currentIndex: Int {
        let starts = workout.segmentStarts
        return starts.lastIndex { TimeInterval($0) <= elapsed } ?? 0
    }

    var segment: Segment { workout.segments[currentIndex] }

    var nextSegment: Segment? {
        let i = currentIndex + 1
        return i < workout.segments.count ? workout.segments[i] : nil
    }

    private var segmentEnd: TimeInterval {
        TimeInterval(workout.segmentStarts[currentIndex] + segment.seconds)
    }

    var segmentRemaining: TimeInterval { max(segmentEnd - elapsed, 0) }
    var segmentProgress: Double { 1 - segmentRemaining / TimeInterval(segment.seconds) }
    var totalRemaining: TimeInterval { total - elapsed }
    var totalProgress: Double { elapsed / total }

    /// Which run/walk interval this is, e.g. run 3 of 8. Nil for the warm-up.
    var intervalPosition: (number: Int, of: Int)? {
        guard segment.kind == .run || segment.kind == .walk else { return nil }
        let same = workout.segments.enumerated().filter { $0.element.kind == segment.kind }
        guard let n = same.firstIndex(where: { $0.offset == currentIndex }) else { return nil }
        return (n + 1, same.count)
    }

    // MARK: - Control

    /// Starts the clock — or, for a restored session, carries on where it was.
    /// Set `onFinish` first: a restored session may already be over.
    func start() {
        if !isRestored {
            startDate = .now
            persist()
        }
        now = .now
        UIApplication.shared.isIdleTimerDisabled = true
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        tick()
        reschedule()
    }

    func pause() {
        guard !isPaused, !isFinished else { return }
        pausedAt = .now
        Notifier.cancelAll()
        persist()
    }

    func resume() {
        guard let pausedAt else { return }
        pausedTotal += Date.now.timeIntervalSince(pausedAt)
        self.pausedAt = nil
        now = .now
        persist()
        reschedule()
    }

    /// Jumps to the start of the next segment.
    func skipSegment() {
        guard !isFinished else { return }
        startDate -= segmentRemaining
        persist()
        tick()
        reschedule()
    }

    /// Stops the session without recording it.
    func end() {
        stop()
        Notifier.cancelAll()
    }

    private func stop() {
        ticker?.invalidate()
        ticker = nil
        UIApplication.shared.isIdleTimerDisabled = false
        Self.clearSaved()
    }

    private func reschedule() {
        guard !isPaused, !isFinished else { return }
        Notifier.schedule(workout: workout, elapsed: elapsed)
    }

    private func tick() {
        now = .now
        guard !isFinished else { return }

        if elapsed >= total {
            isFinished = true
            stop()
            Announcer.shared.finished(final: workout.isFinal)
            onFinish?()
            return
        }

        let index = currentIndex
        if index != lastIndex {
            lastIndex = index
            Announcer.shared.announce(segment)
        }
    }

    // MARK: - Persistence across launches

    private struct Saved: Codable {
        var workoutID: String
        var startDate: Date
        var pausedAt: Date?
        var pausedTotal: TimeInterval
    }

    private static let savedKey = "activeSession"

    private func persist() {
        let saved = Saved(workoutID: workout.id, startDate: startDate,
                          pausedAt: pausedAt, pausedTotal: pausedTotal)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Self.savedKey)
        }
    }

    private static func clearSaved() {
        UserDefaults.standard.removeObject(forKey: savedKey)
    }

    /// The session that was running when the app was last closed, if any.
    static func restored() -> WorkoutSession? {
        guard let data = UserDefaults.standard.data(forKey: savedKey),
              let saved = try? JSONDecoder().decode(Saved.self, from: data),
              let workout = Program.workout(id: saved.workoutID) else { return nil }
        return WorkoutSession(workout: workout, saved: saved)
    }
}
