import 'dart:math' as math;

enum StressDataMode { fullHrv, noHrv }

enum StressLevel { stable, mild, tense, high }

class StressEstimate {
  const StressEstimate({
    required this.stress,
    required this.confidence,
    required this.mode,
    required this.level,
    required this.isActivityFiltered,
    this.reason,
  });

  /// Null means an instantaneous estimate cannot be produced safely.
  final int? stress;
  final int confidence;
  final StressDataMode mode;
  final StressLevel level;
  final bool isActivityFiltered;
  final String? reason;
}

double _score(double value) {
  if (!value.isFinite) return 0;
  return value.clamp(0, 100).toDouble();
}

double? _validBaseline(double? value) {
  if (value == null || !value.isFinite || value <= 0) return null;
  return value;
}

double calculateHrScore({
  required double heartRate,
  required double baselineHeartRate,
}) {
  if (!heartRate.isFinite || _validBaseline(baselineHeartRate) == null) {
    return 0;
  }
  return _score(
    ((heartRate - baselineHeartRate) / baselineHeartRate) / 0.30 * 100,
  );
}

double calculateHrvScore({required double hrv, required double baselineHrv}) {
  if (!hrv.isFinite || _validBaseline(baselineHrv) == null) return 0;
  return _score(((baselineHrv - hrv) / baselineHrv) / 0.40 * 100);
}

double calculateRhrScore({
  required double restingHeartRate,
  required double baselineRestingHeartRate,
}) {
  if (!restingHeartRate.isFinite ||
      _validBaseline(baselineRestingHeartRate) == null) {
    return 0;
  }
  return _score(
    ((restingHeartRate - baselineRestingHeartRate) / baselineRestingHeartRate) /
        0.12 *
        100,
  );
}

double calculateSleepScore({
  required double sleepMinutes,
  required double baselineSleepMinutes,
}) {
  if (!sleepMinutes.isFinite || _validBaseline(baselineSleepMinutes) == null) {
    return 0;
  }
  return _score(
    ((baselineSleepMinutes - sleepMinutes) / baselineSleepMinutes) / 0.35 * 100,
  );
}

double calculateRecoveryLoad({double? rhrScore, double? sleepScore}) {
  final validRhr = rhrScore?.isFinite == true ? _score(rhrScore!) : null;
  final validSleep = sleepScore?.isFinite == true ? _score(sleepScore!) : null;
  if (validRhr != null && validSleep != null) {
    return validRhr * 0.60 + validSleep * 0.40;
  }
  return validRhr ?? validSleep ?? 0;
}

double calculateAcuteStressWithHrv({
  required double hrScore,
  required double hrvScore,
}) => _score(_score(hrvScore) * 0.65 + _score(hrScore) * 0.35);

double calculateAcuteStressWithoutHrv({
  required double hrScore,
  required List<double> recentHrScores,
}) {
  final valid =
      recentHrScores.where((value) => value.isFinite).map(_score).toList()
        ..sort();
  if (valid.length < 3) return _score(hrScore);
  final middle = valid.length ~/ 2;
  final median = valid.length.isOdd
      ? valid[middle]
      : (valid[middle - 1] + valid[middle]) / 2;
  return _score(_score(hrScore) * 0.70 + median * 0.30);
}

int calculateFinalStress({
  required double acuteStress,
  required double recoveryLoad,
}) {
  final factor = 1 + 0.15 * (_score(recoveryLoad) / 100);
  return _score(_score(acuteStress) * factor).round();
}

int calculateConfidence({
  required StressDataMode mode,
  required int baselineDays,
  required int recentHrSampleCount,
  required bool hasTodayRhr,
  required bool hasLastNightSleep,
  required bool isPostActivityRecovery,
  required bool hasTemperatureAnomaly,
}) {
  var confidence = mode == StressDataMode.fullHrv ? 100 : 80;
  if (baselineDays < 14) confidence -= 10;
  if (baselineDays < 7) confidence -= 15;
  if (recentHrSampleCount < 3) confidence -= 15;
  if (!hasTodayRhr) confidence -= 10;
  if (!hasLastNightSleep) confidence -= 10;
  if (isPostActivityRecovery) confidence -= 20;
  if (hasTemperatureAnomaly) confidence -= 20;
  return confidence.clamp(0, 100);
}

StressLevel stressLevelFor(int? stress) {
  final value = stress ?? 0;
  if (value <= 24) return StressLevel.stable;
  if (value <= 49) return StressLevel.mild;
  if (value <= 74) return StressLevel.tense;
  return StressLevel.high;
}

