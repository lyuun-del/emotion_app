import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodland/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  testWidgets('record mood opens mood selection page', (tester) async {
    await tester.pumpWidget(
      const MoodStressApp(enableHighFidelityIsland: false),
    );

    await tester.tap(find.text('心情'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('选择心情'), findsOneWidget);
    expect(find.text('开心'), findsOneWidget);
    expect(find.text('平静'), findsOneWidget);
    expect(find.text('焦虑'), findsOneWidget);
  });

  testWidgets('island mode toggle switches between day and night', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MoodStressApp(enableHighFidelityIsland: false),
    );

    expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.wb_sunny_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('白昼'), findsOneWidget);
    expect(find.text('黑夜'), findsOneWidget);

    await tester.tap(find.text('黑夜'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
  });

  testWidgets('selected mood updates status pill icon', (tester) async {
    await tester.pumpWidget(
      const MoodStressApp(enableHighFidelityIsland: false),
    );

    expect(find.byIcon(Icons.self_improvement_outlined), findsOneWidget);

    await tester.tap(find.text('心情'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('开心'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('轻微紧绷'), findsOneWidget);
    expect(
      find.byIcon(Icons.sentiment_very_satisfied_outlined),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.self_improvement_outlined), findsNothing);
  });
}
