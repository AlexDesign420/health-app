import SwiftUI
import Charts

struct ContentView: View {
    @EnvironmentObject private var healthManager: HealthManager

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.canvasTop, Color.canvasBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        heroCard
                        if shouldShowAccessCard {
                            accessCard
                        }
                        metricsSection
                        insightsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Health Advisor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await healthManager.loadHealthData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.14))
                            )
                    }
                    .disabled(healthManager.isLoading)
                }
            }
            .task {
                await healthManager.refreshAuthorizationState()

                if healthManager.snapshot.updatedAt == nil {
                    await healthManager.requestAuthorizationAndLoad()
                }
            }
            .navigationDestination(for: HealthMetric.Kind.self) { kind in
                if let metric = healthManager.snapshot.metrics.first(where: { $0.kind == kind }) {
                    MetricDetailView(metric: metric)
                        .environmentObject(healthManager)
                }
            }
        }
    }

    private var shouldShowAccessCard: Bool {
        healthManager.authorizationState != .connected || healthManager.errorMessage != nil
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(greetingTitle)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(heroSubtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.78))
                }

                Spacer(minLength: 16)

                statusBadge
            }

            HStack(spacing: 12) {
                quickStat(
                    title: "Schritte",
                    value: NumberFormatter.wholeNumber.string(from: NSNumber(value: healthManager.snapshot.steps)) ?? "0",
                    detail: "Heute"
                )

                quickStat(
                    title: "Aktiv",
                    value: "\(Int(healthManager.snapshot.exerciseMinutes.rounded())) min",
                    detail: "Training"
                )

                quickStat(
                    title: "Schlaf",
                    value: healthManager.snapshot.sleepHours > 0 ? healthManager.snapshot.sleepHours.formatted(.number.precision(.fractionLength(1))) + " h" : "--",
                    detail: "Letzte Nacht"
                )
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.heroStart, Color.heroMiddle, Color.heroAccent, Color.heroEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 140, height: 140)
                .offset(x: 28, y: -46)
        }
        .overlay(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        }
    }

    private var accessCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentTeal.opacity(0.16))
                        .frame(width: 46, height: 46)

                    Image(systemName: "heart.text.square.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentTeal)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Health-Zugriff")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text(healthManager.authorizationStatus)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                if healthManager.isLoading {
                    ProgressView()
                        .tint(Color.heroStart)
                }
            }

            Text(healthManager.authorizationDescription)
                .font(.callout)
                .foregroundStyle(Color.textSecondary)

            if let message = healthManager.errorMessage {
                Text(message)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.errorText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.errorFill)
                    )
            }

            Button {
                Task { await healthManager.requestAuthorizationAndLoad() }
            } label: {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                    Text("Health-Daten verbinden")
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.footnote.weight(.bold))
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.heroStart, Color.heroMiddle],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
        }
        .padding(22)
        .surfaceCard()
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Dein Tagesbild", subtitle: "Alle wichtigen Gesundheitswerte auf einen Blick.")

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(healthManager.snapshot.metrics) { metric in
                    NavigationLink(value: metric.kind) {
                        MetricCard(metric: metric)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Persoenliche Hinweise", subtitle: "Einfach erklaerte Trends aus deinen aktuellen Daten.")

            ForEach(healthManager.insights) { insight in
                InsightRow(insight: insight)
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(healthManager.authorizationStatus)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.14), in: Capsule())
    }

    private var statusColor: Color {
        switch healthManager.authorizationState {
        case .connected: Color.success
        case .requested: Color.warning
        case .needsRequest, .unknown: Color.white
        case .unavailable: Color.errorText
        }
    }

    private var greetingTitle: String {
        let hour = Calendar.current.component(.hour, from: Date())

        return switch hour {
        case 5..<12: "Guten Morgen"
        case 12..<18: "Guten Tag"
        default: "Guten Abend"
        }
    }

    private var heroSubtitle: String {
        if let updatedAt = healthManager.snapshot.updatedAt {
            return "Letztes Update: \(updatedAt.formatted(date: .abbreviated, time: .shortened))"
        }

        return "Verbinde Apple Health, damit dein Dashboard live mit deinen Tagesdaten arbeitet."
    }

    private func quickStat(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.65))

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(detail)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.textPrimary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MetricCard: View {
    let metric: HealthMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 44, height: 44)

                    Image(systemName: metric.iconName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(tint)
                }

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint.opacity(0.72))

                if metric.progress != nil {
                    Text(metric.progressLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(metric.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.textSecondary)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(metric.formattedValue)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)

                    Text(metric.unit)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.textSecondary)
                }
            }

            if let progress = metric.progress {
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.trackFill)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [tint.opacity(0.75), tint],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(12, proxy.size.width * progress))
                        }
                    }
                    .frame(height: 8)

                    Text(progress >= 1 ? "Ziel erreicht" : "Du bist gut unterwegs")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.textSecondary)
                }
            } else {
                Text("Aktueller Messwert")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.20), Color.surface, Color.white.opacity(0.96)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(tint.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.12), radius: 18, x: 0, y: 10)
    }

    private var tint: Color {
        Color.metricTint(for: metric.kind)
    }
}

