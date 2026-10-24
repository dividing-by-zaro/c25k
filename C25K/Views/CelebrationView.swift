import SwiftData
import SwiftUI

/// Shown the moment a workout's last segment ends.
struct CelebrationView: View {
    var workout: Workout
    var onDone: () -> Void

    @Query private var completions: [Completion]
    @AppStorage(Calories.weightKey) private var weightLb = Calories.defaultWeightLb
    @State private var appeared = false

    private var headline: String {
        if workout.isFinal { return "You're a 5K runner!" }
        if workout.day == 3 { return "Week \(workout.week) complete!" }
        return "Workout complete!"
    }

    private var message: String {
        if workout.isFinal { return "Nine weeks ago this was a 60-second jog. Look at you now." }
        if workout.day == 3 { return "On to week \(workout.week + 1). You've earned the rest day." }
        return "That's \(workout.title) in the books. Rest up — Day \(workout.day + 1) is next."
    }

    var body: some View {
        ZStack {
            GlowBackground()
            Confetti().ignoresSafeArea().allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 22) {
                    medal.padding(.top, 36)

                    VStack(spacing: 8) {
                        Text(headline)
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.forest)
                            .multilineTextAlignment(.center)
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("This workout").font(.headline).foregroundStyle(Theme.ink)
                            HStack(spacing: 10) {
                                tile(Fmt.duration(workout.runSeconds), "running", "figure.run")
                                tile(Fmt.duration(workout.walkSeconds), "walking", "figure.walk")
                                tile(Fmt.number(Calories.estimate(runSeconds: workout.runSeconds,
                                                                  walkSeconds: workout.walkSeconds,
                                                                  weightLb: weightLb)),
                                     "calories", "flame")
                            }
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("All time").font(.headline).foregroundStyle(Theme.ink)
                            StatGrid(stats: Stats(completions))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .statusBarScrim()
        .bottomBar {
            Button("Done", action: onDone)
                .buttonStyle(PillButtonStyle())
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.15)) { appeared = true }
        }
    }

    private var medal: some View {
        ZStack {
            Circle().fill(Theme.mint).frame(width: 150, height: 150)
            Circle().fill(Theme.pine).frame(width: 116, height: 116)
            Image(systemName: workout.isFinal ? "trophy.fill" : "figure.run")
                .font(.system(size: 50, weight: .semibold))
                .foregroundStyle(.white)
        }
        .shadow(color: Theme.forest.opacity(0.3), radius: 20, y: 10)
        .scaleEffect(appeared ? 1 : 0.4)
        .opacity(appeared ? 1 : 0)
    }

    private func tile(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).font(.caption.weight(.semibold)).foregroundStyle(Theme.fern)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.forest)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.mint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Green confetti falling once from the top of the screen.
private struct Confetti: View {
    private struct Piece {
        var x: Double, delay: Double, speed: Double, spin: Double, sway: Double
        var size: CGSize, color: Color, round: Bool
    }

    @State private var pieces: [Piece] = (0..<90).map { _ in
        let palette = [Theme.forest, Theme.pine, Theme.fern, Theme.moss, Theme.sage]
        return Piece(x: .random(in: 0...1), delay: .random(in: 0...1.2), speed: .random(in: 0.18...0.38),
                     spin: .random(in: -6...6), sway: .random(in: 10...30),
                     size: CGSize(width: .random(in: 6...11), height: .random(in: 8...16)),
                     color: palette.randomElement()!, round: Bool.random())
    }

    @State private var start = Date.now

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in pieces {
                    let life = t - p.delay
                    guard life > 0 else { continue }
                    let y = -20 + life * p.speed * size.height
                    guard y < size.height + 20 else { continue }
                    let x = p.x * size.width + sin(life * 2.4 + p.spin) * p.sway
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(life * p.spin))
                    let rect = CGRect(origin: CGPoint(x: -p.size.width / 2, y: -p.size.height / 2), size: p.size)
                    let shape = p.round ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 2)
                    c.fill(shape, with: .color(p.color))
                }
            }
        }
    }
}
