import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rooozgarkooodaki/models/permissions.dart';
import 'package:rooozgarkooodaki/parent/parent_home_page.dart';

void main() {
  testWidgets('والد خلاصهٔ روزانه و شاخص‌های اصلی را می‌بیند', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Session.reset();
    Session.role = AppRole.parent;
    Session.userName = 'ولی';
    Session.childName = 'فرزند آزمایشی';
    Session.className = 'کلاس الف';
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: ParentHomePage(onOpenTab: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('خلاصهٔ امروز'), findsOneWidget);
    expect(find.text('امروز'), findsOneWidget);
    expect(find.text('منوی امروز'), findsOneWidget);
    expect(find.text('اطلاعیه'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
