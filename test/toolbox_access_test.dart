import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rooozgarkooodaki/models/permissions.dart';
import 'package:rooozgarkooodaki/pages/ai_assistant_page.dart';
import 'package:rooozgarkooodaki/pages/toolbox_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Session.reset();
  });

  testWidgets('والد ابزارهای عمومی را می‌بیند و دستیار را نمی‌بیند', (tester) async {
    Session.role = AppRole.parent;
    await tester.pumpWidget(const MaterialApp(home: ToolboxPage()));

    expect(find.text('مبدل‌ها'), findsOneWidget);
    expect(find.text('دفترچه یادداشت'), findsOneWidget);
    expect(find.text('ماشین‌حساب مهندسی'), findsOneWidget);
    expect(find.text('دستیار هوشمند'), findsNothing);
    expect(find.text('ابزارهای کلاس'), findsNothing);
  });

  testWidgets('دانش‌آموز دستیار کادر مدرسه را در جعبه ابزار نمی‌بیند', (tester) async {
    Session.role = AppRole.student;
    await tester.pumpWidget(const MaterialApp(home: ToolboxPage()));

    expect(find.text('دستیار هوشمند'), findsNothing);
  });

  testWidgets('معلم دستیار و ابزارهای کلاس را می‌بیند', (tester) async {
    Session.role = AppRole.teacher;
    await tester.pumpWidget(
      MaterialApp(home: ToolboxPage(classTools: (_) => const SizedBox.shrink())),
    );

    expect(find.text('دستیار هوشمند'), findsOneWidget);
    expect(find.text('ابزارهای کلاس'), findsOneWidget);
  });

  testWidgets('صفحهٔ دستیار ورود مستقیم دانش‌آموز را هم مسدود می‌کند', (tester) async {
    Session.role = AppRole.student;
    await tester.pumpWidget(const MaterialApp(home: AiAssistantPage()));
    await tester.pump();

    expect(find.text('این ابزار فقط برای کادر مدرسه است.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