struct InsightRow: View {
    let insight: HealthInsight

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 44, height: 44)

                Image(systemName: iconName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(insight.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)

                Text(insight.message)
                    .font(.callout)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .surfaceCard()
    }

    private var iconName: String {
        switch insight.tone {
        case .positive: "sparkles"
        case .neutral: "text.bubble.fill"
        case .warning: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch insight.tone {
        case .positive: Color.success
        case .neutral: Color.accentBlue
        case .warning: Color.warning
        }
    }
}

struct MetricDetailView: View {
    @EnvironmentObject private var healthManager: HealthManager

    let metric: HealthMetric

    @State private var points: [HealthTrendPoint] = []
    @State private var isLoading = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.canvasTop, Color.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    detailHero
                    chartPanel
                    summaryGrid
                    analysisPanel
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(metric.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await loadTrend() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(tint)
                }
                .disabled(isLoading)
            }
        }
        .task(id: metric.kind) {
            await loadTrend()
        }
    }

    private var detailHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 58, height: 58)

                    Image(systemName: metric.iconName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text("14 Tage")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.18), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(metric.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(metric.formattedValue)
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(metric.unit)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.78))
                }

                Text(metricContext)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.82))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.78), secondaryTint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var chartPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Verlauf")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.textPrimary)

                    Text("Die letzten 14 Tage aus Apple Health.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(tint)
                }
            }

            Chart {
                ForEach(points) { point in
                    if metric.kind == .restingHeartRate {
                        LineMark(
                            x: .value("Tag", point.date, unit: .day),
                            y: .value(metric.title, point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(tint)

                        PointMark(
                            x: .value("Tag", point.date, unit: .day),
                            y: .value(metric.title, point.value)
                        )
                        .foregroundStyle(tint)
                    } else {
                        BarMark(
                            x: .value("Tag", point.date, unit: .day),
                            y: .value(metric.title, point.value)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [tint.opacity(0.78), tint, secondaryTint.opacity(0.9)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                    }
                }
            }
            .frame(height: 260)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }

            if points.isEmpty || points.allSatisfy({ $0.value == 0 }) {
                Text("Noch keine Verlaufdaten fuer diesen Wert gefunden.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .surfaceCard()
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            DetailStatTile(title: "Durchschnitt", value: formatted(averageValue), tint: tint)
            DetailStatTile(title: "Bester Tag", value: formatted(bestValue), tint: secondaryTint)
            DetailStatTile(title: "Heute", value: metric.formattedValue, tint: Color.accentTeal)
            DetailStatTile(title: "Trend", value: trendLabel, tint: trendTint)
        }
    }

    private var analysisPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)

                Text("Analyse")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
            }

            Text(analysisText)
                .font(.callout)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .surfaceCard()
    }

    private var averageValue: Double {
        let values = points.map(\.value)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private var bestValue: Double {
        points.map(\.value).max() ?? 0
    }

    private var trendDelta: Double {
        guard let first = points.first?.value, let last = points.last?.value else { return 0 }
        return last - first
    }

    private var trendLabel: String {
        let delta = trendDelta
        guard abs(delta) >= 0.1 else { return "Stabil" }
        return delta > 0 ? "+\(formatted(abs(delta)))" : "-\(formatted(abs(delta)))"
    }

    private var trendTint: Color {
        guard abs(trendDelta) >= 0.1 else { return Color.textSecondary }

        if metric.kind == .restingHeartRate {
            return trendDelta > 0 ? Color.warning : Color.success
        }

        return trendDelta > 0 ? Color.success : Color.warning
    }

    private var metricContext: String {
        switch metric.kind {
        case .steps: "Bewegung und Alltagsaktivitaet."
        case .activeEnergy: "Energieverbrauch durch Aktivitaet."
        case .exercise: "Trainingsminuten und aktive Zeit."
        case .distance: "Geh- und Laufdistanz im Alltag."
        case .restingHeartRate: "Ruhepuls als Belastungs- und Erholungsindikator."
        case .sleep: "Schlafdauer und Erholung ueber Nacht."
        }
    }

    private var analysisText: String {
        let average = formatted(averageValue)
        let best = formatted(bestValue)

        switch metric.kind {
        case .steps:
            return "Du liegst im 14-Tage-Schnitt bei \(average) Schritten. Dein staerkster Tag lag bei \(best). Wenn der Trend steigt, baut sich dein Bewegungsniveau stabil auf."
        case .activeEnergy:
            return "Deine aktive Energie liegt im Schnitt bei \(average) kcal. Der beste Tag kam auf \(best) kcal. Achte darauf, ob hohe Tage mit Training oder laengeren Wegen zusammenfallen."
        case .exercise:
            return "Du sammelst durchschnittlich \(average) aktive Minuten. Der Spitzenwert liegt bei \(best). Fuer eine gute Wochenbasis helfen mehrere moderate Tage mehr als ein einzelner sehr harter Tag."
        case .distance:
            return "Deine Distanz liegt im Mittel bei \(average) km. Der hoechste Wert war \(best) km. Das zeigt gut, wie viel Bewegung wirklich im Alltag landet."
        case .restingHeartRate:
            return "Dein durchschnittlicher Ruhepuls liegt bei \(average) bpm. Niedrigere oder stabile Werte sprechen oft fuer Erholung; ein deutlicher Anstieg kann durch Stress, Schlafmangel oder Belastung entstehen."
        case .sleep:
            return "Du schlaefst im Schnitt \(average) Stunden, mit einem besten Wert von \(best). Regelmaessigkeit ist hier fast genauso wichtig wie die einzelne Schlafdauer."
        }
    }

    private var tint: Color {
        Color.metricTint(for: metric.kind)
    }

    private var secondaryTint: Color {
        switch metric.kind {
        case .steps: Color.accentTeal
        case .activeEnergy: Color.accentGold
        case .exercise: Color.accentBlue
        case .distance: Color.accentOrange
        case .restingHeartRate: Color.accentGold
        case .sleep: Color.accentIndigo
        }
    }

    private func loadTrend() async {
        isLoading = true
        points = await healthManager.trend(for: metric.kind)
        isLoading = false
    }

    private func formatted(_ value: Double) -> String {
        switch metric.kind {
        case .steps:
            return NumberFormatter.wholeNumber.string(from: NSNumber(value: value)) ?? "\(Int(value.rounded()))"
        case .activeEnergy, .restingHeartRate:
            return "\(Int(value.rounded()))"
        case .exercise, .sleep:
            return value.formatted(.number.precision(.fractionLength(1)))
        case .distance:
            return value.formatted(.number.precision(.fractionLength(2)))
        }
    }
}

