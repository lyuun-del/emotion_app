import Foundation
import HealthKit
import WatchConnectivity

struct WatchHealthSample: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

@MainActor
final class WatchHealthStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var heartRate: Double?
    @Published private(set) var hrv: Double?
    @Published private(set) var sleepMinutes: Double?
    @Published private(set) var steps: Double?
    @Published private(set) var heartRateSamples: [WatchHealthSample] = []
    @Published private(set) var hrvSamples: [WatchHealthSample] = []
    @Published private(set) var sleepSamples: [WatchHealthSample] = []
    @Published private(set) var stepSamples: [WatchHealthSample] = []
    @Published private(set) var stressSamples: [WatchHealthSample] = []
    @Published private(set) var stress: Double?
    @Published private(set) var status = "准备读取健康数据"
    @Published private(set) var statusIcon = "heart.text.square"
    @Published private(set) var isLoading = false
    @Published private(set) var isMockDataEnabled = false
    @Published private(set) var heartRateBaselineAverage: Double?
    @Published private(set) var hrvBaselineAverage: Double?
    @Published private(set) var stressConfidence = 0
    @Published private(set) var isActivityFiltered = false
    @Published private(set) var stressDataMode = "noHrv"

    private let store = HKHealthStore()
    private let cacheKey = "moodland.watch.health.snapshot.v2"
    private let phonePayloadCacheKey = "moodland.watch.phone.payload.v2"
    private let mockDataEnabledKey = "moodland.watch.mock.enabled"
    private let phoneOverrideDelay: TimeInterval = 5 * 60
    private let defaultHrvBaseline = 50.0
    private let requiredHrvBaselineSampleCount = 20

    private var watchHeartRate: Double?
    private var watchHrv: Double?
    private var watchSleepMinutes: Double?
    private var watchSteps: Double?
    private var watchHeartRateDate: Date?
    private var watchHrvDate: Date?
    private var watchSleepDate: Date?
    private var watchStepsDate: Date?
    private var heartRateBaseline: Double?
    private var hrvBaseline: Double?
    private var hrvBaselineSampleCount = 0
    private var restingHeartRateHistory: [WatchHealthSample] = []
    private var baselineSleepHistory: [WatchHealthSample] = []
    private var rawStepSamples: [WatchHealthSample] = []
    private var syncedPhonePayload: [String: Any]?
    private var lastAutomaticRefreshAt: Date?

    override init() {
        super.init()
        isMockDataEnabled = UserDefaults.standard.bool(forKey: mockDataEnabledKey)
        restoreCachedData()
        activateWatchConnectivity()
    }

    func requestAccessAndRefresh() async {
        if isMockDataEnabled {
            applyMockDataAndSync()
            return
        }
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "此设备不支持健康数据"
            statusIcon = "exclamationmark.triangle"
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.stepCount),
            HKCategoryType(.sleepAnalysis),
        ]

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            await refresh()
        } catch {
            status = "请在健康 App 中允许访问"
            statusIcon = "lock"
        }
    }

    func refreshIfNeeded(minimumInterval: TimeInterval = 60) async {
        if let lastAutomaticRefreshAt,
           Date().timeIntervalSince(lastAutomaticRefreshAt) < minimumInterval {
            return
        }
        lastAutomaticRefreshAt = Date()
        await requestAccessAndRefresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        lastAutomaticRefreshAt = Date()
        defer { isLoading = false }

        if isMockDataEnabled {
            applyMockDataAndSync()
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let rollingDayStart = now.addingTimeInterval(-24 * 60 * 60)
        let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: startOfDay) ?? startOfDay
        let sleepQueryStart = Calendar.current.date(byAdding: .day, value: -1, to: weekStart) ?? weekStart
        let baselineStart = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
        let baselineSleepStart = Calendar.current.date(byAdding: .day, value: -1, to: baselineStart) ?? baselineStart
        let heartRateType = HKQuantityType(.heartRate)
        let restingHeartRateType = HKQuantityType(.restingHeartRate)
        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
        let stepType = HKQuantityType(.stepCount)
        let sleepType = HKCategoryType(.sleepAnalysis)

        async let latestHeartRate = latestSample(
            for: heartRateType,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
        async let latestHrv = latestSample(for: hrvType, unit: .secondUnit(with: .milli))
        async let restingSamples = sampleValues(
            for: restingHeartRateType,
            unit: HKUnit.count().unitDivided(by: .minute()),
            from: baselineStart,
            to: now
        )
        async let hrvBaselineSamples = sampleValues(
            for: hrvType,
            unit: .secondUnit(with: .milli),
            from: baselineStart,
            to: now
        )
        async let baselineHeartRateSamples = sampleValues(
            for: heartRateType,
            unit: HKUnit.count().unitDivided(by: .minute()),
            from: baselineStart,
            to: now
        )
        async let dailyHeartRateSamples = sampleValues(
            for: heartRateType,
            unit: HKUnit.count().unitDivided(by: .minute()),
            from: rollingDayStart,
            to: now
        )
        async let dailyHrvSamples = sampleValues(
            for: hrvType,
            unit: .secondUnit(with: .milli),
            from: rollingDayStart,
            to: now
        )
        async let recentRawStepSamples = sampleValues(
            for: stepType,
            unit: .count(),
            from: now.addingTimeInterval(-90 * 60),
            to: now
        )
        async let weeklyStepSamples = dailyQuantityTotals(
            for: stepType,
            unit: .count(),
            from: weekStart,
            to: now
        )
        async let weeklySleepSamples = dailySleepTotals(
            for: sleepType,
            from: sleepQueryStart,
            reportingFrom: weekStart,
            to: now
        )
        async let baselineSleepSamples = dailySleepTotals(
            for: sleepType,
            from: baselineSleepStart,
            reportingFrom: baselineStart,
            to: now
        )

        let values = await (
            latestHeartRate,
            latestHrv,
            restingSamples,
            hrvBaselineSamples,
            baselineHeartRateSamples,
            dailyHeartRateSamples,
            dailyHrvSamples,
            recentRawStepSamples,
            weeklyStepSamples,
            weeklySleepSamples,
            baselineSleepSamples
        )

        if let sample = values.0 {
            watchHeartRate = sample.value
            watchHeartRateDate = sample.date
            heartRate = sample.value
        }
        if let sample = values.1 {
            watchHrv = sample.value
            watchHrvDate = sample.date
            hrv = sample.value
        }
        restingHeartRateHistory = values.2
        rawStepSamples = values.7
        baselineSleepHistory = values.10
        let restingBaseline = median(values.2.map(\.value).sorted())
        let timeSegmentBaseline = heartRateBaselineFor(
            now,
            samples: values.4,
            fallback: restingBaseline
        )
        heartRateBaseline = timeSegmentBaseline
        heartRateBaselineAverage = timeSegmentBaseline
        if !values.3.isEmpty {
            let validValues = values.3
                .map(\.value)
                .filter { $0 >= 10 && $0 <= 200 }
                .sorted()
            let recommended = median(validValues)
            hrvBaselineSampleCount = validValues.count
            hrvBaselineAverage = recommended
            if validValues.count >= requiredHrvBaselineSampleCount,
               let recommended {
                hrvBaseline = recommended
            } else {
                hrvBaseline = defaultHrvBaseline
            }
        } else {
            hrvBaselineSampleCount = 0
            hrvBaselineAverage = nil
            hrvBaseline = defaultHrvBaseline
        }
        if !values.5.isEmpty {
            heartRateSamples = values.5
        }
        if !values.6.isEmpty {
            hrvSamples = values.6
        }
        stepSamples = values.8
        sleepSamples = values.9
        if let todaySteps = values.8.last(where: {
            Calendar.current.isDate($0.date, inSameDayAs: now)
        }) {
            watchSteps = todaySteps.value
            watchStepsDate = now
            steps = todaySteps.value
        }
        if let latestSleep = values.9.last {
            watchSleepMinutes = latestSleep.value
            watchSleepDate = latestSleep.date
            sleepMinutes = latestSleep.value
        }

        stress = calculateStress(
            heartRate: heartRate,
            hrv: hrv,
            heartRateBaseline: heartRateBaseline,
            hrvBaseline: hrvBaseline,
            hrvDate: watchHrvDate
        ) ?? stress
        stressSamples = calculateStressSamples(
            heartRateSamples: heartRateSamples,
            hrvSamples: hrvSamples,
            heartRateBaseline: heartRateBaseline,
            hrvBaseline: hrvBaseline
        )

        if isActivityFiltered {
            status = "活动中，暂不判断压力状态"
            statusIcon = "figure.walk"
            sendWatchDataToPhone()
        } else if watchHeartRate != nil || watchHrv != nil || watchSleepMinutes != nil || watchSteps != nil {
            status = "已读取 Apple Watch 健康数据"
            statusIcon = "applewatch"
            sendWatchDataToPhone()
        } else if heartRate == nil && hrv == nil && sleepMinutes == nil && steps == nil {
            status = "等待 Apple Watch 健康数据"
            statusIcon = "waveform.path.ecg"
        } else {
            status = "正在显示上次同步数据"
            statusIcon = "clock.arrow.circlepath"
        }

        applySyncedPhoneDataIfAvailable()
        persistResolvedSnapshot()
    }

    func setMockDataEnabled(_ enabled: Bool) async {
        guard enabled != isMockDataEnabled else { return }
        isMockDataEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: mockDataEnabledKey)

        if enabled {
            applyMockDataAndSync()
            return
        }

        watchHeartRate = nil
        watchHrv = nil
        watchSleepMinutes = nil
        watchSteps = nil
        watchHeartRateDate = nil
        watchHrvDate = nil
        watchSleepDate = nil
        watchStepsDate = nil
        heartRate = nil
        hrv = nil
        sleepMinutes = nil
        steps = nil
        stress = nil
        heartRateSamples = []
        hrvSamples = []
        sleepSamples = []
        stepSamples = []
        stressSamples = []
        status = "正在恢复真实健康数据"
        statusIcon = "arrow.clockwise"
        persistResolvedSnapshot()
        sendMockDisabledToPhone()
        await requestAccessAndRefresh()
    }

    private func applyMockDataAndSync() {
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let heartRateValues: [(Int, Double)] = [
            (1, 61), (4, 59), (7, 63), (9, 70), (11, 76),
            (13, 81), (15, 72), (17, 79), (19, 84), (21, 77),
        ]
        let hrvValues: [(Int, Double)] = [
            (1, 68), (4, 71), (7, 63), (9, 57), (11, 51),
            (13, 43), (15, 54), (17, 46), (19, 39), (21, 45),
        ]

        func samples(_ values: [(Int, Double)], latest: Double) -> [WatchHealthSample] {
            var result = values.compactMap { hour, value -> WatchHealthSample? in
                guard let date = calendar.date(byAdding: .hour, value: hour, to: startOfDay),
                      date < now
                else { return nil }
                return WatchHealthSample(date: date, value: value)
            }
            result.append(WatchHealthSample(date: now, value: latest))
            return result
        }

        watchHeartRate = 74
        watchHrv = 48
        watchHeartRateDate = now
        watchHrvDate = now
        heartRateBaseline = 62
        hrvBaseline = 62
        hrvBaselineSampleCount = requiredHrvBaselineSampleCount
        heartRateBaselineAverage = 62
        hrvBaselineAverage = 62
        heartRate = 74
        hrv = 48
        heartRateSamples = samples(heartRateValues, latest: 74)
        hrvSamples = samples(hrvValues, latest: 48)
        stepSamples = [
            (6, 6480), (5, 8035), (4, 7210), (3, 9120),
            (2, 5840), (1, 7650), (0, 7270),
        ].compactMap { daysAgo, value in
            calendar.date(byAdding: .day, value: -daysAgo, to: startOfDay).map {
                WatchHealthSample(date: $0, value: Double(value))
            }
        }
        sleepSamples = [
            (6, 402), (5, 451), (4, 428), (3, 476),
            (2, 389), (1, 443), (0, 438),
        ].compactMap { daysAgo, value in
            calendar.date(byAdding: .day, value: -daysAgo, to: startOfDay).map {
                WatchHealthSample(date: $0, value: Double(value))
            }
        }
        watchSteps = 7270
        watchStepsDate = now
        steps = 7270
        watchSleepMinutes = 438
        watchSleepDate = startOfDay
        sleepMinutes = 438
        stress = calculateStress(
            heartRate: heartRate,
            hrv: hrv,
            heartRateBaseline: heartRateBaseline,
            hrvBaseline: hrvBaseline
        )
        stressSamples = calculateStressSamples(
            heartRateSamples: heartRateSamples,
            hrvSamples: hrvSamples,
            heartRateBaseline: heartRateBaseline,
            hrvBaseline: hrvBaseline
        )
        status = "Watch 测试数据已开启"
        statusIcon = "testtube.2"
        persistResolvedSnapshot()
        sendWatchDataToPhone()
    }

    private func sendMockDisabledToPhone() {
        guard WCSession.isSupported() else { return }
        let payload: [String: Any] = [
            "source": "watch",
            "mockDisabled": true,
            "updatedAt": Date().timeIntervalSince1970,
        ]
        let session = WCSession.default
        try? session.updateApplicationContext(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    private func activateWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func sendWatchDataToPhone() {
        guard WCSession.isSupported() else { return }
        let payload = makeWatchPayload()
        guard !payload.isEmpty else { return }
        let session = WCSession.default
        do {
            try session.updateApplicationContext(payload)
        } catch {
            status = "Watch 数据已保留，等待连接 iPhone"
            statusIcon = "iphone.slash"
        }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    private func makeWatchPayload() -> [String: Any] {
        let dates = [watchHeartRateDate, watchHrvDate, watchSleepDate, watchStepsDate].compactMap { $0 }
        let updatedAt = dates.max() ?? Date()
        var payload: [String: Any] = [
            "source": "watch",
            "isMockData": isMockDataEnabled,
            "updatedAt": updatedAt.timeIntervalSince1970,
            "heartRateSamples": encodeSamples(heartRateSamples),
            "hrvSamples": encodeSamples(hrvSamples),
            "sleepSamples": encodeSamples(sleepSamples),
            "stepSamples": encodeSamples(stepSamples),
            "stressSamples": encodeSamples(stressSamples),
        ]
        if let watchHeartRate {
            payload["heartRate"] = watchHeartRate
        }
        if let watchHeartRateDate {
            payload["heartRateMeasuredAt"] = watchHeartRateDate.timeIntervalSince1970
        }
        if let watchHrv {
            payload["hrv"] = watchHrv
        }
        if let watchHrvDate {
            payload["hrvMeasuredAt"] = watchHrvDate.timeIntervalSince1970
        }
        if let watchSleepMinutes {
            payload["sleepMinutes"] = watchSleepMinutes
        }
        if let watchSleepDate {
            payload["sleepMeasuredAt"] = watchSleepDate.timeIntervalSince1970
        }
        if let watchSteps {
            payload["steps"] = watchSteps
        }
        if let watchStepsDate {
            payload["stepsMeasuredAt"] = watchStepsDate.timeIntervalSince1970
        }
        if let heartRateBaseline {
            payload["heartRateBaseline"] = heartRateBaseline
        }
        if let hrvBaseline {
            payload["hrvBaseline"] = hrvBaseline
        }
        if let hrvBaselineAverage {
            payload["hrvBaselineRecommendation"] = hrvBaselineAverage
        }
        payload["hrvBaselineSampleCount"] = hrvBaselineSampleCount
        payload["stressConfidence"] = stressConfidence
        payload["isActivityFiltered"] = isActivityFiltered
        payload["stressMode"] = stressDataMode
        if let watchStress = calculateStress(
            heartRate: watchHeartRate,
            hrv: watchHrv,
            heartRateBaseline: heartRateBaseline,
            hrvBaseline: hrvBaseline,
            hrvDate: watchHrvDate
        ) {
            payload["stress"] = watchStress
        }
        return payload
    }

    private func applySyncedPhoneDataIfAvailable() {
        guard let syncedPhonePayload else { return }
        applySyncedPhoneData(syncedPhonePayload)
    }

    private func applySyncedPhoneData(_ payload: [String: Any]) {
        guard payload["source"] as? String != "watch" else { return }
        syncedPhonePayload = payload
        persistDictionary(payload, key: phonePayloadCacheKey)

        let phoneHeartRateSamples = decodeSamples(payload["heartRateSamples"])
        let phoneHrvSamples = decodeSamples(payload["hrvSamples"])
        let phoneSleepSamples = decodeSamples(payload["sleepSamples"])
        let phoneStepSamples = decodeSamples(payload["stepSamples"])
        let phoneStressSamples = decodeSamples(payload["stressSamples"])
        let phoneHeartRate = number(payload["heartRate"]) ?? phoneHeartRateSamples.last?.value
        let phoneHrv = number(payload["hrv"]) ?? phoneHrvSamples.last?.value
        let phoneSleepMinutes = number(payload["sleepMinutes"]) ?? phoneSleepSamples.last?.value
        let phoneSteps = number(payload["steps"]) ?? phoneStepSamples.last?.value
        let phoneHeartRateDate = date(
            payload["heartRateMeasuredAt"],
            fallback: phoneHeartRateSamples.last?.date ?? date(payload["updatedAt"])
        )
        let phoneHrvDate = date(
            payload["hrvMeasuredAt"],
            fallback: phoneHrvSamples.last?.date ?? date(payload["updatedAt"])
        )
        let phoneSleepDate = date(
            payload["sleepMeasuredAt"],
            fallback: phoneSleepSamples.last?.date ?? date(payload["updatedAt"])
        )
        let phoneStepsDate = date(
            payload["stepsMeasuredAt"],
            fallback: phoneStepSamples.last?.date ?? date(payload["updatedAt"])
        )

        let usePhoneHeartRate = shouldUsePhoneValue(
            phoneValue: phoneHeartRate,
            phoneDate: phoneHeartRateDate,
            watchValue: watchHeartRate,
            watchDate: watchHeartRateDate
        )
        let usePhoneHrv = shouldUsePhoneValue(
            phoneValue: phoneHrv,
            phoneDate: phoneHrvDate,
            watchValue: watchHrv,
            watchDate: watchHrvDate
        )
        let usePhoneSleep = shouldUsePhoneValue(
            phoneValue: phoneSleepMinutes,
            phoneDate: phoneSleepDate,
            watchValue: watchSleepMinutes,
            watchDate: watchSleepDate
        )
        let usePhoneSteps = shouldUsePhoneValue(
            phoneValue: phoneSteps,
            phoneDate: phoneStepsDate,
            watchValue: watchSteps,
            watchDate: watchStepsDate
        )

        if usePhoneHeartRate {
            heartRate = phoneHeartRate
        } else if let watchHeartRate {
            heartRate = watchHeartRate
        }
        if usePhoneHrv {
            hrv = phoneHrv
        } else if let watchHrv {
            hrv = watchHrv
        }
        if usePhoneSleep {
            sleepMinutes = phoneSleepMinutes
        } else if let watchSleepMinutes {
            sleepMinutes = watchSleepMinutes
        }
        if usePhoneSteps {
            steps = phoneSteps
        } else if let watchSteps {
            steps = watchSteps
        }

        if let value = number(payload["heartRateBaseline"]), heartRateBaseline == nil {
            heartRateBaseline = value
            heartRateBaselineAverage = value
        }
        if let value = number(payload["hrvBaseline"]) {
            hrvBaseline = value
            if hrvBaselineAverage == nil {
                hrvBaselineAverage = value
            }
        }
        if let value = number(payload["hrvBaselineRecommendation"]) {
            hrvBaselineAverage = value
        }
        if let value = number(payload["hrvBaselineSampleCount"]) {
            hrvBaselineSampleCount = max(hrvBaselineSampleCount, Int(value.rounded()))
        }

        heartRateSamples = mergeSamples(heartRateSamples, phoneHeartRateSamples)
        hrvSamples = mergeSamples(hrvSamples, phoneHrvSamples)
        if usePhoneSleep || sleepSamples.isEmpty {
            sleepSamples = phoneSleepSamples
        }
        if usePhoneSteps || stepSamples.isEmpty {
            stepSamples = phoneStepSamples
        }
        stressSamples = mergeSamples(stressSamples, phoneStressSamples)
        stress = calculateStress(
            heartRate: heartRate,
            hrv: hrv,
            heartRateBaseline: heartRateBaseline,
            hrvBaseline: hrvBaseline
        ) ?? number(payload["stress"]) ?? stress
        if stressSamples.isEmpty {
            stressSamples = calculateStressSamples(
                heartRateSamples: heartRateSamples,
                hrvSamples: hrvSamples,
                heartRateBaseline: heartRateBaseline,
                hrvBaseline: hrvBaseline
            )
        }

        let filledMissingValue =
            (watchHeartRate == nil && usePhoneHeartRate) ||
            (watchHrv == nil && usePhoneHrv) ||
            (watchSleepMinutes == nil && usePhoneSleep) ||
            (watchSteps == nil && usePhoneSteps)
        let usedNewerPhoneValue =
            (watchHeartRate != nil && usePhoneHeartRate) ||
            (watchHrv != nil && usePhoneHrv) ||
            (watchSleepMinutes != nil && usePhoneSleep) ||
            (watchSteps != nil && usePhoneSteps)
        status = if usedNewerPhoneValue {
            "iPhone 有至少晚 5 分钟的新数据"
        } else if filledMissingValue {
            "Watch 数据优先，缺失项已由 iPhone 补充"
        } else {
            "正在显示 Apple Watch 最新数据"
        }
        let usedPhone = usePhoneHeartRate || usePhoneHrv || usePhoneSleep || usePhoneSteps
        statusIcon = usedPhone ? "iphone.and.arrow.forward" : "applewatch"
        persistResolvedSnapshot()
    }

    private func shouldUsePhoneValue(
        phoneValue: Double?,
        phoneDate: Date?,
        watchValue: Double?,
        watchDate: Date?
    ) -> Bool {
        guard phoneValue != nil else { return false }
        guard watchValue != nil else { return true }
        guard let phoneDate, let watchDate else { return false }
        return phoneDate.timeIntervalSince(watchDate) >= phoneOverrideDelay
    }

    private func encodeSamples(_ samples: [WatchHealthSample]) -> [[String: Any]] {
        samples.map {
            ["timestamp": $0.date.timeIntervalSince1970, "value": $0.value]
        }
    }

    private func decodeSamples(_ rawValue: Any?) -> [WatchHealthSample] {
        guard let entries = rawValue as? [[String: Any]] else { return [] }
        return entries.compactMap { entry in
            guard
                let timestamp = number(entry["timestamp"]),
                let value = number(entry["value"])
            else {
                return nil
            }
            return WatchHealthSample(
                date: Date(timeIntervalSince1970: timestamp),
                value: value
            )
        }
        .sorted { $0.date < $1.date }
    }

    private func mergeSamples(
        _ first: [WatchHealthSample],
        _ second: [WatchHealthSample]
    ) -> [WatchHealthSample] {
        var samplesBySecond: [Int64: WatchHealthSample] = [:]
        for sample in first + second {
            let key = Int64(sample.date.timeIntervalSince1970.rounded())
            if samplesBySecond[key] == nil {
                samplesBySecond[key] = sample
            }
        }
        let merged = samplesBySecond.values.sorted { $0.date < $1.date }
        return Self.downsample(merged, maximumCount: 120)
    }

    private func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber {
            return value.doubleValue
        }
        return value as? Double
    }

    private func date(_ value: Any?, fallback: Date? = nil) -> Date? {
        guard let timestamp = number(value) else { return fallback }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func restoreCachedData() {
        if let snapshot = restoredDictionary(key: cacheKey) {
            heartRate = number(snapshot["heartRate"])
            hrv = number(snapshot["hrv"])
            sleepMinutes = number(snapshot["sleepMinutes"])
            steps = number(snapshot["steps"])
            stress = number(snapshot["stress"])
            heartRateBaseline = number(snapshot["heartRateBaseline"])
            hrvBaseline = number(snapshot["hrvBaseline"])
            hrvBaselineAverage = number(snapshot["hrvBaselineRecommendation"])
                ?? hrvBaseline
            hrvBaselineSampleCount = Int(
                number(snapshot["hrvBaselineSampleCount"])?.rounded() ?? 0
            )
            heartRateBaselineAverage = heartRateBaseline
            watchHeartRate = number(snapshot["watchHeartRate"])
            watchHrv = number(snapshot["watchHrv"])
            watchSleepMinutes = number(snapshot["watchSleepMinutes"])
            watchSteps = number(snapshot["watchSteps"])
            watchHeartRateDate = date(snapshot["watchHeartRateMeasuredAt"])
            watchHrvDate = date(snapshot["watchHrvMeasuredAt"])
            watchSleepDate = date(snapshot["watchSleepMeasuredAt"])
            watchStepsDate = date(snapshot["watchStepsMeasuredAt"])
            heartRateSamples = decodeSamples(snapshot["heartRateSamples"])
            hrvSamples = decodeSamples(snapshot["hrvSamples"])
            sleepSamples = decodeSamples(snapshot["sleepSamples"])
            stepSamples = decodeSamples(snapshot["stepSamples"])
            stressSamples = decodeSamples(snapshot["stressSamples"])
            if heartRate != nil || hrv != nil || sleepMinutes != nil || steps != nil {
                status = "正在显示上次保存的数据"
                statusIcon = "clock.arrow.circlepath"
            }
        }
        syncedPhonePayload = restoredDictionary(key: phonePayloadCacheKey)
    }

    private func persistResolvedSnapshot() {
        var snapshot: [String: Any] = [
            "heartRateSamples": encodeSamples(heartRateSamples),
            "hrvSamples": encodeSamples(hrvSamples),
            "sleepSamples": encodeSamples(sleepSamples),
            "stepSamples": encodeSamples(stepSamples),
            "stressSamples": encodeSamples(stressSamples),
        ]
        if let heartRate { snapshot["heartRate"] = heartRate }
        if let hrv { snapshot["hrv"] = hrv }
        if let sleepMinutes { snapshot["sleepMinutes"] = sleepMinutes }
        if let steps { snapshot["steps"] = steps }
        if let stress { snapshot["stress"] = stress }
        if let heartRateBaseline { snapshot["heartRateBaseline"] = heartRateBaseline }
        if let hrvBaseline { snapshot["hrvBaseline"] = hrvBaseline }
        if let hrvBaselineAverage {
            snapshot["hrvBaselineRecommendation"] = hrvBaselineAverage
        }
        snapshot["hrvBaselineSampleCount"] = hrvBaselineSampleCount
        if let watchHeartRate { snapshot["watchHeartRate"] = watchHeartRate }
        if let watchHrv { snapshot["watchHrv"] = watchHrv }
        if let watchSleepMinutes { snapshot["watchSleepMinutes"] = watchSleepMinutes }
        if let watchSteps { snapshot["watchSteps"] = watchSteps }
        if let watchHeartRateDate {
            snapshot["watchHeartRateMeasuredAt"] = watchHeartRateDate.timeIntervalSince1970
        }
        if let watchHrvDate {
            snapshot["watchHrvMeasuredAt"] = watchHrvDate.timeIntervalSince1970
        }
        if let watchSleepDate {
            snapshot["watchSleepMeasuredAt"] = watchSleepDate.timeIntervalSince1970
        }
        if let watchStepsDate {
            snapshot["watchStepsMeasuredAt"] = watchStepsDate.timeIntervalSince1970
        }
        persistDictionary(snapshot, key: cacheKey)
    }

    private func persistDictionary(_ dictionary: [String: Any], key: String) {
        guard JSONSerialization.isValidJSONObject(dictionary),
              let data = try? JSONSerialization.data(withJSONObject: dictionary)
        else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func restoredDictionary(key: String) -> [String: Any]? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return value
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        let context = session.receivedApplicationContext
        guard !context.isEmpty else { return }
        Task { @MainActor [weak self] in
            self?.applySyncedPhoneData(context)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor [weak self] in
            self?.applySyncedPhoneData(applicationContext)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor [weak self] in
            self?.applySyncedPhoneData(message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        Task { @MainActor [weak self] in
            self?.applySyncedPhoneData(userInfo)
        }
    }

    private func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let middle = values.count / 2
        if values.count.isMultiple(of: 2) {
            return (values[middle - 1] + values[middle]) / 2
        }
        return values[middle]
    }

    private func calculateStress(
        heartRate: Double?,
        hrv: Double?,
        heartRateBaseline: Double?,
        hrvBaseline: Double?,
        hrvDate: Date? = nil,
        at date: Date = Date()
    ) -> Double? {
        guard
            let heartRate,
            let heartRateBaseline,
            heartRateBaseline > 0
        else {
            return nil
        }

        let activityNow = isPhysicalActivity(
            heartRate: heartRate,
            baseline: heartRateBaseline,
            at: date
        )
        let lastActivity = lastSignificantActivity(at: date)
        let activityAge = lastActivity.map { date.timeIntervalSince($0) }
        let withinThirtyMinutes = activityAge.map { $0 >= 0 && $0 <= 30 * 60 } ?? false
        if Calendar.current.isDate(date, inSameDayAs: Date()) {
            isActivityFiltered = activityNow || withinThirtyMinutes
        }
        guard !activityNow, !withinThirtyMinutes else { return nil }

        let heartRateScore = hrScore(heartRate, baseline: heartRateBaseline)
        let recentScores = heartRateSamples
            .filter {
                $0.date <= date &&
                    date.timeIntervalSince($0.date) <= 15 * 60 &&
                    !isPhysicalActivity(
                        heartRate: $0.value,
                        baseline: heartRateBaseline,
                        at: $0.date
                    )
            }
            .map { hrScore($0.value, baseline: heartRateBaseline) }
            .sorted()

        let hrvIsFresh = hrvDate.map { abs(date.timeIntervalSince($0)) <= 6 * 60 * 60 } ?? (hrv != nil)
        let acuteStress: Double
        let fullHrvMode = hrv != nil && hrvBaseline != nil && hrvBaseline! > 0 && hrvIsFresh
        if Calendar.current.isDate(date, inSameDayAs: Date()) {
            stressDataMode = fullHrvMode ? "fullHrv" : "noHrv"
        }
        if fullHrvMode, let hrv, let hrvBaseline {
            let hrvScore = score(((hrvBaseline - hrv) / hrvBaseline) / 0.40 * 100)
            acuteStress = hrvScore * 0.65 + heartRateScore * 0.35
        } else if recentScores.count >= 3, let recentMedian = median(recentScores) {
            acuteStress = heartRateScore * 0.70 + recentMedian * 0.30
        } else {
            acuteStress = heartRateScore
        }

        let restingBaseline = median(restingHeartRateHistory.map(\.value).sorted())
        let todayRhr = restingHeartRateHistory.last(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        })?.value
        let rhrScore = todayRhr.flatMap { current in
            restingBaseline.map { baseline in
                score(((current - baseline) / baseline) / 0.12 * 100)
            }
        }
        let sleepBaseline = median(baselineSleepHistory.map(\.value).sorted())
        let latestSleep = baselineSleepHistory.last(where: { $0.date <= date })?.value
        let sleepScore = latestSleep.flatMap { current in
            sleepBaseline.map { baseline in
                score(((baseline - current) / baseline) / 0.35 * 100)
            }
        }
        let recoveryLoad: Double
        if let rhrScore, let sleepScore {
            recoveryLoad = rhrScore * 0.60 + sleepScore * 0.40
        } else {
            recoveryLoad = rhrScore ?? sleepScore ?? 0
        }

        var confidence = fullHrvMode ? 100 : 80
        let baselineDays = Set(
            restingHeartRateHistory.map { Calendar.current.startOfDay(for: $0.date) } +
                baselineSleepHistory.map { Calendar.current.startOfDay(for: $0.date) }
        ).count
        if baselineDays < 14 { confidence -= 10 }
        if baselineDays < 7 { confidence -= 15 }
        if recentScores.count < 3 { confidence -= 15 }
        if todayRhr == nil { confidence -= 10 }
        if latestSleep == nil { confidence -= 10 }
        if let activityAge, activityAge > 30 * 60, activityAge <= 90 * 60 {
            confidence -= 20
        }
        if Calendar.current.isDate(date, inSameDayAs: Date()) {
            stressConfidence = min(max(confidence, 0), 100)
        }

        let recoveryFactor = 1 + 0.15 * (score(recoveryLoad) / 100)
        return score(acuteStress * recoveryFactor).rounded()
    }

    private func calculateStressSamples(
        heartRateSamples: [WatchHealthSample],
        hrvSamples: [WatchHealthSample],
        heartRateBaseline: Double?,
        hrvBaseline: Double?
    ) -> [WatchHealthSample] {
        guard let heartRateBaseline, heartRateBaseline > 0 else { return [] }
        return heartRateSamples.compactMap { heartRateSample in
            let nearbyHrv = hrvSamples.min {
                abs($0.date.timeIntervalSince(heartRateSample.date)) <
                    abs($1.date.timeIntervalSince(heartRateSample.date))
            }
            let usableHrv = nearbyHrv.flatMap { sample in
                abs(sample.date.timeIntervalSince(heartRateSample.date)) <= 3 * 60 * 60
                    ? sample.value
                    : nil
            }
            guard let value = calculateStress(
                heartRate: heartRateSample.value,
                hrv: usableHrv,
                heartRateBaseline: heartRateBaseline,
                hrvBaseline: hrvBaseline,
                hrvDate: nearbyHrv?.date,
                at: heartRateSample.date
            ) else { return nil }
            return WatchHealthSample(date: heartRateSample.date, value: value)
        }
    }

    private func score(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 100)
    }

    private func hrScore(_ heartRate: Double, baseline: Double) -> Double {
        guard heartRate.isFinite, baseline.isFinite, baseline > 0 else { return 0 }
        return score(((heartRate - baseline) / baseline) / 0.30 * 100)
    }

    private func nearbySteps(at date: Date, window: TimeInterval) -> Double {
        rawStepSamples
            .filter { abs($0.date.timeIntervalSince(date)) <= window }
            .reduce(0) { $0 + $1.value }
    }

    private func isPhysicalActivity(
        heartRate: Double,
        baseline: Double,
        at date: Date
    ) -> Bool {
        guard baseline > 0 else { return false }
        let ratio = heartRate / baseline
        if ratio >= 1.75 { return true }
        return ratio >= 1.55 && nearbySteps(at: date, window: 20 * 60) >= 80
    }

    private func lastSignificantActivity(at date: Date) -> Date? {
        rawStepSamples.last(where: {
            $0.date <= date &&
                date.timeIntervalSince($0.date) <= 90 * 60 &&
                nearbySteps(at: $0.date, window: 10 * 60) >= 80
        })?.date
    }

    private func heartRateBaselineFor(
        _ date: Date,
        samples: [WatchHealthSample],
        fallback: Double?
    ) -> Double? {
        let hour = Calendar.current.component(.hour, from: date)
        let range: Range<Int>?
        switch hour {
        case 6..<9: range = 6..<9
        case 9..<12: range = 9..<12
        case 12..<15: range = 12..<15
        case 15..<18: range = 15..<18
        case 18..<21: range = 18..<21
        case 21..<24: range = 21..<24
        default: range = nil
        }
        guard let range else { return fallback }
        let values = samples.filter {
            range.contains(Calendar.current.component(.hour, from: $0.date)) &&
                nearbySteps(at: $0.date, window: 20 * 60) < 80
        }.map(\.value).sorted()
        return values.count >= 3 ? median(values) : fallback
    }

    private func latestSample(
        for type: HKQuantityType,
        unit: HKUnit
    ) async -> WatchHealthSample? {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [
                    NSSortDescriptor(
                        key: HKSampleSortIdentifierEndDate,
                        ascending: false
                    ),
                ]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: WatchHealthSample(
                    date: sample.endDate,
                    value: sample.quantity.doubleValue(for: unit)
                ))
            }
            store.execute(query)
        }
    }

    private func averageValue(
        for type: HKQuantityType,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double? {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: .strictStartDate
            )
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, _ in
                continuation.resume(
                    returning: result?.averageQuantity()?.doubleValue(for: unit)
                )
            }
            store.execute(query)
        }
    }

    private func sampleValues(
        for type: HKQuantityType,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> [WatchHealthSample] {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: .strictStartDate
            )
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [
                    NSSortDescriptor(
                        key: HKSampleSortIdentifierStartDate,
                        ascending: true
                    ),
                ]
            ) { _, samples, _ in
                let values = (samples as? [HKQuantitySample] ?? []).map { sample in
                    WatchHealthSample(
                        date: sample.startDate,
                        value: sample.quantity.doubleValue(for: unit)
                    )
                }
                continuation.resume(returning: Self.downsample(values, maximumCount: 120))
            }
            store.execute(query)
        }
    }

    private func dailyQuantityTotals(
        for type: HKQuantityType,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> [WatchHealthSample] {
        await withCheckedContinuation { continuation in
            var interval = DateComponents()
            interval.day = 1
            let anchor = Calendar.current.startOfDay(for: start)
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: .strictStartDate
            )
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchor,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                var samples: [WatchHealthSample] = []
                results?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    guard let value = statistics.sumQuantity()?.doubleValue(for: unit),
                          value > 0
                    else { return }
                    samples.append(
                        WatchHealthSample(date: statistics.startDate, value: value)
                    )
                }
                continuation.resume(returning: samples)
            }
            store.execute(query)
        }
    }

    private func dailySleepTotals(
        for type: HKCategoryType,
        from start: Date,
        reportingFrom reportingStart: Date,
        to end: Date
    ) async -> [WatchHealthSample] {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: []
            )
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [
                    NSSortDescriptor(
                        key: HKSampleSortIdentifierStartDate,
                        ascending: true
                    ),
                ]
            ) { _, samples, _ in
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                ]
                let calendar = Calendar.current
                let rawIntervals = (samples as? [HKCategorySample] ?? [])
                    .filter { asleepValues.contains($0.value) }
                    .compactMap { sample -> DateInterval? in
                        let intervalStart = max(sample.startDate, start)
                        let intervalEnd = min(sample.endDate, end)
                        guard intervalStart < intervalEnd else { return nil }
                        return DateInterval(start: intervalStart, end: intervalEnd)
                    }
                    .sorted { $0.start < $1.start }

                var mergedIntervals: [DateInterval] = []
                for interval in rawIntervals {
                    guard let last = mergedIntervals.last else {
                        mergedIntervals.append(interval)
                        continue
                    }
                    if interval.start <= last.end {
                        mergedIntervals[mergedIntervals.count - 1] = DateInterval(
                            start: last.start,
                            end: max(last.end, interval.end)
                        )
                    } else {
                        mergedIntervals.append(interval)
                    }
                }

                let maximumSleepStageGap: TimeInterval = 3 * 60 * 60
                var sessions: [[DateInterval]] = []
                for interval in mergedIntervals {
                    if let lastSession = sessions.last,
                       let lastInterval = lastSession.last,
                       interval.start.timeIntervalSince(lastInterval.end) <= maximumSleepStageGap {
                        sessions[sessions.count - 1].append(interval)
                    } else {
                        sessions.append([interval])
                    }
                }

                let reportingDay = calendar.startOfDay(for: reportingStart)
                var minutesByWakeDay: [Date: Double] = [:]
                for session in sessions {
                    guard let wakeTime = session.last?.end else { continue }
                    let wakeDay = calendar.startOfDay(for: wakeTime)
                    guard wakeDay >= reportingDay, wakeDay <= end else { continue }
                    let asleepMinutes = session.reduce(0.0) { result, interval in
                        result + interval.duration / 60
                    }
                    minutesByWakeDay[wakeDay, default: 0] += asleepMinutes
                }

                let totals = minutesByWakeDay.map { day, minutes in
                    WatchHealthSample(
                        date: day,
                        value: minutes
                    )
                }
                .sorted { $0.date < $1.date }
                continuation.resume(returning: totals)
            }
            store.execute(query)
        }
    }

    nonisolated private static func downsample(
        _ samples: [WatchHealthSample],
        maximumCount: Int
    ) -> [WatchHealthSample] {
        guard samples.count > maximumCount else { return samples }
        let stride = Double(samples.count - 1) / Double(maximumCount - 1)
        return (0..<maximumCount).map { index in
            samples[Int((Double(index) * stride).rounded())]
        }
    }
}
