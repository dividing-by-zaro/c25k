import Foundation

/// One piece of a workout from the builder: a run, a walk, or run/walk
/// intervals that repeat a set number of times or until you stop.
struct Block: Identifiable, Hashable, Codable {
    enum Kind: String, Codable, CaseIterable {
        case run, walk, interval

        var name: String {
            switch self {
            case .run: "Run"
            case .walk: "Walk"
            case .interval: "Intervals"
            }
        }

        var icon: String {
            switch self {
            case .run: "figure.run"
            case .walk: "figure.walk"
            case .interval: "repeat"
            }
        }
    }

    var id = UUID()
    var kind: Kind
    /// Length of a run or walk block.
    var seconds = 600
    /// The two halves of one interval.
    var runSeconds = 60
    var walkSeconds = 90
    /// How many times the interval plays. Ignored when `forever`.
    var repeats = 6
    /// Loop the interval until you tap Finish.
    var forever = false

    static func new(_ kind: Kind) -> Block {
        switch kind {
        case .run: Block(kind: .run, seconds: 1200)
        case .walk: Block(kind: .walk, seconds: 300)
        case .interval: Block(kind: .interval)
        }
    }

    var loopsForever: Bool { kind == .interval && forever }

    /// "Run 20 min", "Run 1 min | Walk 90 sec × 6"
    var title: String {
        switch kind {
        case .run: "Run \(Fmt.duration(seconds))"
        case .walk: "Walk \(Fmt.duration(seconds))"
        case .interval: "Run \(Fmt.duration(runSeconds)) | Walk \(Fmt.duration(walkSeconds))"
        }
    }

    var subtitle: String {
        switch kind {
        case .run: seconds >= 600 ? "Check-in every 5 minutes" : "Run block"
        case .walk: "Walk block"
        case .interval where forever: "Repeats until you stop"
        case .interval: "\(repeats) time\(repeats == 1 ? "" : "s") | \(Fmt.duration(totalSeconds))"
        }
    }

    /// For a forever loop, the length of one pass through the repeats.
    var totalSeconds: Int {
        switch kind {
        case .run, .walk: seconds
        case .interval: (runSeconds + walkSeconds) * repeats
        }
    }
}

/// The lengths the builder offers. Each has a voice clip from
/// `Tools/make_voice.py`, so keep the two lists in step.
enum BlockOptions {
    static let blockSeconds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20, 25, 30, 35, 40, 45, 50, 60].map { $0 * 60 }
    static let intervalSeconds = [30, 45, 60, 90, 120, 180, 240, 300]
    static let repeats = 1...30
}

/// The workout being built, saved on-device between launches.
struct CustomPlan: Codable, Equatable {
    var blocks: [Block] = [Block.new(.walk), Block.new(.run), Block.new(.walk)]

    static let title = "My workout"
    /// An open-ended workout stops on its own after this long.
    static let openEndedCap = 4 * 3600

    /// Index of the first interval that loops forever. Anything after it
    /// never plays.
    var foreverIndex: Int? { blocks.firstIndex(where: \.loopsForever) }

    var playable: ArraySlice<Block> {
        guard let i = foreverIndex else { return blocks[...] }
        return blocks[...i]
    }

    var isOpenEnded: Bool { foreverIndex != nil }

    /// Total time, not counting a forever loop.
    var fixedSeconds: Int {
        playable.filter { !$0.loopsForever }.reduce(0) { $0 + $1.totalSeconds }
    }

    var workout: Workout {
        var segments: [Segment] = []
        for block in playable {
            switch block.kind {
            case .run:
                segments.append(Segment(kind: .run, seconds: block.seconds, checkIns: true))
            case .walk:
                segments.append(Segment(kind: .walk, seconds: block.seconds))
            case .interval:
                let pair = [Segment(kind: .run, seconds: block.runSeconds),
                            Segment(kind: .walk, seconds: block.walkSeconds)]
                // A forever loop repeats until the cap; you'll tap Finish first.
                let cycle = block.runSeconds + block.walkSeconds
                let used = segments.reduce(0) { $0 + $1.seconds }
                let times = block.forever
                    ? max((Self.openEndedCap - used + cycle - 1) / cycle, 1)
                    : block.repeats
                for _ in 0..<times { segments += pair }
            }
        }
        return Workout(customTitle: Self.title, segments: segments,
                       summary: playable.map(\.title).joined(separator: " | "),
                       isOpenEnded: isOpenEnded)
    }

    // MARK: - Storage

    private static let key = "customPlan"

    static func load() -> CustomPlan {
        guard let data = UserDefaults.standard.data(forKey: key),
              let plan = try? JSONDecoder().decode(CustomPlan.self, from: data) else { return CustomPlan() }
        return plan
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
