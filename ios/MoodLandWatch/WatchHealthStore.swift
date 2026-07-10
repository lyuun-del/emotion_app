import Foundation
import HealthKit

@MainActor
final class WatchHealthStore: ObservableObject {
    @Published private(set) var heartRate: Double?
    @Published private(set) var hrv: Double?
    @Published private(set) var stress: Double?
    @Published private(set) var status = "准备读取健康数据"
    @Published private(set) var statusIcon = "heart.text.square"
    @Published private(set) var isLoading = false

    private let store = HKHealthStore()

    func requestAccessAndRefresh() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "此设备不支持健康数据"
            statusIcon = "exclamationmark.triangle"
            return
        }

        let readTypes = Set([
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
        ])

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            await refresh()
        } catch {
            status = "请在健康 App 中允许访问"
            statusIcon = "lock"
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let now = Date()
        let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let heartRateType = HKQuantityType(.heartRate)
        let restingHeartRateType = HKQuantityType(.restingHeartRate)
        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)

        async let latestHeartRate = latestValue(
            for: heartRateType,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
        async let latestHrv = latestValue(for: hrvType, unit: .secondUnit(with: .milli))
        async let restingBaseline = averageValue(
            for: restingHeartRateType,
            unit: HKUnit.count().unitDivided(by: .minute()),
            from: monthAgo,
            to: now
        )
        async let hrvBaseline = averageValue(
            for: hrvType,
            unit: .secondUnit(with: .milli),
            from: monthAgo,
            to: now
        )

        let values = await (latestHeartRate, latestHrv, restingBaseline, hrvBaseline)
        heartRate = values.0
        hrv = values.1
        stress = calculateStress(
            heartRate: values.0,
            hrv: values.1,
            heartRateBaseline: values.2,
            hrvBaseline: values.3
        )

        if stress != nil {
            status = "已读取最新健康数据"
            statusIcon = "checkmark.circle"
        } else if heartRate == nil && hrv == nil {
            status = "等待 Apple Watch 健康数据"
            statusIcon = "waveform.path.ecg"
        } else {
            status = "数据不足，继续佩戴后再刷新"
            statusIcon = "clock"
        }
    }

    private func calculateStress(
        heartRate: Double?,
        hrv: Double?,
        heartRateBaseline: Double?,
        hrvBaseline: Double?
    ) -> Double? {
        guard
            let heartRate,
            let heartRateBaseline,
            heartRateBaseline > 0
        else {
            return nil
        }

        let heartRateDelta = (heartRate - heartRateBaseline) / heartRateBaseline
        let heartRateScore = min(max(heartRateDelta / 0.30 * 100, 0), 100)

        guard let hrv, let hrvBaseline, hrvBaseline > 0 else {
            return heartRateScore.rounded()
        }

        let hrvDelta = (hrvBaseline - hrv) / hrvBaseline
        let hrvScore = min(max(hrvDelta / 0.40 * 100, 0), 100)
        return min(max(hrvScore * 0.65 + heartRateScore * 0.35, 0), 100).rounded()
    }

    private func latestValue(for type: HKQuantityType, unit: HKUnit) async -> Double? {
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
                let sample = samples?.first as? HKQuantitySample
                continuation.resume(returning: sample?.quantity.doubleValue(for: unit))
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
}
