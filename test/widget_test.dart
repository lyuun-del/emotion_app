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
    expect(find.text('恢复建议'), findsOneWidget);
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

  testWidgets('deepseek chat page starts a new conversation', (tester) async {
    SharedPreferences.setMockInitialValues({
      'lighthouse_deepseek_chat_history': '[{"role":"user","content":"旧消息"}]',
    });

    await tester.pumpWidget(const MaterialApp(home: DeepSeekChatPage()));
    await tester.pump();

    expect(find.text('旧消息'), findsOneWidget);

    await tester.tap(find.byTooltip('开启新对话'));
    await tester.pump();

    expect(find.text('旧消息'), findsNothing);
    expect(find.text('你好，我是灯塔里的 moodland 助手。今天想聊些什么？'), findsOneWidget);
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

    await tester.tap(find.byTooltip('开启新对话'));
    await tester.pump();
    await tester.tap(find.byTooltip('查看旧对话'));
    await tester.pumpAndSettle();

    expect(find.text('旧对话'), findsOneWidget);
    expect(find.textContaining('1 条消息'), findsWidgets);

    await tester.tap(find.byTooltip('删除对话').last);
    await tester.pumpAndSettle();

    expect(find.text('旧对话'), findsNothing);
  });
}
