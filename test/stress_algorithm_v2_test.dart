import 'package:flutter_test/flutter_test.dart';
import 'package:moodland/stress_algorithm_v2.dart';

void main() {
  group('MoodLand Stress Algorithm V2 scores', () {
    test('HR equal to baseline scores zero', () {
      expect(calculateHrScore(heartRate: 60, baselineHeartRate: 60), 0);
    });

    test('HR 30 percent above baseline scores 100', () {
      expect(
        calculateHrScore(heartRate: 78, baselineHeartRate: 60),
        closeTo(100, 0.001),
      );
    });

    test('HRV equal to baseline scores zero', () {
      expect(calculateHrvScore(hrv: 50, baselineHrv: 50), 0);
    });

    test('HRV 40 percent below baseline scores 100', () {
      expect(calculateHrvScore(hrv: 30, baselineHrv: 50), closeTo(100, 0.001));
    });

    test('full HRV acute stress keeps 65/35 weighting', () {
      expect(
        calculateAcuteStressWithHrv(hrScore: 40, hrvScore: 80),
        closeTo(66, 0.001),
      );
    });

    test('no-HRV mode uses recent median with 70/30 weighting', () {
      expect(
        calculateAcuteStressWithoutHrv(
          hrScore: 80,
          recentHrScores: const [20, 40, 60],
        ),
        closeTo(68, 0.001),
      );
    });

    test('sleep above personal baseline scores zero', () {
      expect(
        calculateSleepScore(sleepMinutes: 500, baselineSleepMinutes: 450),
        0,
      );
    });

    test('RHR 12 percent above baseline scores 100', () {
      expect(
        calculateRhrScore(restingHeartRate: 67.2, baselineRestingHeartRate: 60),
        closeTo(100, 0.001),
      );
    });

    test('final stress is always clamped to 0-100', () {
      expect(calculateFinalStress(acuteStress: -20, recoveryLoad: 100), 0);
      expect(calculateFinalStress(acuteStress: 100, recoveryLoad: 100), 100);
    });

    test('zero baselines do not produce NaN or crash', () {
      expect(calculateHrScore(heartRate: 80, baselineHeartRate: 0), 0);
      expect(calculateHrvScore(hrv: 40, baselineHrv: 0), 0);
      expect(
        calculateSleepScore(sleepMinutes: 400, baselineSleepMinutes: 0),
        0,
      );
    });
  });

  group('MoodLand Stress Algorithm V2 estimate', () {
    StressEstimate estimate({
      double? hrv = 45,
      double? baselineHrv = 60,
      bool isHrvFresh = true,
      bool isActivity = false,
    }) {
      return calculateStressV2(
        heartRate: 72,
        baselineHeartRate: 60,
        hrv: hrv,
        baselineHrv: baselineHrv,
        isHrvFresh: isHrvFresh,
        recentHeartRates: const [68, 70, 71, 72],
        todayRestingHeartRate: 62,
        baselineRestingHeartRate: 60,
        lastNightSleepMinutes: 420,
        baselineSleepMinutes: 450,
        baselineDays: 14,
        isActivity: isActivity,
        timeSinceActivity: null,
      );
    }

    test('obvious activity returns no ordinary stress estimate', () {
      final result = estimate(isActivity: true);
      expect(result.stress, isNull);
      expect(result.isActivityFiltered, isTrue);
    });

    test('missing HRV enters noHrv mode and still estimates', () {
      final result = estimate(hrv: null);
      expect(result.mode, StressDataMode.noHrv);
      expect(result.stress, isNotNull);
      expect(result.stress, inInclusiveRange(0, 100));
    });

    test('fresh HRV enters fullHrv mode', () {
      final result = estimate();
      expect(result.mode, StressDataMode.fullHrv);
      expect(result.stress, isNotNull);
    });

    test('stale HRV falls back to noHrv mode', () {
      final result = estimate(isHrvFresh: false);
      expect(result.mode, StressDataMode.noHrv);
    });

    test('missing HR produces no instantaneous estimate', () {
      final result = calculateStressV2(
        heartRate: null,
        baselineHeartRate: 60,
        hrv: 45,
        baselineHrv: 60,
        isHrvFresh: true,
        recentHeartRates: const [],
        todayRestingHeartRate: null,
        baselineRestingHeartRate: 60,
        lastNightSleepMinutes: null,
        baselineSleepMinutes: 450,
        baselineDays: 14,
        isActivity: false,
        timeSinceActivity: null,
      );
      expect(result.stress, isNull);
      expect(result.reason, contains('数据不足'));
    });
  });
}
