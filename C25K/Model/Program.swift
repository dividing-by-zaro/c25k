import Foundation

/// One timed stretch of a workout.
struct Segment: Hashable, Codable {
    enum Kind: String, Codable {
        case warmup, run, walk, cooldown

        var isRunning: Bool { self == .run }

        /// The instruction shown, spoken and notified when the segment begins.
        var command: String {
            switch self {
            case .warmup: "Warm-up walk"
            case .run: "Start running"
            case .walk: "Start walking"
            case .cooldown: "Cool-down walk"
            }
        }

        var label: String {
            switch self {
            case .warmup: "Brisk warm-up walk"
            case .run: "Jog"
            case .walk: "Walk"
            case .cooldown: "Cool-down walk"
            }
        }
    }

    let kind: Kind
    let seconds: Int
    /// Speak a check-in every five minutes ("10 minutes, nice work").
    /// Set on run blocks from the workout builder.
    var checkIns = false

    /// Offsets into the segment that get a check-in: every 5 minutes, up to
    /// 40 (the clips `Tools/make_voice.py` makes), and never at the very end,
    /// where the next segment's cue takes over.
    var checkInOffsets: [Int] {
        guard checkIns else { return [] }
        return Array(stride(from: 300, through: min(seconds - 1, 2400), by: 300))
    }
}

/// A single day of the plan, e.g. Week 3 | Day 2, or a workout from the
/// builder.
struct Workout: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    /// 0 for a workout from the builder.
    let week: Int
    let day: Int
    let segments: [Segment]
    /// One-line description in the plan's own words.
    let summary: String
    /// Ends when you stop it, not when the clock runs out: the last block
    /// loops until you tap Finish.
    var isOpenEnded = false

    init(week: Int, day: Int, segments: [Segment], summary: String) {
        self.id = "w\(week)d\(day)"
        self.title = "Week \(week) | Day \(day)"
        self.week = week
        self.day = day
        self.segments = segments
        self.summary = summary
    }

    init(customTitle: String, segments: [Segment], summary: String, isOpenEnded: Bool) {
        self.id = Self.customID
        self.title = customTitle
        self.week = 0
        self.day = 0
        self.segments = segments
        self.summary = summary
        self.isOpenEnded = isOpenEnded
    }

    static let customID = "custom"
    var isCustom: Bool { week == 0 }

    var totalSeconds: Int { segments.reduce(0) { $0 + $1.seconds } }
    var runSeconds: Int { segments.filter { $0.kind == .run }.reduce(0) { $0 + $1.seconds } }
    var walkSeconds: Int { totalSeconds - runSeconds }
    var isFinal: Bool { week == Program.weeks.count && day == 3 }

    /// Start offset (in seconds from the beginning) of each segment.
    var segmentStarts: [Int] {
        var starts: [Int] = []
        var t = 0
        for s in segments {
            starts.append(t)
            t += s.seconds
        }
        return starts
    }
}

struct Week: Identifiable, Hashable {
    let number: Int
    let workouts: [Workout]
    var id: Int { number }
}

/// The official Couch to 5K schedule: nine weeks, three workouts a week,
/// each starting with a five-minute brisk warm-up walk and ending with a
/// five-minute cool-down walk.
enum Program {
    private static func min(_ m: Double) -> Int { Int(m * 60) }

    private static func run(_ seconds: Int) -> Segment { Segment(kind: .run, seconds: seconds) }
    private static func walk(_ seconds: Int) -> Segment { Segment(kind: .walk, seconds: seconds) }

    /// Warm-up first, then the given pattern, then the cool-down.
    private static func plan(_ body: [Segment]) -> [Segment] {
        [Segment(kind: .warmup, seconds: min(5))] + body + [Segment(kind: .cooldown, seconds: min(5))]
    }

    private static func repeating(_ pattern: [Segment], times: Int) -> [Segment] {
        Array(repeating: pattern, count: times).flatMap { $0 }
    }

    private static func week(_ n: Int, _ days: [(String, [Segment])]) -> Week {
        Week(number: n, workouts: days.enumerated().map { i, d in
            Workout(week: n, day: i + 1, segments: plan(d.1), summary: d.0)
        })
    }

    private static func same(_ summary: String, _ body: [Segment]) -> [(String, [Segment])] {
        Array(repeating: (summary, body), count: 3)
    }

    static let weeks: [Week] = [
        // "Repeat for 20 min": 8 × (60 + 90 sec) = 20 min.
        week(1, same("Jog 60 sec | Walk 90 sec",
                     repeating([run(60), walk(90)], times: 8))),
        // 6 × (90 sec + 2 min) = 21 min, the closest whole number of sets to 20.
        week(2, same("Jog 90 sec | Walk 2 min",
                     repeating([run(90), walk(min(2))], times: 6))),
        week(3, same("Jog 90 sec | Walk 90 sec | Jog 3 min | Walk 3 min",
                     repeating([run(90), walk(90), run(min(3)), walk(min(3))], times: 2))),
        week(4, same("Jog 3 min | Walk 90 sec | Jog 5 min | Walk 2½ min | Jog 3 min | Walk 90 sec | Jog 5 min",
                     [run(min(3)), walk(90), run(min(5)), walk(150),
                      run(min(3)), walk(90), run(min(5))])),
        week(5, [
            ("Jog 5 min | Walk 3 min | Jog 5 min | Walk 3 min | Jog 5 min",
             [run(min(5)), walk(min(3)), run(min(5)), walk(min(3)), run(min(5))]),
            ("Jog 8 min | Walk 5 min | Jog 8 min",
             [run(min(8)), walk(min(5)), run(min(8))]),
            ("Jog 20 min",
             [run(min(20))]),
        ]),
        week(6, [
            ("Jog 5 min | Walk 3 min | Jog 8 min | Walk 3 min | Jog 5 min",
             [run(min(5)), walk(min(3)), run(min(8)), walk(min(3)), run(min(5))]),
            ("Jog 10 min | Walk 3 min | Jog 10 min",
             [run(min(10)), walk(min(3)), run(min(10))]),
            ("Jog 25 min",
             [run(min(25))]),
        ]),
        week(7, same("Jog 25 min", [run(min(25))])),
        week(8, same("Jog 28 min", [run(min(28))])),
        week(9, same("Jog 30 min", [run(min(30))])),
    ]

    static let allWorkouts: [Workout] = weeks.flatMap(\.workouts)

    static let allIDs = Set(allWorkouts.map(\.id))

    static func workout(id: String) -> Workout? {
        allWorkouts.first { $0.id == id }
    }
}
