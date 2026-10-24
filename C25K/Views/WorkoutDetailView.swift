import SwiftData
import SwiftUI

/// A day's plan, step by step, with Start and check-off.
struct WorkoutDetailView: View {
    var workout: Workout
    var onStart: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var completions: [Completion]
    @AppStorage(Calories.weightKey) private var weightLb = Calories.defaultWeightLb

    private var mine: [Completion] { completions.filter { $0.workoutID == workout.id } }
    private var isDone: Bool { !mine.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(workout.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.forest)
                    Text(workout.summary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                    if let last = mine.last {
                        Label(last.checkedOff ? "Checked off \(last.date.formatted(date: .abbreviated, time: .omitted))"
                                              : "Done \(last.date.formatted(date: .abbreviated, time: .omitted))",
                              systemImage: "checkmark.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.pine)
                            .padding(.top, 4)
                    }
                }

                HStack(spacing: 10) {
                    summaryTile(Fmt.duration(workout.totalSeconds), "total")
                    summaryTile(Fmt.duration(workout.runSeconds), "running")
                    summaryTile(Fmt.duration(workout.walkSeconds), "walking")
                }

                SegmentStrip(workout: workout, spacing: 2).frame(height: 8)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(workout.segments.enumerated()), id: \.offset) { i, segment in
                        step(segment, isLast: i == workout.segments.count - 1)
                    }
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button(action: onStart) {
                    Label(isDone ? "Do it again" : "Start workout", systemImage: "play.fill")
                }
                .buttonStyle(PillButtonStyle())

                Button(action: toggle) {
                    Label(isDone ? "Mark as not done" : "Already did it — check off",
                          systemImage: isDone ? "arrow.uturn.backward" : "checkmark")
                }
                .buttonStyle(PillButtonStyle(fill: Theme.mint, text: Theme.pine))
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .background(.white)
        }
        .background(.white)
        .presentationDetents([.large])
        .presentationCornerRadius(32)
    }

    private func summaryTile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(Theme.forest)
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.mist, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// One row of the vertical timeline.
    private func step(_ segment: Segment, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Theme.color(for: segment.kind))
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)
                if !isLast {
                    Rectangle().fill(Theme.mint).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            HStack {
                Text(segment.kind.label)
                    .font(.body.weight(segment.kind == .run ? .semibold : .regular))
                    .foregroundStyle(segment.kind == .run ? Theme.ink : Theme.muted)
                Spacer()
                Text(Fmt.duration(segment.seconds))
                    .font(.system(.body, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }
            .padding(.bottom, 16)
        }
    }

    private func toggle() {
        if isDone {
            mine.forEach(context.delete)
        } else {
            context.insert(Completion(workout: workout, weightLb: weightLb, checkedOff: true))
        }
        try? context.save()
        dismiss()
    }
}
