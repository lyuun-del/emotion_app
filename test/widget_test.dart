import 'package:flutter_test/flutter_test.dart';
import 'package:mood_stress_app/main.dart';

void main() {
  testWidgets('stress home renders current status', (tester) async {
    await tester.pumpWidget(const MoodStressApp());

    expect(find.text('今日压力'), findsOneWidget);
    expect(find.text('38'), findsOneWidget);
    expect(find.text('轻微紧绷'), findsOneWidget);
    expect(find.text('恢复建议'), findsOneWidget);
  });
}
