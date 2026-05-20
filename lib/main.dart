import 'package:flutter/material.dart';

void main() {
  runApp(const MoodStressApp());
}

class MoodStressApp extends StatelessWidget {
  const MoodStressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mood Stress',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF79A88D),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      home: const StressHomePage(),
    );
  }
}

class StressHomePage extends StatefulWidget {
  const StressHomePage({super.key});

  @override
  State<StressHomePage> createState() => _StressHomePageState();
}

class _StressHomePageState extends State<StressHomePage> {
  double _stressValue = 38;

  StressProfile get _profile => StressProfile.fromValue(_stressValue);

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      backgroundColor: profile.baseColor,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 550),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.55),
            radius: 1.25,
            colors: [
              profile.hazeColor.withValues(alpha: 0.82),
              profile.baseColor,
              const Color(0xFFFFFBF4),
            ],
            stops: const [0, 0.58, 1],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 20 : 32,
                  vertical: 18,
                ),
                child: Column(
                  children: [
                    _HomeHeader(profile: profile),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: _StressCenter(
                            profile: profile,
                            value: _stressValue,
                          ),
                        ),
                      ),
                    ),
                    _StressSlider(
                      value: _stressValue,
                      activeColor: profile.accentColor,
                      onChanged: (value) {
                        setState(() => _stressValue = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    _SupportCard(profile: profile),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.profile});

  final StressProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '今日压力',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF24302A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Apple Watch 已同步 2 分钟前',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF68746D),
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: '上传情绪',
          onPressed: () {},
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.72),
            foregroundColor: profile.accentColor,
          ),
          icon: const Icon(Icons.add_photo_alternate_outlined),
        ),
      ],
    );
  }
}

class _StressCenter extends StatelessWidget {
  const _StressCenter({required this.profile, required this.value});

  final StressProfile profile;
  final double value;

  @override
  Widget build(BuildContext context) {
    final roundedValue = value.round();

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusPill(profile: profile),
          const SizedBox(height: 16),
          Semantics(
            label: '当前压力值 $roundedValue',
            child: _StressPillWindow(
              profile: profile,
              roundedValue: roundedValue,
            ),
          ),
          const SizedBox(height: 18),
          _RecordMoodButton(profile: profile),
        ],
      ),
    );
  }
}

class _StressPillWindow extends StatelessWidget {
  const _StressPillWindow({required this.profile, required this.roundedValue});

  final StressProfile profile;
  final int roundedValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 228,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.62),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.92),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: profile.accentColor.withValues(alpha: 0.18),
            blurRadius: 38,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            child: MoodIllustration(
              key: ValueKey(profile.imageIndex),
              profile: profile,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.86),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.96),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$roundedValue',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1F2A24),
                  ),
                ),
                Text(
                  '压力值',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF68746D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.profile});

  final StressProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(profile.icon, size: 18, color: profile.accentColor),
          const SizedBox(width: 8),
          Text(
            profile.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF2C352F),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordMoodButton extends StatelessWidget {
  const _RecordMoodButton({required this.profile});

  final StressProfile profile;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: () {},
      icon: const Icon(Icons.add, size: 20),
      label: const Text('记录当前心情'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.74),
        foregroundColor: profile.accentColor,
        textStyle: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: const StadiumBorder(),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
      ),
    );
  }
}

class _StressSlider extends StatelessWidget {
  const _StressSlider({
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final double value;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: activeColor,
          inactiveTrackColor: Colors.white.withValues(alpha: 0.72),
          thumbColor: Colors.white,
          overlayColor: activeColor.withValues(alpha: 0.14),
          trackHeight: 8,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 13),
        ),
        child: Slider(
          min: 0,
          max: 100,
          divisions: 100,
          value: value,
          label: value.round().toString(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.profile});

  final StressProfile profile;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: profile.accentColor.withValues(alpha: 0.14),
              ),
              child: Icon(
                Icons.psychology_alt_outlined,
                color: profile.accentColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '恢复建议',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF25312B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.suggestion,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5D6961),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MoodIllustration extends StatelessWidget {
  const MoodIllustration({super.key, required this.profile});

  final StressProfile profile;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 154,
      child: ClipOval(
        child: Image.asset(
          profile.imageAsset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class StressProfile {
  const StressProfile({
    required this.label,
    required this.suggestion,
    required this.baseColor,
    required this.hazeColor,
    required this.accentColor,
    required this.imageAsset,
    required this.imageIndex,
    required this.icon,
  });

  final String label;
  final String suggestion;
  final Color baseColor;
  final Color hazeColor;
  final Color accentColor;
  final String imageAsset;
  final int imageIndex;
  final IconData icon;

  static StressProfile fromValue(double value) {
    if (value < 35) {
      return const StressProfile(
        label: '平稳放松',
        suggestion: '保持当前节奏，做一次 4 分钟轻呼吸，让身体继续停在舒服区间。',
        baseColor: Color(0xFFF7FFF8),
        hazeColor: Color(0xFFD7F4DB),
        accentColor: Color(0xFF5C9B72),
        imageAsset: 'assets/images/mood_0.jpg',
        imageIndex: 0,
        icon: Icons.spa_outlined,
      );
    }
    if (value < 55) {
      return const StressProfile(
        label: '轻微紧绷',
        suggestion: '离开屏幕半分钟，喝水并放慢呼吸，先把注意力带回身体。',
        baseColor: Color(0xFFFFFCF4),
        hazeColor: Color(0xFFEAD4A6),
        accentColor: Color(0xFFA77A31),
        imageAsset: 'assets/images/mood_1.jpg',
        imageIndex: 1,
        icon: Icons.self_improvement_outlined,
      );
    }
    if (value < 75) {
      return const StressProfile(
        label: '压力偏高',
        suggestion: '暂停当前任务，试一次 4-7-8 呼吸；如果可以，站起来慢走 3 分钟。',
        baseColor: Color(0xFFFFF8F6),
        hazeColor: Color(0xFFFFC7BC),
        accentColor: Color(0xFFD36C5A),
        imageAsset: 'assets/images/mood_2.jpg',
        imageIndex: 2,
        icon: Icons.favorite_border,
      );
    }
    return const StressProfile(
      label: '需要恢复',
      suggestion: '先降低刺激源：摘下耳机、远离通知，给自己 10 分钟完整休息。',
      baseColor: Color(0xFFFFF7F6),
      hazeColor: Color(0xFFFFB7B0),
      accentColor: Color(0xFFBE514A),
      imageAsset: 'assets/images/mood_3.jpg',
      imageIndex: 3,
      icon: Icons.health_and_safety_outlined,
    );
  }
}
