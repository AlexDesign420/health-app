import Foundation
import HealthKit
import Combine

@MainActor
final class HealthManager: ObservableObject {
    enum AuthorizationState: Equatable {
        case unknown
        case unavailable
        case needsRequest
        case requested
        case connected

        var title: String {
            switch self {
            case .unknown: "Noch nicht geprueft"
            case .unavailable: "Nicht verfuegbar"
            case .needsRequest: "Freigabe anfragen"
            case .requested: "Freigabe angefragt"
            case .connected: "Verbunden"
            }
        }

        var subtitle: String {
            switch self {
            case .unknown: "Die App hat den aktuellen Health-Status noch nicht ausgewertet."
            case .unavailable: "HealthKit funktioniert nur auf einem echten iPhone mit aktivierter Health-App."
            case .needsRequest: "Die App hat den Health-Dialog fuer diese Datentypen noch nicht angefragt."
            case .requested: "Die Freigabe wurde bereits angefragt. Aus Datenschutzgruenden verraet HealthKit nicht, welche Leserechte exakt erlaubt oder abgelehnt wurden."
            case .connected: "Die Health-Verbindung ist aktiv. Einzelne Werte koennen trotzdem leer sein, wenn dazu noch keine Daten in Apple Health vorliegen."
            }
        }
    }

    @Published var snapshot = HealthSnapshot()
    @Published var insights: [HealthInsight] = []
    @Published var authorizationState: AuthorizationState = .unknown
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let healthStore = HKHealthStore()
    private lazy var readableTypes: Set<HKObjectType> = {
        Set([
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        ].compactMap { $0 })
    }()

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var authorizationStatus: String {
        authorizationState.title
    }

    var authorizationDescription: String {
        authorizationState.subtitle
    }

    func refreshAuthorizationState() async {
        guard isHealthDataAvailable else {
            authorizationState = .unavailable
            return
        }

        do {
            let status = try await healthStore.getRequestStatusForAuthorization(toShare: [], read: readableTypes)
            switch status {
            case .shouldRequest:
                authorizationState = .needsRequest
            case .unnecessary:
                if snapshot.updatedAt != nil {
                    authorizationState = .connected
                } else {
                    authorizationState = .requested
                }
            case .unknown:
                authorizationState = .unknown
            @unknown default:
                authorizationState = .unknown
            }
        } catch {
            authorizationState = .unknown
        }
    }

    func requestAuthorizationAndLoad() async {
        errorMessage = nil

        guard isHealthDataAvailable else {
            authorizationState = .unavailable
            errorMessage = "HealthKit ist auf diesem Geraet nicht verfuegbar. Teste die App auf einem echten iPhone."
            return
        }

        do {
            try await requestAuthorization()
            await refreshAuthorizationState()
            await loadHealthData()
        } catch {
            await refreshAuthorizationState()
            errorMessage = friendlyErrorMessage(for: error)
        }
    }

