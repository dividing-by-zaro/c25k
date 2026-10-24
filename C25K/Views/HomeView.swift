import SwiftData
import SwiftUI

struct HomeView: View {
    var onStart: (Workout) -> Void

    @Query(sort: \Completion.date) private var completions: [Completion]
    @State private var selectedWeek: Int?
    @State private var detail: Workout?
    @State private var showingSettings = false

    private var doneIDs: Set<String> { Set(completions.map(\.workoutID)) }

    /// The first workout in the plan not yet done.
    private var nextWorkout: Workout? {
        Program.allWorkouts.first { !doneIDs.contains($0.id) }
    }

    private var currentWeek: Int { nextWorkout?.week ?? Program.weeks.count }
    private var week: Week { Program.weeks[(selectedWeek ?? currentWeek) - 1] }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                WeekPicker(selected: Binding(get: { selectedWeek ?? currentWeek },
                                             set: { selectedWeek = $0 }),
                           current: currentWeek, doneIDs: doneIDs)
                ThisWeekCard(week: week, doneIDs: doneIDs, next: nextWorkout,
                             onOpen: { detail = $0 })
                StatsCard(completions: completions, doneCount: doneIDs.count)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(GlowBackground())
        .statusBarScrim()
        .bottomBar { startBar }
        .sheet(item: $detail) { workout in
            WorkoutDetailView(workout: workout, onStart: {
                detail = nil
                onStart(workout)
            })
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("COUCH TO 5K")
                    .font(.caption.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.75))
                Text(nextWorkout == nil ? "You did it!" : "Week \(currentWeek)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.pine)
                    .frame(width: 46, height: 46)
                    .background(.white, in: Circle())
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    private var subtitle: String {
        guard let next = nextWorkout else { return "All 27 workouts complete." }
        let left = Program.allWorkouts.count - doneIDs.count
        return "Day \(next.day) is up next | \(left) workout\(left == 1 ? "" : "s") to go"
    }

    @ViewBuilder private var startBar: some View {
        if let next = nextWorkout {
            Button { onStart(next) } label: {
                Label("Start \(next.title)", systemImage: "play.fill")
            }
            .buttonStyle(PillButtonStyle())
        }
    }
}

// MARK: - Week picker

private struct WeekPicker: View {
    @Binding var selected: Int
    var current: Int
    var doneIDs: Set<String>

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Program.weeks) { week in
                        pill(week)
                            .id(week.number)
                            .onTapGesture {
                                withAnimation(.snappy) { selected = week.number }
                            }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
            // Let the selected pill's shadow spill past the scroll view's edges.
            .scrollClipDisabled()
            .onAppear { proxy.scrollTo(selected, anchor: .center) }
        }
    }

    private func pill(_ week: Week) -> some View {
        let isSelected = week.number == selected
        let done = week.workouts.filter { doneIDs.contains($0.id) }.count

        return VStack(spacing: 6) {
            Text("Wk")
                .font(.caption)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : Theme.muted)
            Text("\(week.number)")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white : Theme.ink)
            Group {
                if done == 3 {
                    Image(systemName: "checkmark").font(.caption2.weight(.bold))
                } else {
                    Text("\(done)/3").font(.caption2.weight(.medium)).monospacedDigit()
                }
            }
            .foregroundStyle(isSelected ? .white.opacity(0.85) : Theme.fern)
            .frame(height: 12)
        }
        .frame(width: 58, height: isSelected ? 96 : 86)
        .background(
            Capsule().fill(isSelected ? AnyShapeStyle(Theme.pine) : AnyShapeStyle(.white.opacity(0.75)))
        )
        .overlay {
            if week.number == current && !isSelected {
                Capsule().strokeBorder(Theme.fern, lineWidth: 2)
            }
        }
        .shadow(color: Theme.forest.opacity(isSelected ? 0.25 : 0), radius: 10, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Week \(week.number), \(done) of 3 done")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - This week

private struct ThisWeekCard: View {
    var week: Week
    var doneIDs: Set<String>
    var next: Workout?
    var onOpen: (Workout) -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text("Week \(week.number) plan")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 8)

                ForEach(week.workouts) { workout in
                    WorkoutRow(workout: workout,
                               isDone: doneIDs.contains(workout.id),
                               isNext: workout == next)
                        .contentShape(Rectangle())
                        .onTapGesture { onOpen(workout) }
                    if workout.day < 3 { Divider().overlay(Theme.mint) }
                }
            }
        }
    }
}