struct DetailStatTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.textSecondary)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.18), Color.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private extension View {
    func surfaceCard() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}

private extension Color {
    static let canvasTop = Color(red: 0.97, green: 0.98, blue: 0.95)
    static let canvasBottom = Color(red: 0.88, green: 0.95, blue: 0.98)
    static let surface = Color.white.opacity(0.92)
    static let border = Color.white.opacity(0.55)
    static let textPrimary = Color(red: 0.10, green: 0.13, blue: 0.19)
    static let textSecondary = Color(red: 0.38, green: 0.44, blue: 0.54)
    static let heroStart = Color(red: 0.02, green: 0.40, blue: 0.62)
    static let heroMiddle = Color(red: 0.00, green: 0.64, blue: 0.62)
    static let heroAccent = Color(red: 0.20, green: 0.66, blue: 0.91)
    static let heroEnd = Color(red: 1.00, green: 0.58, blue: 0.22)
    static let accentBlue = Color(red: 0.08, green: 0.39, blue: 0.88)
    static let accentTeal = Color(red: 0.00, green: 0.68, blue: 0.62)
    static let accentOrange = Color(red: 0.96, green: 0.38, blue: 0.16)
    static let accentIndigo = Color(red: 0.26, green: 0.27, blue: 0.76)
    static let accentRose = Color(red: 0.88, green: 0.18, blue: 0.38)
    static let accentGold = Color(red: 0.95, green: 0.66, blue: 0.16)
    static let success = Color(red: 0.20, green: 0.69, blue: 0.44)
    static let warning = Color(red: 0.89, green: 0.55, blue: 0.13)
    static let errorFill = Color(red: 0.98, green: 0.91, blue: 0.91)
    static let errorText = Color(red: 0.78, green: 0.23, blue: 0.27)
    static let trackFill = Color(red: 0.90, green: 0.92, blue: 0.95)

    static func metricTint(for kind: HealthMetric.Kind) -> Color {
        switch kind {
        case .steps: Color.accentBlue
        case .activeEnergy: Color.accentOrange
        case .exercise: Color.accentTeal
        case .distance: Color.accentIndigo
        case .restingHeartRate: Color.accentRose
        case .sleep: Color.accentGold
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthManager())
}