    func loadHealthData() async {
        guard isHealthDataAvailable else {
            authorizationState = .unavailable
            errorMessage = "HealthKit ist nur auf einem echten iPhone verfuegbar."
            return
        }

        isLoading = true
        defer { isLoading = false }

        await refreshAuthorizationState()
        let dayStart = Calendar.current.startOfDay(for: Date())
        async let steps = safeValue { try await self.cumulativeQuantity(.stepCount, unit: .count(), from: dayStart) }
        async let energy = safeValue { try await self.cumulativeQuantity(.activeEnergyBurned, unit: .kilocalorie(), from: dayStart) }
        async let exercise = safeValue { try await self.cumulativeQuantity(.appleExerciseTime, unit: .minute(), from: dayStart) }
        async let distance = safeValue { try await self.cumulativeQuantity(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), from: dayStart) }
        async let restingHeartRate = safeValue { try await self.mostRecentQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute())) }
        async let sleep = safeValue { try await self.sleepHoursSinceYesterday() }

        let loadedSnapshot = HealthSnapshot(
            steps: await steps,
            activeEnergy: await energy,
            exerciseMinutes: await exercise,
            distanceKilometers: await distance,
            restingHeartRate: await restingHeartRate,
            sleepHours: await sleep,
            updatedAt: Date()
        )

        snapshot = loadedSnapshot
        insights = HealthAnalyzer.insights(for: loadedSnapshot)
        authorizationState = .connected

        if hasAnyData(in: loadedSnapshot) {
            errorMessage = nil
        } else {
            errorMessage = "Es wurden noch keine auslesbaren Health-Daten gefunden. Bitte pruefe in Apple Health unter Profil > Apps > Health Advisor, ob Lesen fuer Schritte, Aktivitaet, Distanz, Schlaf und Ruhepuls aktiviert ist."
        }
    }

    func trend(for kind: HealthMetric.Kind, days: Int = 14) async -> [HealthTrendPoint] {
        guard isHealthDataAvailable else { return [] }

        do {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
            let endDate = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()

            switch kind {
            case .steps:
                return try await dailyCumulativeQuantity(.stepCount, unit: .count(), from: startDate, to: endDate)
            case .activeEnergy:
                return try await dailyCumulativeQuantity(.activeEnergyBurned, unit: .kilocalorie(), from: startDate, to: endDate)
            case .exercise:
                return try await dailyCumulativeQuantity(.appleExerciseTime, unit: .minute(), from: startDate, to: endDate)
            case .distance:
                return try await dailyCumulativeQuantity(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), from: startDate, to: endDate)
            case .restingHeartRate:
                return try await dailyAverageQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), from: startDate, to: endDate)
            case .sleep:
                return try await dailySleepHours(from: startDate, to: endDate)
            }
        } catch {
            return []
        }
    }

    private func requestAuthorization() async throws {
        try await healthStore.requestAuthorization(toShare: [], read: readableTypes)
    }

    private func cumulativeQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from startDate: Date) async throws -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            healthStore.execute(query)
        }
    }

    private func dailyCumulativeQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from startDate: Date, to endDate: Date) async throws -> [HealthTrendPoint] {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [] }
        return try await dailyStatistics(type: type, unit: unit, option: .cumulativeSum, from: startDate, to: endDate)
    }

    private func dailyAverageQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from startDate: Date, to endDate: Date) async throws -> [HealthTrendPoint] {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [] }
        return try await dailyStatistics(type: type, unit: unit, option: .discreteAverage, from: startDate, to: endDate)
    }

    private func dailyStatistics(type: HKQuantityType, unit: HKUnit, option: HKStatisticsOptions, from startDate: Date, to endDate: Date) async throws -> [HealthTrendPoint] {
        let calendar = Calendar.current
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        var interval = DateComponents()
        interval.day = 1

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: option,
                anchorDate: startDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                var points: [HealthTrendPoint] = []
                collection?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let quantity = option == .cumulativeSum ? statistics.sumQuantity() : statistics.averageQuantity()
                    let day = calendar.startOfDay(for: statistics.startDate)
                    points.append(HealthTrendPoint(date: day, value: quantity?.doubleValue(for: unit) ?? 0))
                }

                continuation.resume(returning: points)
            }

            healthStore.execute(query)
        }
    }

    private func dailySleepHours(from startDate: Date, to endDate: Date) async throws -> [HealthTrendPoint] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let calendar = Calendar.current
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let sleepSamples = (samples as? [HKCategorySample]) ?? []
                let asleepValues = Set([
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ])

                var points: [HealthTrendPoint] = []
                var day = startDate

                while day < endDate {
                    let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? endDate
                    let seconds = sleepSamples.reduce(0.0) { total, sample in
                        guard asleepValues.contains(sample.value) else { return total }
                        let overlapStart = max(sample.startDate, day)
                        let overlapEnd = min(sample.endDate, nextDay)
                        return overlapEnd > overlapStart ? total + overlapEnd.timeIntervalSince(overlapStart) : total
                    }

                    points.append(HealthTrendPoint(date: day, value: seconds / 3_600))
                    day = nextDay
                }

                continuation.resume(returning: points)
            }

            healthStore.execute(query)
        }
    }

    private func mostRecentQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return 0 }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictEndDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let sample = samples?.first as? HKQuantitySample
                continuation.resume(returning: sample?.quantity.doubleValue(for: unit) ?? 0)
            }
            healthStore.execute(query)
        }
    }

    private func sleepHoursSinceYesterday() async throws -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let startDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let sleepSeconds = (samples as? [HKCategorySample])?.reduce(0.0) { total, sample in
                    guard sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue else {
                        return total
                    }

                    return total + sample.endDate.timeIntervalSince(sample.startDate)
                } ?? 0

                continuation.resume(returning: sleepSeconds / 3_600)
            }
            healthStore.execute(query)
        }
    }

    private func safeValue(_ operation: @escaping () async throws -> Double) async -> Double {
        do {
            return try await operation()
        } catch {
            return 0
        }
    }

    private func hasAnyData(in snapshot: HealthSnapshot) -> Bool {
        snapshot.steps > 0 ||
        snapshot.activeEnergy > 0 ||
        snapshot.exerciseMinutes > 0 ||
        snapshot.distanceKilometers > 0 ||
        snapshot.restingHeartRate > 0 ||
        snapshot.sleepHours > 0
    }

    private func friendlyErrorMessage(for error: Error) -> String {
        let nsError = error as NSError

        if nsError.domain == HKErrorDomain {
            return "Health-Daten konnten nicht vollstaendig geladen werden (\(nsError.code)). Bitte pruefe in Apple Health die Leserechte fuer Health Advisor und stelle sicher, dass das iPhone entsperrt ist."
        }

        return nsError.localizedDescription
    }
}

private extension HKHealthStore {
    func getRequestStatusForAuthorization(toShare shareTypes: Set<HKSampleType>, read readTypes: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus {
        try await withCheckedThrowingContinuation { continuation in
            getRequestStatusForAuthorization(toShare: shareTypes, read: readTypes) { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }
}
