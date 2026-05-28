import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodland/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'new_user_questions_completed': true,
    });
  });

  testWidgets('stress home renders current status', (tester) async {
    await tester.pumpWidget(
      const MoodStressApp(enableHighFidelityIsland: false),
    );

    expect(find.text('moodland'), findsOneWidget);
    expect(find.text('38'), findsOneWidget);
    expect(find.text('轻微紧绷'), findsOneWidget);
    expect(find.byTooltip('新手指引'), findsOneWidget);
    expect(find.text('恢复建议'), findsOneWidget);
  });

  testWidgets('stress home can open home guide overlay', (tester) async {
    await tester.pumpWidget(
      const MoodStressApp(enableHighFidelityIsland: false),
    );

    await tester.tap(find.byTooltip('新手指引'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('灯塔'), findsOneWidget);
    expect(find.textContaining('点这里进入灯塔对话'), findsOneWidget);
    expect(find.text('新手问题'), findsNothing);
  });

  testWidgets('stress home can switch sample health data', (tester) async {
    await tester.pumpWidget(
      const MoodStressApp(enableHighFidelityIsland: false),
    );

    await tester.tap(find.text('使用测试数据'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('选择测试数据'), findsOneWidget);
    expect(find.text('平稳放松'), findsWidgets);
    expect(find.text('压力偏高'), findsWidgets);

    await tester.tap(find.text('压力偏高').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('73'), findsOneWidget);
    expect(find.text('压力偏高'), findsOneWidget);
    expect(find.textContaining('测试数据 · 压力偏高'), findsOneWidget);

    await tester.tap(find.text('使用测试数据'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('需要恢复').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('91'), findsOneWidget);
    expect(find.text('需要恢复'), findsOneWidget);
    expect(find.textContaining('测试数据 · 需要恢复'), findsOneWidget);
  });

  testWidgets('flower reminder page saves a reminder', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FlowerReminderPage()));

    expect(find.text('花时来信'), findsOneWidget);
    expect(find.text('每天'), findsOneWidget);
    expect(find.text('工作日'), findsOneWidget);
    expect(find.text('自定义'), findsOneWidget);
    expect(find.text('静待花开'), findsOneWidget);
    expect(find.text('晚上11点到早上7点，花会静静含苞，不打扰你休息。'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('保存提醒'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('保存提醒'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('喝水'), findsOneWidget);
    expect(find.text('花时来信已收好。'), findsOneWidget);
  });

  testWidgets('flower reminder reference table is grouped and collapsible', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FlowerReminderPage()));

    await tester.scrollUntilVisible(
      find.text('完整预设提醒语句速查表'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('展开查看全部分类语句'), findsOneWidget);
    expect(find.text('生活小事'), findsNothing);

    await tester.tap(find.text('完整预设提醒语句速查表'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('生活小事'), findsOneWidget);
    expect(find.text('14 条'), findsOneWidget);
    expect(find.text('喝水'), findsWidgets);
    expect(find.text('该喝口水啦。你比任何一朵花，都更需要水的滋养。'), findsOneWidget);
    expect(find.text('喝点水吧。身体里的每片叶子都在等这口水。'), findsOneWidget);
  });

  testWidgets(
    'wooden house opens health dashboard and avatar opens user page',
    (tester) async {
      final estimate = const HealthStressEstimator().sampleEstimate(
        HealthStressEstimator.samples[2],
      );

      await tester.pumpWidget(
        MaterialApp(home: HealthDataDashboardPage(currentEstimate: estimate)),
      );

      expect(find.text('健康数据详情'), findsOneWidget);
      expect(find.text('当前压力趋势'), findsOneWidget);
      expect(find.byTooltip('用户主页'), findsOneWidget);
      expect(find.text('心率'), findsOneWidget);
      expect(find.text('HRV'), findsOneWidget);
      expect(find.text('0点'), findsWidgets);

      await tester.tap(
        find
            .ancestor(of: find.text('心率'), matching: find.byType(InkWell))
            .first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('时间范围'), findsOneWidget);
      expect(find.text('显示精度'), findsOneWidget);
      expect(find.text('一天内 · 标准显示'), findsOneWidget);

      await tester.tap(find.text('月'));
      await tester.pump();
      await tester.tap(find.text('精细'));
      await tester.pump();

      expect(find.text('一个月内 · 精细显示'), findsOneWidget);

      await tester.tap(find.byTooltip('Back').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.scrollUntilVisible(
        find.text('睡眠'),
        220,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('睡眠'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('步数'),
        260,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('步数'), findsOneWidget);

      await tester.tap(find.byTooltip('用户主页'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('我的主页'), findsOneWidget);
      expect(find.text('个人信息'), findsOneWidget);
      expect(find.text('软件设置'), findsOneWidget);
      expect(find.text('灯塔头像'), findsOneWidget);
      expect(find.text('更改'), findsOneWidget);
      expect(find.text('新手问题'), findsOneWidget);
      expect(find.text('隐私与权限'), findsOneWidget);
      expect(find.text('本地数据'), findsOneWidget);
      expect(find.text('应用版本'), findsOneWidget);
      expect(find.byIcon(Icons.monitor_heart_rounded), findsNothing);
    },
  );

  testWidgets('user page can show restore default lighthouse avatar action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'new_user_questions_completed': true,
      'lighthouse_assistant_avatar_path': '/tmp/custom_lighthouse.png',
    });

    await tester.pumpWidget(
      const MaterialApp(home: UserHomePage(currentEstimate: null)),
    );
    await tester.pump();

    expect(find.text('灯塔头像'), findsOneWidget);
    expect(find.text('更改'), findsOneWidget);
    expect(find.text('恢复默认'), findsOneWidget);
  });

  testWidgets('user page can reopen new user questions from settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'new_user_questions_completed': true,
    });

    await tester.pumpWidget(
      const MaterialApp(home: UserHomePage(currentEstimate: null)),
    );
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pump();
    await tester.tap(find.text('新手问题'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('新手问题'), findsWidgets);
    expect(find.text('先让 moodland 认识一下你。'), findsOneWidget);
  });

  testWidgets('deepseek chat page starts a new conversation', (tester) async {
    final now = DateTime.now();
    final todayTitle = '${now.year}年${now.month}月${now.day}日';
    SharedPreferences.setMockInitialValues({
      'lighthouse_deepseek_chat_history': '[{"role":"user","content":"旧消息"}]',
    });

    await tester.pumpWidget(const MaterialApp(home: DeepSeekChatPage()));
    await tester.pump();

    expect(find.byTooltip('对话记录'), findsOneWidget);
    expect(find.byTooltip('新对话'), findsOneWidget);
    expect(find.text('对话记录'), findsNothing);
    expect(find.text('旧消息'), findsNothing);
    expect(find.text('你来了。我是灯塔，光还亮着。你慢慢说。'), findsOneWidget);

    await tester.tap(find.byTooltip('新对话'));
    await tester.pump();

    expect(find.text('旧消息'), findsNothing);
    expect(find.text('你来了。我是灯塔，光还亮着。你慢慢说。'), findsOneWidget);
    await tester.tap(find.byTooltip('对话记录'));
    await tester.pumpAndSettle();
    expect(find.text(todayTitle), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/lighthouse_lamp_avatar.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('deepseek chat page shows and deletes old conversations', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'lighthouse_deepseek_conversations':
          '[{"id":"old","title":"旧对话","updatedAt":"2026-05-26T10:00:00.000","messages":[{"role":"user","content":"旧消息"}]}]',
      'lighthouse_active_chat_conversation_id': 'old',
    });

    await tester.pumpWidget(const MaterialApp(home: DeepSeekChatPage()));
    await tester.pump();

    await tester.tap(find.byTooltip('新对话'));
    await tester.pump();
    await tester.tap(find.byTooltip('对话记录'));
    await tester.pumpAndSettle();

    expect(find.text('旧对话'), findsOneWidget);
    expect(find.textContaining('1 条消息'), findsWidgets);

    await tester.tap(find.byTooltip('删除对话').last);
    await tester.pumpAndSettle();

    expect(find.text('旧对话'), findsNothing);
  });
}
