import Foundation

struct HealthInsight: Identifiable, Equatable {
    enum Tone {
        case positive
        case neutral
        case warning
    }

    let id = UUID()
    let title: String
    let message: String
    let tone: Tone
}

enum HealthAnalyzer {
    static func insights(for snapshot: HealthSnapshot) -> [HealthInsight] {
        var insights: [HealthInsight] = []

        if snapshot.steps >= 10_000 {
            insights.append(.init(title: "Bewegungsziel erreicht", message: "Du liegst heute bei mindestens 10.000 Schritten.", tone: .positive))
        } else if snapshot.steps > 0 {
            let remaining = max(0, 10_000 - Int(snapshot.steps))
            insights.append(.init(title: "Noch Luft nach oben", message: "Bis zum Schrittziel fehlen dir noch etwa \(remaining) Schritte.", tone: .neutral))
        }

        if snapshot.exerciseMinutes >= 30 {
            insights.append(.init(title: "Training passt", message: "Die WHO-Empfehlung von 30 aktiven Minuten pro Tag ist fuer heute erfuellt.", tone: .positive))
        } else if snapshot.exerciseMinutes > 0 {
            insights.append(.init(title: "Kurze Einheit moeglich", message: "Ein kurzer Spaziergang oder Mobility-Block wuerde dein Aktivitaetsprofil abrunden.", tone: .neutral))
        }

        if snapshot.sleepHours > 0 && snapshot.sleepHours < 6 {
            insights.append(.init(title: "Schlaf im Blick behalten", message: "Die letzte Nacht war kurz. Plane heute bewusst Erholung ein.", tone: .warning))
        } else if snapshot.sleepHours >= 7 {
            insights.append(.init(title: "Solide Erholung", message: "Deine Schlafdauer liegt in einem gesunden Bereich.", tone: .positive))
        }

        if snapshot.restingHeartRate > 0 && snapshot.restingHeartRate >= 85 {
            insights.append(.init(title: "Ruhepuls erhoeht", message: "Ein erhoehter Ruhepuls kann durch Stress, Infekt oder Belastung entstehen. Beobachte den Trend.", tone: .warning))
        }

        if insights.isEmpty {
            insights.append(.init(title: "Daten werden gesammelt", message: "Sobald Health-Daten verfuegbar sind, erscheinen hier persoenliche Hinweise.", tone: .neutral))
        }

        return insights
    }
}
