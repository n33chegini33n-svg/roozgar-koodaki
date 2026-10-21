import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:rooozgarkooodaki/main.dart';

void main() {
  testWidgets('Welcome screen renders the real app entry point', (WidgetTester tester) async {
    await tester.pumpWidget(const RoozgarKoodakiApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('با هم می‌درخشیم'), findsOneWidget);
    expect(
      find.text('شمارهٔ موبایلی که مدرسه برای شما ثبت کرده را وارد کنید'),
      findsOneWidget,
    );
    expect(find.text('ادامه'), findsOneWidget);
  });
}
