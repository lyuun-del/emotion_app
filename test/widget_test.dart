import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodland/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'new_user_questions_completed': true,
      'home_guide_completed': true,
    });
  });

  test('future intent parser extracts an exact reminder draft', () {
    final draft = FlowerLetterIntentParser.parse(
      '明天下午3点提醒我交报告',
      now: DateTime(2026, 8, 29, 10),
    );

    expect(draft, isNotNull);
    expect(draft!.scheduledAt, DateTime(2026, 8, 30, 15));
    expect(draft.event, contains('交报告'));
    expect(
      FlowerLetterIntentParser.parse('今天心情有点乱', now: DateTime(2026, 8, 29, 10)),
      isNull,
    );
  });

  testWidgets('stress home renders current status', (tester) async {
    await tester.pumpWidget(
      const MoodStressApp(enableHighFidelityIsland: false),
    );

    expect(find.text('MoodLand'), findsOneWidget);
    expect(find.text('38'), findsOneWidget);
    expect(find.text('略有波动'), findsOneWidget);
    expect(find.byTooltip('新手指引'), findsOneWidget);
    expect(find.byTooltip('个人中心'), findsOneWidget);
    expect(find.text('恢复建议'), findsOneWidget);
  });

  testWidgets('home profile button opens user center', (tester) async {
    await tester.pumpWidget(
      const MoodStressApp(enableHighFidelityIsland: false),
    );

    await tester.tap(find.byTooltip('个人中心'));
    await tester.pumpAndSettle();

    expect(find.text('我的主页'), findsOneWidget);
    expect(find.text('编辑个人资料'), findsOneWidget);
  });

  testWidgets('stress home opens recovery advice detail', (tester) async {
    await tester.pumpWidget(
      const MoodStressApp(enableHighFidelityIsland: false),
    );

    await tester.tap(find.text('恢复建议'));
    await tester.pumpAndSettle();

    expect(find.text('可行的恢复建议'), findsOneWidget);
    expect(find.text('当前压力值 38'), findsOneWidget);
    expect(find.text('离开屏幕看远处'), findsOneWidget);
    expect(find.text('和灯塔对话'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('和灯塔对话'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('和灯塔对话'));
    await tester.pumpAndSettle();

    expect(find.text('灯塔对话'), findsOneWidget);
    expect(find.byTooltip('新对话'), findsOneWidget);
  });

  testWidgets('stress value opens metric detail', (tester) async {
    await tester.pumpWidget(
      const MoodStressApp(enableHighFidelityIsland: false),
    );

    await tester.tap(find.text('压力值'));
    await tester.pumpAndSettle();

    expect(find.text('时间范围'), findsOneWidget);
    expect(find.text('显示精度'), findsNothing);
    expect(find.text('精细'), findsOneWidget);
    expect(find.text('当天 0点-24点 · 每 1 小时'), findsOneWidget);
  });

  testWidgets('stress home can open home guide overlay', (tester) async {
    await tester.pumpWidget(
      const MoodStressApp(enableHighFidelityIsland: false),
    );

    await tester.tap(find.byTooltip('新手指引'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('欢迎来到 MoodLand'), findsOneWidget);
    expect(find.textContaining('压力值、健康数据、情绪记录和灯塔对话'), findsOneWidget);

    await tester.tap(find.text('下一步'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('灯塔'), findsOneWidget);
    expect(find.textContaining('点这里进入灯塔对话'), findsOneWidget);
    expect(find.text('新手问题'), findsNothing);
  });

  testWidgets('first launch shows app overview guide before questions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MoodStressApp(enableHighFidelityIsland: false),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('欢迎来到 MoodLand'), findsOneWidget);
    expect(find.textContaining('这里会把压力值'), findsOneWidget);
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

    expect(find.text('100'), findsOneWidget);
    expect(find.text('明显紧绷'), findsOneWidget);
    expect(find.textContaining('测试数据 · 压力偏高'), findsOneWidget);

    await tester.tap(find.text('使用测试数据'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final recoverySample = find.text('需要恢复').last;
    await tester.ensureVisible(recoverySample);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(recoverySample);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('100'), findsOneWidget);
    expect(find.text('明显紧绷'), findsOneWidget);
    expect(find.textContaining('测试数据 · 需要恢复'), findsOneWidget);
  });

  testWidgets('flower reminder page saves a reminder', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FlowerReminderPage()));

    expect(find.text('花时来信'), findsOneWidget);
    expect(find.text('每天'), findsOneWidget);
    expect(find.text('工作日'), findsOneWidget);
    expect(find.text('自定义'), findsOneWidget);
    expect(find.text('先选择提醒方向'), findsOneWidget);
    expect(find.text('再选择具体提醒事项'), findsOneWidget);

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

  testWidgets('flower reminder can schedule a garden check-in', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FlowerReminderPage()));

    expect(find.text('提醒我选一朵花'), findsOneWidget);
    final gardenSwitch = find.byType(Switch).first;
    await tester.ensureVisible(gardenSwitch);
    await tester.pump();
    await tester.tap(gardenSwitch);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('保存提醒'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('保存提醒'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 150));
    await tester.pump();
    await tester.tap(find.text('保存提醒'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString('flower_reminders')!) as List;
    expect((stored.first as Map)['opensGarden'], isTrue);
    expect((stored.first as Map)['event'], '选一朵今日心情花');
    expect((stored.first as Map)['hour'], 21);
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
    'flower reminder explains scheduled and stress-triggered letters',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FlowerReminderPage()));

      await tester.scrollUntilVisible(
        find.text('来信会怎样抵达'),
        350,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('你种下的提醒'), findsOneWidget);
      expect(find.text('身体状态的来信'), findsOneWidget);
      expect(find.textContaining('压力状态出现明显变化'), findsOneWidget);
    },
  );

  testWidgets('lighthouse can draft a letter from recent garden history', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'garden_selection_history': jsonEncode([
        {
          'id': 'garden-record-1',
          'flowerName': '铃兰',
          'mood': '低落',
          'meaning': '想哭就哭吧。',
          'message': '灯塔先陪你安静一会儿。',
          'createdAt': '2026-05-29T09:30:00.000',
        },
      ]),
    });
    await tester.pumpWidget(const MaterialApp(home: FlowerReminderPage()));

    await tester.tap(find.text('灯塔帮我写'));
    await tester.pumpAndSettle();

    expect(find.text('灯塔写了三封短信'), findsOneWidget);
    expect(find.textContaining('铃兰'), findsWidgets);
  });

  testWidgets('opening and responding to a flower letter updates its status', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'flower_reminders': jsonEncode([
        {
          'id': 'letter-1',
          'event': '给未来的我',
          'category': '情绪赋能',
          'subcategory': '自我肯定',
          'message': '今天也可以慢慢来。',
          'frequency': '仅一次',
          'weekdays': <int>[],
          'hour': 9,
          'minute': 0,
          'createdAt': '2026-05-29T09:30:00.000',
          'source': 'garden',
          'flowerName': '铃兰',
          'mood': '低落',
        },
      ]),
    });

    await tester.pumpWidget(
      const MaterialApp(home: FlowerLetterReceiptPage(reminderId: 'letter-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天也可以慢慢来。'), findsOneWidget);
    expect(find.text('记录此刻心情'), findsOneWidget);
    expect(find.text('和灯塔聊聊'), findsOneWidget);

    await tester.tap(find.text('和灯塔聊聊'));
    await tester.pumpAndSettle();
    expect(find.text('灯塔对话'), findsOneWidget);
    expect(find.textContaining('我收到了一封花时来信'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString('flower_reminders')!) as List;
    expect((stored.first as Map)['deliveredAt'], isNotNull);
    expect((stored.first as Map)['respondedAt'], isNotNull);
  });

  testWidgets('legacy daily reminder uses the new receipt actions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'flower_reminders': jsonEncode([
        {
          'id': 'legacy-reminder-1',
          'event': '喝水',
          'category': '生活小事',
          'subcategory': '喝水',
          'message': '喝口水，让身体慢慢舒展开。',
          'frequency': '每天',
          'weekdays': <int>[],
          'hour': 9,
          'minute': 0,
          'createdAt': '2026-05-29T09:30:00.000',
        },
      ]),
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: FlowerLetterReceiptPage(reminderId: 'legacy-reminder-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('喝水提醒到了'), findsOneWidget);
    expect(find.text('日常提醒 · 每天'), findsOneWidget);
    expect(find.text('我完成了'), findsOneWidget);
    expect(find.text('10 分钟后再提醒'), findsOneWidget);
    expect(find.text('记录此刻心情'), findsOneWidget);
    expect(find.text('和灯塔聊聊'), findsOneWidget);

    await tester.tap(find.text('我完成了'));
    await tester.pump();
    expect(find.text('收到，灯塔替你记下了。'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString('flower_reminders')!) as List;
    expect((stored.first as Map)['source'], 'reminder');
    expect((stored.first as Map)['deliveredAt'], isNotNull);
    expect((stored.first as Map)['respondedAt'], isNotNull);
  });

  testWidgets('stress-triggered letter opens its recovery advice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'flower_reminders': jsonEncode([
        {
          'id': 'stress-letter-1',
          'event': '轻微紧绷 → 需要恢复',
          'category': '身体状态',
          'subcategory': '需要恢复',
          'message': '当前压力 82% · 身体正在提醒你先停一下。',
          'frequency': '仅一次',
          'weekdays': <int>[],
          'hour': 15,
          'minute': 0,
          'createdAt': '2026-08-29T15:00:00.000',
          'source': 'stress',
          'stressValue': 82,
          'stressTransitionMessage': '身体正在提醒你先停一下。',
        },
      ]),
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: FlowerLetterReceiptPage(reminderId: 'stress-letter-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('身体状态发生了变化'), findsOneWidget);
    expect(find.text('身体状态 · 仅一次'), findsOneWidget);
    expect(find.text('查看此刻的恢复建议'), findsOneWidget);

    await tester.tap(find.text('查看此刻的恢复建议'));
    await tester.pumpAndSettle();
    expect(find.text('当前压力值 82'), findsOneWidget);
    expect(find.text('恢复建议'), findsWidgets);
  });

  testWidgets('conversation draft is saved only after user confirmation', (
    tester,
  ) async {
    final scheduledAt = DateTime.now().add(const Duration(days: 1));
    await tester.pumpWidget(
      MaterialApp(
        home: DeepSeekChatPage(
          initialReminderDraft: FlowerLetterDraft(
            event: '交报告',
            message: '报告时间快到了，先从眼前最小的一步开始。',
            scheduledAt: scheduledAt,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('要让灯塔在那个时候'), findsOneWidget);
    expect(find.text('收下这封信'), findsOneWidget);
    expect(find.text('改一改'), findsOneWidget);
    expect(find.text('不用了'), findsOneWidget);

    await tester.tap(find.text('收下这封信'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString('flower_reminders')!) as List;
    expect(stored, hasLength(1));
    expect((stored.first as Map)['source'], 'chat');
    expect((stored.first as Map)['scheduledAt'], isNotNull);
    expect(find.textContaining('这封来信已'), findsOneWidget);
  });

  testWidgets('garden page shows flower selection history', (tester) async {
    SharedPreferences.setMockInitialValues({
      'new_user_questions_completed': true,
      'home_guide_completed': true,
      'selected_garden_flower_name': '铃兰',
      'garden_selection_history': jsonEncode([
        {
          'id': '1',
          'flowerName': '铃兰',
          'mood': '低落',
          'meaning': '想哭就哭吧，你的眼泪和你的笑容一样珍贵。',
          'message': '灯塔把这朵铃兰放在窗边，先陪你安静一会儿。',
          'createdAt': '2026-05-29T09:30:00.000',
        },
      ]),
    });

    await tester.pumpWidget(const MaterialApp(home: MyGardenPage()));
    await tester.pumpAndSettle();

    expect(find.text('我的花园'), findsOneWidget);
    expect(find.text('低落 · 铃兰'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('选择历史'),
      260,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('选择历史'), findsOneWidget);
    expect(find.text('灯塔回信'), findsOneWidget);
    expect(find.text('灯塔把这朵铃兰放在窗边，先陪你安静一会儿。'), findsWidgets);
  });

  testWidgets('garden can send the latest flower to a future self', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'selected_garden_flower_name': '铃兰',
      'garden_selection_history': jsonEncode([
        {
          'id': 'garden-record-1',
          'flowerName': '铃兰',
          'mood': '低落',
          'meaning': '想哭就哭吧。',
          'message': '灯塔先陪你安静一会儿。',
          'createdAt': '2026-05-29T09:30:00.000',
        },
      ]),
    });

    await tester.pumpWidget(const MaterialApp(home: MyGardenPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('把这朵花寄给未来的我'));
    await tester.pumpAndSettle();

    expect(find.text('花时来信'), findsOneWidget);
    expect(find.text('灯塔先陪你安静一会儿。'), findsOneWidget);
    expect(find.text('一次'), findsOneWidget);
  });

  testWidgets('garden reply opens lighthouse chat with flower context', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'new_user_questions_completed': true,
      'home_guide_completed': true,
      'selected_garden_flower_name': '铃兰',
      'garden_selection_history': jsonEncode([
        {
          'id': 'garden-record-1',
          'flowerName': '铃兰',
          'mood': '低落',
          'meaning': '想哭就哭吧，你的眼泪和你的笑容一样珍贵。',
          'message': '灯塔把这朵铃兰放在窗边，先陪你安静一会儿。',
          'createdAt': '2026-05-29T09:30:00.000',
        },
      ]),
    });

    await tester.pumpWidget(const MaterialApp(home: MyGardenPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('灯塔把这朵铃兰放在窗边，先陪你安静一会儿。').first);
    await tester.pumpAndSettle();

    expect(find.text('灯塔对话'), findsOneWidget);
    expect(find.text('我的情绪状态：低落\n对应的花：铃兰'), findsOneWidget);
    expect(find.text('灯塔把这朵铃兰放在窗边，先陪你安静一会儿。'), findsOneWidget);
  });

  testWidgets('wooden house opens health dashboard and manual entry page', (
    tester,
  ) async {
    final estimate = const HealthStressEstimator().sampleEstimate(
      HealthStressEstimator.samples[2],
    );

    await tester.pumpWidget(
      MaterialApp(home: HealthDataDashboardPage(currentEstimate: estimate)),
    );

    expect(find.text('健康数据详情'), findsOneWidget);
    expect(find.text('当前压力趋势'), findsOneWidget);
    expect(find.byTooltip('手动记录'), findsOneWidget);
    expect(find.text('压力值'), findsOneWidget);
    expect(find.text('心率'), findsOneWidget);
    expect(find.text('暂无'), findsWidgets);
    expect(find.text('暂无真实数据'), findsWidgets);

    await tester.tap(find.text('压力值').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('时间范围'), findsOneWidget);
    expect(find.text('显示精度'), findsNothing);
    expect(find.text('当天 0点-24点 · 每 1 小时'), findsOneWidget);

    await tester.tap(find.text('月'));
    await tester.pump();
    await tester.tap(find.text('精细'));
    await tester.pump();

    expect(find.text('当天 0点-24点 · 每 10 分钟'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('HRV'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('HRV'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('睡眠'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('睡眠'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('步数'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('步数'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_note_rounded));
    await tester.pumpAndSettle();

    expect(find.text('手动记录'), findsOneWidget);
    expect(find.text('最近的心率 HR'), findsOneWidget);
    expect(find.text('当前 HRV'), findsOneWidget);
  });

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

    await tester.scrollUntilVisible(
      find.text('灯塔头像'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('灯塔头像'), findsOneWidget);
    expect(find.text('更改'), findsOneWidget);
    expect(find.text('恢复默认'), findsOneWidget);
  });

  testWidgets('user page can edit profile name and bio', (tester) async {
    SharedPreferences.setMockInitialValues({
      'new_user_questions_completed': true,
    });

    await tester.pumpWidget(
      const MaterialApp(home: UserHomePage(currentEstimate: null)),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('编辑个人资料'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '名字'), '小鹿');
    await tester.enterText(find.widgetWithText(TextField, '个人信息'), '喜欢安静地恢复能量');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('小鹿'), findsOneWidget);
    expect(find.text('喜欢安静地恢复能量'), findsOneWidget);
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
    expect(find.text('先让 MoodLand 认识一下你。'), findsOneWidget);
  });

  testWidgets('user page opens HRV baseline settings with recommendation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'new_user_questions_completed': true,
      'recommended_hrv_baseline': 62.0,
      'recommended_hrv_sample_count': 20,
    });

    await tester.pumpWidget(
      const MaterialApp(home: UserHomePage(currentEstimate: null)),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('HRV 基线'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HRV 基线'));
    await tester.pumpAndSettle();

    expect(find.text('推荐 HRV 基线值'), findsOneWidget);
    expect(find.text('62.0 ms'), findsOneWidget);
    expect(find.text('自动'), findsOneWidget);
    expect(find.text('自定义'), findsOneWidget);
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
