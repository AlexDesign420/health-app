import Foundation

struct HealthSnapshot: Equatable {
    var steps: Double = 0
    var activeEnergy: Double = 0
    var exerciseMinutes: Double = 0
    var distanceKilometers: Double = 0
    var restingHeartRate: Double = 0
    var sleepHours: Double = 0
    var updatedAt: Date?

    var metrics: [HealthMetric] {
        [
            HealthMetric(kind: .steps, title: "Schritte", value: steps, unit: "heute", goal: 10_000),
            HealthMetric(kind: .activeEnergy, title: "Aktive Energie", value: activeEnergy, unit: "kcal", goal: 500),
            HealthMetric(kind: .exercise, title: "Training", value: exerciseMinutes, unit: "min", goal: 30),
            HealthMetric(kind: .distance, title: "Distanz", value: distanceKilometers, unit: "km", goal: 5),
            HealthMetric(kind: .restingHeartRate, title: "Ruhepuls", value: restingHeartRate, unit: "bpm", goal: nil),
            HealthMetric(kind: .sleep, title: "Schlaf", value: sleepHours, unit: "Std.", goal: 8)
        ]
    }
}
