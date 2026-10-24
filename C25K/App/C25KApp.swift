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

/// Home, plus the full-screen workout on top of it when one is running.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(Calories.weightKey) private var weightLb = Calories.defaultWeightLb

    @State private var session: WorkoutSession?

    var body: some View {
        HomeView(onStart: start)
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
            context.insert(Completion(workout: session.workout, weightLb: weightLb, checkedOff: false))
            try? context.save()
        }
        session.start()
        self.session = session
    }
}
