import SwiftData
import SwiftUI
import UserNotifications

@main
struct C25KApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.pine)
        }
        // Everything lives on-device; there's no server.
        .modelContainer(for: Completion.self)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    private let notificationDelegate = NotificationDelegate()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        return true
    }
}

extension WorkoutSession: Identifiable {}

/// The plan and the workout builder as tabs, plus the full-screen workout on
/// top of them when one is running.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(Calories.weightKey) private var weightLb = Calories.defaultWeightLb

    @State private var session: WorkoutSession?

    var body: some View {
        TabView {
            HomeView(onStart: start)
                .tabItem { Label("Plan", systemImage: "calendar") }
            BuilderView(onStart: start)
                .tabItem { Label("Build", systemImage: "square.stack.3d.up.fill") }
        }
            .fullScreenCover(item: $session) { session in
                ActiveWorkoutView(session: session) { self.session = nil }
            }
            .task {
                if let restored = WorkoutSession.restored() { run(restored) }
            }
    }

    private func start(_ workout: Workout) {
        Task {
            await Notifier.requestAuthorization()
            run(WorkoutSession(workout: workout))
        }
    }

    private func run(_ session: WorkoutSession) {
        session.onFinish = { [weak session] in
            guard let session else { return }
            // What was actually done, which for a builder workout finished
            // early is less than the plan.
            let run = session.runSecondsDone, walk = session.walkSecondsDone
            context.insert(Completion(workoutID: session.workout.id, runSeconds: run, walkSeconds: walk,
                                      calories: Calories.estimate(runSeconds: run, walkSeconds: walk,
                                                                  weightLb: weightLb),
                                      checkedOff: false))
            try? context.save()
        }
        session.start()
        self.session = session
    }
}
