import SwiftUI

/// The full-screen timer: what to do now, how long is left, what's next.
/// Turns into the celebration when the last segment ends.
struct ActiveWorkoutView: View {
    let session: WorkoutSession
    var onDone: () -> Void

    @State private var confirmingEnd = false

    var body: some View {
        if session.isFinished {
            CelebrationView(workout: session.workout, onDone: onDone)
                .transition(.opacity)
        } else {
            timer
        }
    }

    private var kind: Segment.Kind { session.segment.kind }

    /// Running is the deepest green, walking a lighter leafy one.
    private var background: Color {
        switch kind {
        case .run: Theme.forest
        case .walk: Theme.fern
        case .warmup, .cooldown: Theme.pine
        }
    }

    private var timer: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 12)

            VStack(spacing: 10) {
                Image(systemName: kind.isRunning ? "figure.run" : "figure.walk")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Theme.mint)
                    .symbolEffect(.bounce, value: session.currentIndex)
                Text(session.isPaused ? "Paused" : kind.command)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                if let pos = session.intervalPosition {
                    Text("\(kind == .run ? "Run" : "Walk") \(pos.number) of \(pos.of)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.mint.opacity(0.8))
                }
            }
            .animation(.snappy, value: session.currentIndex)

            Spacer(minLength: 20)

            ZStack {
                ProgressRing(progress: session.segmentProgress, lineWidth: 16,
                             track: .white.opacity(0.12), fill: Theme.mint)
                VStack(spacing: 4) {
                    Text(Fmt.clock(session.segmentRemaining))
                        .font(.system(size: 68, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                    Text("left in this \(kind == .run ? "run" : "walk")")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .frame(width: 270, height: 270)

            Spacer(minLength: 20)

            nextUp
            Spacer(minLength: 16)
            overallProgress
            controls
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.6), value: kind)
        .confirmationDialog("End this workout?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("End workout", role: .destructive) {
                session.end()
                onDone()
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("It won't be counted. You can check it off later if you finish it another way.")
        }
    }

    private var topBar: some View {
        HStack {
            Button { confirmingEnd = true } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.14), in: Circle())
            }
            .accessibilityLabel("End workout")
            Spacer()
            Text(session.workout.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.top, 8)
    }

    @ViewBuilder private var nextUp: some View {
        HStack(spacing: 12) {
            if let next = session.nextSegment {
                Image(systemName: next.kind.isRunning ? "figure.run" : "figure.walk")
                    .foregroundStyle(Theme.forest)
                    .frame(width: 36, height: 36)
                    .background(Theme.mint, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("Up next").font(.caption).foregroundStyle(.white.opacity(0.65))
                    Text("\(next.kind.label) | \(Fmt.duration(next.seconds))")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                }
            } else {
                Image(systemName: "flag.checkered")
                    .foregroundStyle(Theme.forest)
                    .frame(width: 36, height: 36)
                    .background(Theme.mint, in: Circle())
                Text("Last stretch. Nearly done!")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var overallProgress: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                // On the dark background: runs bright, walks softer, the rest faint.
                ZStack(alignment: .leading) {
                    SegmentStrip(workout: session.workout, spacing: 2,
                                 color: { $0 == .run ? .white.opacity(0.28) : .white.opacity(0.14) })
                    SegmentStrip(workout: session.workout, spacing: 2,
                                 color: { $0 == .run ? .white : Theme.moss })
                        .mask(alignment: .leading) {
                            Rectangle().frame(width: geo.size.width * session.totalProgress)
                        }
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(Fmt.clock(session.elapsed, roundingUp: false)) elapsed")
                Spacer()
                Text("\(Fmt.clock(session.totalRemaining)) to go")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.bottom, 20)
    }

    private var controls: some View {
        HStack(spacing: 28) {
            Color.clear.frame(width: 56, height: 56)

            Button {
                session.isPaused ? session.resume() : session.pause()
            } label: {
                Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(background)
                    .frame(width: 84, height: 84)
                    .background(.white, in: Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(session.isPaused ? "Resume" : "Pause")

            Button(action: session.skipSegment) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.14), in: Circle())
            }
            .accessibilityLabel("Skip to next interval")
        }
    }
}
