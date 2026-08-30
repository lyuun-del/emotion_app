import SwiftUI
import WatchKit
import Charts

struct WatchHomeView: View {
    @EnvironmentObject private var healthStore: WatchHealthStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var page: WatchPage = .island
    @State private var navigationPath: [WatchMetric] = []
    @State private var detailTopBarBottom: CGFloat = 0
    @State private var detailFooterClearance: CGFloat = 0

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                switch page {
                case .island:
                    islandHome
                        .transition(.move(edge: .top).combined(with: .opacity))
                case .dashboard:
                    healthDashboard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationDestination(for: WatchMetric.self) { metric in
                metricDetail(metric)
            }
        }
        .task {
            await healthStore.requestAccessAndRefresh()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await healthStore.refreshIfNeeded()
            }
        }
    }

    private var islandHome: some View {
        GeometryReader { geometry in
            ZStack {
                Image("WatchIsland")
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
                    )
                    .position(
                        x: geometry.size.width / 2,
                        y: (geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom) / 2 - geometry.safeAreaInsets.top
                    )
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        .black.opacity(0.02),
                        .black.opacity(0.02),
                        .black.opacity(0.18),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

            }
            .contentShape(Rectangle())
            .onTapGesture {
                openDashboard()
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("打开健康数据")
        }
        .ignoresSafeArea()
    }

    private var healthDashboard: some View {
        GeometryReader { geometry in
            ZStack {
                blurredIslandBackground

                ScrollView(.vertical) {
                    VStack(spacing: 12) {
                        VStack(spacing: 8) {
                            Button {
                                closeDashboard()
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "chevron.compact.down")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("返回岛屿")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(.white.opacity(0.94))
                                .padding(.horizontal, 15)
                                .frame(height: 30)
                            }
                            .buttonStyle(.plain)
                            .liquidGlassBackground(
                                Capsule(style: .continuous),
                                tint: .white.opacity(0.12)
                            )
                            .accessibilityLabel("返回岛屿主页")

                            Text("MoodLand")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .shadow(color: .black.opacity(0.24), radius: 8, y: 3)
                        }
                        .padding(.horizontal, 8)

                        Button {
                            openMetric(.stress)
                        } label: {
                            pressureCircle
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("查看压力趋势图表")

                        HStack(spacing: 10) {
                            Button {
                                openMetric(.heartRate)
                            } label: {
                                metricCard(
                                    title: "心率",
                                    value: healthStore.heartRate.map { "\(Int($0.rounded()))" } ?? "--",
                                    unit: "次/分",
                                    tint: .red
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                openMetric(.hrv)
                            } label: {
                                metricCard(
                                    title: "HRV",
                                    value: healthStore.hrv.map { "\(Int($0.rounded()))" } ?? "--",
                                    unit: "ms",
                                    tint: .mint
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: 10) {
                            Button {
                                openMetric(.sleep)
                            } label: {
                                metricCard(
                                    title: "睡眠",
                                    value: healthStore.sleepMinutes.map {
                                        String(format: "%.1f", $0 / 60)
                                    } ?? "--",
                                    unit: "小时",
                                    tint: WatchMetric.sleep.tint
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                openMetric(.steps)
                            } label: {
                                metricCard(
                                    title: "步数",
                                    value: healthStore.steps.map { "\(Int($0.rounded()))" } ?? "--",
                                    unit: "步",
                                    tint: WatchMetric.steps.tint
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Toggle(
                            isOn: Binding(
                                get: { healthStore.isMockDataEnabled },
                                set: { enabled in
                                    Task {
                                        await healthStore.setMockDataEnabled(enabled)
                                    }
                                }
                            )
                        ) {
                            Label("使用测试数据", systemImage: "testtube.2")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .tint(.yellow)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 48)
                        .liquidGlassBackground(
                            RoundedRectangle(cornerRadius: 22, style: .continuous),
                            tint: healthStore.isMockDataEnabled
                                ? .yellow.opacity(0.14)
                                : .white.opacity(0.08)
                        )
                        .accessibilityHint("开启后在手表和手机之间同步跨设备测试数据")

                        Button {
                            Task { await healthStore.refresh() }
                        } label: {
                            Label(
                                healthStore.isLoading ? "同步中" : "同步数据",
                                systemImage: healthStore.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise"
                            )
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .liquidGlassButtonTint()
                        .foregroundStyle(.white)
                        .disabled(healthStore.isLoading)

                        statusCard

                        dataHintCard

                        Color.clear.frame(height: max(54, geometry.size.height * 0.18))
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .contentMargins(.vertical, 0, for: .scrollContent)
                .defaultScrollAnchor(.top)
            }
        }
    }

    private func metricDetail(_ metric: WatchMetric) -> some View {
        GeometryReader { geometry in
            ZStack {
                blurredIslandBackground

                ScrollView(.vertical) {
                    VStack(spacing: 12) {
                        Text(metric.title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)

                        HStack(spacing: 8) {
                            metricSummaryCard(
                                title: metric.primarySummaryTitle,
                                value: metricAverage(metric),
                                metric: metric
                            )
                            metricSummaryCard(
                                title: metric.secondarySummaryTitle,
                                value: metricBaseline(metric),
                                metric: metric
                            )
                        }

                        metricChart(metric)

                        Button {
                            Task { await healthStore.refresh() }
                        } label: {
                            Label(
                                healthStore.isLoading ? "同步中" : "同步数据",
                                systemImage: "arrow.clockwise"
                            )
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .liquidGlassButtonTint()
                        .foregroundStyle(.white)
                        .disabled(healthStore.isLoading)
                        .background {
                            GeometryReader { buttonGeometry in
                                Color.clear
                                    .onAppear {
                                        if detailFooterClearance == 0 {
                                            detailFooterClearance = buttonGeometry.size.height
                                        }
                                    }
                            }
                        }

                        Color.clear.frame(
                            height: detailFooterClearance
                                + max(geometry.safeAreaInsets.bottom, detailFooterClearance)
                        )

                    }
                    .padding(.horizontal, 10)
                }
                .contentMargins(
                    .top,
                    max(0, detailTopBarBottom - geometry.frame(in: .global).minY),
                    for: .scrollContent
                )
                .defaultScrollAnchor(.top)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: closeMetric) {
                    Image(systemName: "chevron.left")
                }
                .background {
                    GeometryReader { toolbarGeometry in
                        Color.clear
                            .onAppear {
                                if detailTopBarBottom == 0 {
                                    detailTopBarBottom = toolbarGeometry.frame(in: .global).maxY
                                }
                            }
                    }
                }
                .accessibilityLabel("返回健康数据")
            }
        }
    }

    @ViewBuilder
    private func metricChart(_ metric: WatchMetric) -> some View {
        let samples = metricSamples(metric)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(metric.chartTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                Spacer()
                Text("\(samples.count) 条")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
            }

            if samples.isEmpty {
                VStack(spacing: 7) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 24, weight: .medium))
                    Text(metric.isWeekly ? "近 7 日暂无数据" : "近 24 小时暂无数据")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.58))
                .frame(maxWidth: .infinity, minHeight: 132)
            } else {
                Chart(samples) { sample in
                    LineMark(
                        x: .value("时间", sample.date),
                        y: .value(metric.title, sample.value)
                    )
                    .interpolationMethod(.linear)
                    .lineStyle(
                        StrokeStyle(
                            lineWidth: 1.5,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .foregroundStyle(metric.tint)
                }
                .chartXScale(domain: metric.isWeekly ? chartWeekRange : chartDayRange)
                .chartYScale(domain: metric == .stress ? 0...100 : chartYDomain(samples))
                .chartXAxis {
                    if metric.isWeekly {
                        AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                            AxisGridLine().foregroundStyle(.white.opacity(0.10))
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.58))
                        }
                    } else {
                        AxisMarks(values: chartDayAxisValues) { _ in
                            AxisGridLine().foregroundStyle(.white.opacity(0.10))
                            AxisValueLabel(format: .dateTime.hour().minute())
                                .font(.system(size: 7))
                                .foregroundStyle(.white.opacity(0.58))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                        AxisGridLine().foregroundStyle(.white.opacity(0.12))
                        AxisValueLabel()
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }
                .frame(height: 158)
            }
        }
        .padding(12)
        .liquidGlassBackground(
            RoundedRectangle(cornerRadius: 24, style: .continuous),
            tint: metric.tint.opacity(0.10)
        )
    }

    private func metricSummaryCard(
        title: String,
        value: Double?,
        metric: WatchMetric
    ) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(metric.formatted(value))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(metric.unit)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(metric.tint.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .liquidGlassBackground(
            RoundedRectangle(cornerRadius: 22, style: .continuous),
            tint: metric.tint.opacity(0.11)
        )
    }

    private var blurredIslandBackground: some View {
        ZStack {
            Color(red: 0.36, green: 0.52, blue: 0.51)
                .ignoresSafeArea()

            Image("WatchIsland")
                .resizable()
                .scaledToFill()
                .blur(radius: 24)
                .saturation(0.74)
                .brightness(-0.14)
                .scaleEffect(1.16)
                .ignoresSafeArea()

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.52)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .black.opacity(0.04),
                    .black.opacity(0.18),
                    .black.opacity(0.34),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var pressureCircle: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.10, green: 0.27, blue: 0.28).opacity(0.72))

            Circle()
                .stroke(.white.opacity(0.20), lineWidth: 14)
                .padding(15)

            Circle()
                .stroke(.cyan.opacity(0.52), lineWidth: 2)

            Circle()
                .trim(from: 0, to: max(0.02, CGFloat(healthStore.stress ?? 0) / 100))
                .stroke(
                    pressureColor,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(8)

            VStack(spacing: 8) {
                Text(healthStore.stress.map { "\(Int($0.rounded()))" } ?? "--")
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                Text("压力值")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .frame(width: 162, height: 162)
        .shadow(color: .cyan.opacity(0.18), radius: 10, y: 3)
    }

    private func metricCard(title: String, value: String, unit: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))

            Text(value)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.68)

            Text(unit)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.60))
        }
        .frame(maxWidth: .infinity, minHeight: 108)
        .liquidGlassBackground(
            RoundedRectangle(cornerRadius: 28, style: .continuous),
            tint: tint.opacity(0.14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(tint.opacity(0.55), lineWidth: 1.2)
        }
    }

    private var statusCard: some View {
        HStack(spacing: 9) {
            Image(systemName: healthStore.statusIcon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.12), in: Circle())

            Text(healthStore.status)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .liquidGlassBackground(
            RoundedRectangle(cornerRadius: 24, style: .continuous),
            tint: .white.opacity(0.10)
        )
    }

    private var dataHintCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("数据浏览")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("上下滑动查看压力、心率、HRV、睡眠、步数与同步状态。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassBackground(
            RoundedRectangle(cornerRadius: 24, style: .continuous),
            tint: .cyan.opacity(0.10)
        )
    }

    private var pressureColor: Color {
        guard let stress = healthStore.stress else { return .white.opacity(0.62) }
        switch stress {
        case ..<35: return .green
        case ..<55: return .yellow
        case ..<75: return .orange
        default: return .red
        }
    }

    private var chartDayRange: ClosedRange<Date> {
        let end = Date()
        let start = end.addingTimeInterval(-24 * 60 * 60)
        return start...end
    }

    private var chartDayAxisValues: [Date] {
        let range = chartDayRange
        return [0, 6, 12, 18, 24].map { hour in
            range.lowerBound.addingTimeInterval(TimeInterval(hour * 60 * 60))
        }
    }

    private var chartWeekRange: ClosedRange<Date> {
        let today = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.date(byAdding: .day, value: -6, to: today) ?? today
        let end = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        return start...end
    }

    private func metricSamples(_ metric: WatchMetric) -> [WatchHealthSample] {
        let rollingRange = chartDayRange
        switch metric {
        case .heartRate:
            return rollingDaySamples(healthStore.heartRateSamples, in: rollingRange)
        case .hrv:
            return rollingDaySamples(healthStore.hrvSamples, in: rollingRange)
        case .sleep:
            return dailyTotalSamples(healthStore.sleepSamples, divisor: 60)
        case .steps:
            return dailyTotalSamples(healthStore.stepSamples)
        case .stress:
            return rollingDaySamples(healthStore.stressSamples, in: rollingRange)
        }
    }

    private func rollingDaySamples(
        _ samples: [WatchHealthSample],
        in range: ClosedRange<Date>
    ) -> [WatchHealthSample] {
        samples
            .filter { $0.date >= range.lowerBound && $0.date <= range.upperBound }
            .sorted { $0.date < $1.date }
    }

    private func dailyTotalSamples(
        _ samples: [WatchHealthSample],
        divisor: Double = 1
    ) -> [WatchHealthSample] {
        let calendar = Calendar.current
        var totalsByDay: [Date: Double] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.date)
            totalsByDay[day, default: 0] += sample.value / divisor
        }
        return totalsByDay.map { day, total in
            WatchHealthSample(date: weeklyDisplayDate(day), value: total)
        }
        .sorted { $0.date < $1.date }
    }

    private func weeklyDisplayDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .hour, value: 12, to: day) ?? date
    }

    private func metricCurrentValue(_ metric: WatchMetric) -> String {
        let value: Double?
        switch metric {
        case .heartRate: value = healthStore.heartRate
        case .hrv: value = healthStore.hrv
        case .sleep: value = healthStore.sleepMinutes.map { $0 / 60 }
        case .steps: value = healthStore.steps
        case .stress: value = healthStore.stress
        }
        return metric.formatted(value)
    }

    private func metricAverage(_ metric: WatchMetric) -> Double? {
        if metric == .stress || metric == .sleep || metric == .steps {
            if metric == .sleep {
                return healthStore.sleepMinutes.map { $0 / 60 }
            }
            if metric == .steps {
                return healthStore.steps
            }
            return healthStore.stress
        }
        let samples = metricSamples(metric)
        guard !samples.isEmpty else { return nil }
        return samples.map(\.value).reduce(0, +) / Double(samples.count)
    }

    private func metricBaseline(_ metric: WatchMetric) -> Double? {
        switch metric {
        case .heartRate: return healthStore.heartRateBaselineAverage
        case .hrv: return healthStore.hrvBaselineAverage
        case .sleep, .steps:
            let samples = metricSamples(metric)
            guard !samples.isEmpty else { return nil }
            return samples.map(\.value).reduce(0, +) / Double(samples.count)
        case .stress:
            let samples = healthStore.stressSamples
            guard !samples.isEmpty else { return nil }
            return samples.map(\.value).reduce(0, +) / Double(samples.count)
        }
    }

    private func stressColor(_ value: Double) -> Color {
        switch value {
        case ..<35: return .mint
        case ..<55: return .yellow
        case ..<75: return .orange
        default: return .pink
        }
    }

    private func chartYDomain(_ samples: [WatchHealthSample]) -> ClosedRange<Double> {
        guard
            let minimum = samples.map(\.value).min(),
            let maximum = samples.map(\.value).max()
        else {
            return 0...100
        }
        let padding = max((maximum - minimum) * 0.18, 5)
        return max(0, minimum - padding)...(maximum + padding)
    }

    private func openDashboard() {
        WKInterfaceDevice.current().play(.click)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
            page = .dashboard
        }
    }

    private func closeDashboard() {
        WKInterfaceDevice.current().play(.click)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
            page = .island
        }
    }

    private func openMetric(_ metric: WatchMetric) {
        WKInterfaceDevice.current().play(.click)
        navigationPath.append(metric)
    }

    private func closeMetric() {
        WKInterfaceDevice.current().play(.click)
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

}

