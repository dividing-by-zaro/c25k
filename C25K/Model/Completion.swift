import Foundation
import SwiftData

/// A finished workout, stored on-device with SwiftData.
///
/// Either recorded by the in-app timer, or checked off by hand for a workout
/// done elsewhere — in which case the plan's own durations stand in for the
/// measured ones, so the stats still add up.
@Model
final class Completion {
    var workoutID: String
    var date: Date
    var runSeconds: Int
    var walkSeconds: Int
    var calories: Double
    var checkedOff: Bool

    init(workoutID: String, date: Date = .now, runSeconds: Int, walkSeconds: Int,
         calories: Double, checkedOff: Bool) {
        self.workoutID = workoutID
        self.date = date
        self.runSeconds = runSeconds
        self.walkSeconds = walkSeconds
        self.calories = calories
        self.checkedOff = checkedOff
    }

    convenience init(workout: Workout, weightLb: Double, checkedOff: Bool, date: Date = .now) {
        self.init(workoutID: workout.id, date: date,
                  runSeconds: workout.runSeconds, walkSeconds: workout.walkSeconds,
                  calories: Calories.estimate(runSeconds: workout.runSeconds,
                                              walkSeconds: workout.walkSeconds,
                                              weightLb: weightLb),
                  checkedOff: checkedOff)
    }
}

/// Totals across a set of completions.
struct Stats {
    var workouts = 0
    var runSeconds = 0
    var walkSeconds = 0
    var calories = 0.0

    init<S: Sequence>(_ completions: S) where S.Element == Completion {
        for c in completions {
            workouts += 1
            runSeconds += c.runSeconds
            walkSeconds += c.walkSeconds
            calories += c.calories
        }
    }

    var runMinutes: Int { runSeconds / 60 }
    var walkMinutes: Int { walkSeconds / 60 }
}

/// Calorie estimate from MET values (Compendium of Physical Activities):
/// kcal = MET × body weight in kg × hours.
enum Calories {
    static let walkMET = 3.5   // brisk walk, ~3 mph
    static let runMET = 7.0    // general jogging

    static let weightKey = "weightLb"
    static let defaultWeightLb = 150.0

    static func estimate(runSeconds: Int, walkSeconds: Int, weightLb: Double) -> Double {
        let kg = weightLb * 0.453_592
        return (runMET * Double(runSeconds) + walkMET * Double(walkSeconds)) / 3600 * kg
    }
}
