import Foundation

struct HealthMetric: Identifiable, Equatable {
    enum Kind: String, Identifiable, Hashable {
        case steps
        case activeEnergy
        case exercise
        case distance
        case restingHeartRate
        case sleep

        var id: String {
            rawValue
        }
    }

    let kind: Kind
    let title: String
    let value: Double
    let unit: String
    let goal: Double?

    var id: Kind {
        kind
    }

    var iconName: String {
        switch kind {
        case .steps: "figure.walk.motion"
        case .activeEnergy: "flame.fill"
        case .exercise: "figure.strengthtraining.traditional"
        case .distance: "point.topleft.down.curvedto.point.bottomright.up"
        case .restingHeartRate: "heart.text.square.fill"
        case .sleep: "moon.stars.fill"
        }
    }

    var progress: Double? {
        guard let goal, goal > 0 else { return nil }
        return min(value / goal, 1)
    }

    var progressLabel: String {
        guard let goal else { return "Live-Wert" }
        return "\(Int(min(value, goal).rounded())) / \(Int(goal.rounded()))"
    }

    var formattedValue: String {
        switch kind {
        case .steps:
            return NumberFormatter.wholeNumber.string(from: value as NSNumber) ?? "\(Int(value))"
        case .activeEnergy:
            return "\(Int(value.rounded()))"
        case .exercise, .sleep:
            return value.formatted(.number.precision(.fractionLength(1)))
        case .distance:
            return value.formatted(.number.precision(.fractionLength(2)))
        case .restingHeartRate:
            return "\(Int(value.rounded()))"
        }
    }
}

struct HealthTrendPoint: Identifiable, Equatable {
    let date: Date
    let value: Double

    var id: Date {
        date
    }
}

extension NumberFormatter {
    static let wholeNumber: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