private enum WatchPage {
    case island
    case dashboard
}

private enum WatchMetric: Hashable {
    case heartRate
    case hrv
    case sleep
    case steps
    case stress

    var title: String {
        switch self {
        case .heartRate: return "心率"
        case .hrv: return "HRV"
        case .sleep: return "睡眠"
        case .steps: return "步数"
        case .stress: return "实时压力"
        }
    }

    var unit: String {
        switch self {
        case .heartRate: return "次/分"
        case .hrv: return "ms"
        case .sleep: return "小时"
        case .steps: return "步"
        case .stress: return "%"
        }
    }

    var tint: Color {
        switch self {
        case .heartRate: return .red
        case .hrv: return .mint
        case .sleep: return Color(red: 89.0 / 255, green: 123.0 / 255, blue: 199.0 / 255)
        case .steps: return Color(red: 209.0 / 255, green: 154.0 / 255, blue: 53.0 / 255)
        case .stress: return .pink
        }
    }

    var isWeekly: Bool {
        self == .sleep || self == .steps
    }

    var primarySummaryTitle: String {
        switch self {
        case .stress: return "实时压力"
        case .sleep, .steps: return "最近记录"
        case .heartRate, .hrv: return "今日平均"
        }
    }

    var secondarySummaryTitle: String {
        switch self {
        case .stress: return "今日平均"
        case .sleep, .steps: return "近 7 日平均"
        case .heartRate, .hrv: return "近 30 日平均"
        }
    }

    var chartTitle: String {
        if self == .stress { return "近 24 小时压力趋势" }
        return isWeekly ? "近 7 日\(title)趋势" : "近 24 小时\(title)趋势"
    }

    func formatted(_ value: Double?) -> String {
        guard let value else { return "--" }
        if self == .sleep {
            return String(format: "%.1f", value)
        }
        return "\(Int(value.rounded()))"
    }
}

private extension View {
    @ViewBuilder
    func liquidGlassBackground<S: Shape>(_ shape: S, tint: Color) -> some View {
        if #available(watchOS 26.0, *) {
            self
                .glassEffect(.regular.tint(tint), in: shape)
                .background(.white.opacity(0.08), in: shape)
        } else {
            self
                .background(.ultraThinMaterial.opacity(0.78), in: shape)
                .overlay {
                    shape.stroke(.white.opacity(0.22), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    func liquidGlassButtonTint() -> some View {
        if #available(watchOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.tint(.cyan)
        }
    }
}