private struct WorkoutRow: View {
    var workout: Workout
    var isDone: Bool
    var isNext: Bool

    @Environment(\.modelContext) private var context
    @Query private var completions: [Completion]
    @AppStorage(Calories.weightKey) private var weightLb = Calories.defaultWeightLb

    var body: some View {
        HStack(spacing: 14) {
            // The day's circle doubles as its check-off toggle: a number until
            // it's done, then a check.
            Button(action: toggle) {
                ZStack {
                    Circle().fill(isDone ? Theme.pine : (isNext ? Theme.mint : Theme.mist))
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(workout.day)")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(isNext ? Theme.pine : Theme.muted)
                    }
                }
                .frame(width: 42, height: 42)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone ? "Mark Day \(workout.day) as not done" : "Check off Day \(workout.day)")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Day \(workout.day)").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    if isNext {
                        Text("UP NEXT")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.pine)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Theme.mint, in: Capsule())
                    }
                }
                Text(workout.summary)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                SegmentStrip(workout: workout).frame(height: 5).padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }

    /// Checks a workout off without running it — for days done elsewhere.
    private func toggle() {
        withAnimation(.snappy) {
            if isDone {
                for c in completions where c.workoutID == workout.id { context.delete(c) }
            } else {
                context.insert(Completion(workout: workout, weightLb: weightLb, checkedOff: true))
            }
            try? context.save()
        }
    }
}

/// A thin bar showing the workout's shape: run stretches dark, walks light.
struct SegmentStrip: View {
    var workout: Workout
    var spacing: CGFloat = 1.5
    var color: (Segment.Kind) -> Color = Theme.color(for:)

    var body: some View {
        GeometryReader { geo in
            let total = CGFloat(workout.totalSeconds)
            let usable = geo.size.width - spacing * CGFloat(workout.segments.count - 1)
            HStack(spacing: spacing) {
                ForEach(Array(workout.segments.enumerated()), id: \.offset) { _, segment in
                    // Squared-off, not capsules: short intervals would read as dots.
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(color(segment.kind))
                        .frame(width: max(usable * CGFloat(segment.seconds) / total, 1))
                }
            }
        }
    }
}

// MARK: - Stats

struct StatsCard: View {
    var completions: [Completion]
    var doneCount: Int

    var body: some View {
        let stats = Stats(completions)
        let progress = Double(doneCount) / Double(Program.allWorkouts.count)

        Card {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 18) {
                    ZStack {
                        ProgressRing(progress: progress, lineWidth: 9)
                        Text("\(Int((progress * 100).rounded()))%")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(Theme.forest)
                    }
                    .frame(width: 76, height: 76)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your journey")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                        Text("\(doneCount) of \(Program.allWorkouts.count) workouts on the road to 5K")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                }

                StatGrid(stats: stats)
            }
        }
    }
}

/// Workouts, running minutes, walking minutes and calories as a 2×2 grid.
struct StatGrid: View {
    var stats: Stats
    var tint: Color = Theme.mint

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                tile("\(stats.workouts)", stats.workouts == 1 ? "workout" : "workouts", "checkmark.seal")
                tile("\(Fmt.number(stats.calories))", "calories", "flame")
            }
            GridRow {
                tile("\(stats.runMinutes)", "min running", "figure.run")
                tile("\(stats.walkMinutes)", "min walking", "figure.walk")
            }
        }
    }

    private func tile(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.fern)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.forest)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