String stressLevelLabel(StressLevel level) => switch (level) {
  StressLevel.stable => '平稳',
  StressLevel.mild => '略有波动',
  StressLevel.tense => '有些紧绷',
  StressLevel.high => '明显紧绷',
};

StressEstimate calculateStressV2({
  required double? heartRate,
  required double? baselineHeartRate,
  required double? hrv,
  required double? baselineHrv,
  required bool isHrvFresh,
  required List<double> recentHeartRates,
  required double? todayRestingHeartRate,
  required double? baselineRestingHeartRate,
  required double? lastNightSleepMinutes,
  required double? baselineSleepMinutes,
  required int baselineDays,
  required bool isActivity,
  required Duration? timeSinceActivity,
  bool hasTemperatureAnomaly = false,
}) {
  final validHrv = hrv != null && hrv.isFinite && hrv > 0;
  final validHrvBaseline = _validBaseline(baselineHrv) != null;
  final mode = validHrv && validHrvBaseline && isHrvFresh
      ? StressDataMode.fullHrv
      : StressDataMode.noHrv;
  final recentScores = <double>[
    if (_validBaseline(baselineHeartRate) != null)
      for (final sample in recentHeartRates)
        if (sample.isFinite && sample > 0)
          calculateHrScore(
            heartRate: sample,
            baselineHeartRate: baselineHeartRate!,
          ),
  ];

  final withinThirtyMinutes =
      timeSinceActivity != null &&
      !timeSinceActivity.isNegative &&
      timeSinceActivity <= const Duration(minutes: 30);
  final postActivityRecovery =
      timeSinceActivity != null &&
      timeSinceActivity > const Duration(minutes: 30) &&
      timeSinceActivity <= const Duration(minutes: 90);
  final confidence = calculateConfidence(
    mode: mode,
    baselineDays: math.max(0, baselineDays),
    recentHrSampleCount: recentScores.length,
    hasTodayRhr: todayRestingHeartRate != null,
    hasLastNightSleep: lastNightSleepMinutes != null,
    isPostActivityRecovery: postActivityRecovery,
    hasTemperatureAnomaly: hasTemperatureAnomaly,
  );

  if (isActivity || withinThirtyMinutes) {
    return StressEstimate(
      stress: null,
      confidence: confidence,
      mode: mode,
      level: StressLevel.stable,
      isActivityFiltered: true,
      reason: '活动中，暂不判断压力状态',
    );
  }
  if (heartRate == null ||
      !heartRate.isFinite ||
      heartRate <= 0 ||
      _validBaseline(baselineHeartRate) == null) {
    return StressEstimate(
      stress: null,
      confidence: confidence,
      mode: mode,
      level: StressLevel.stable,
      isActivityFiltered: false,
      reason: '数据不足：缺少有效心率或个人心率基线',
    );
  }

  final hrScore = calculateHrScore(
    heartRate: heartRate,
    baselineHeartRate: baselineHeartRate!,
  );
  final acute = mode == StressDataMode.fullHrv
      ? calculateAcuteStressWithHrv(
          hrScore: hrScore,
          hrvScore: calculateHrvScore(hrv: hrv!, baselineHrv: baselineHrv!),
        )
      : calculateAcuteStressWithoutHrv(
          hrScore: hrScore,
          recentHrScores: recentScores,
        );
  final rhrScore =
      todayRestingHeartRate != null &&
          _validBaseline(baselineRestingHeartRate) != null
      ? calculateRhrScore(
          restingHeartRate: todayRestingHeartRate,
          baselineRestingHeartRate: baselineRestingHeartRate!,
        )
      : null;
  final sleepScore =
      lastNightSleepMinutes != null &&
          _validBaseline(baselineSleepMinutes) != null
      ? calculateSleepScore(
          sleepMinutes: lastNightSleepMinutes,
          baselineSleepMinutes: baselineSleepMinutes!,
        )
      : null;
  final recovery = calculateRecoveryLoad(
    rhrScore: rhrScore,
    sleepScore: sleepScore,
  );
  final stress = calculateFinalStress(
    acuteStress: acute,
    recoveryLoad: recovery,
  );
  final reasons = <String>[
    mode == StressDataMode.fullHrv ? 'HRV + 心率完整模式' : '无 HRV 降级模式',
    if (postActivityRecovery) '运动后恢复期，可信度已降低',
    if (hasTemperatureAnomaly) '身体指标与近期状态存在较大差异',
  ];
  return StressEstimate(
    stress: stress,
    confidence: confidence,
    mode: mode,
    level: stressLevelFor(stress),
    isActivityFiltered: false,
    reason: reasons.join(' · '),
  );
}
