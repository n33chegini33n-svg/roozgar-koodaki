import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import '../services/backend.dart';
import 'teacher_home_page.dart';

/// قاب اصلی بخش معلم: نوار پایین + صفحه‌ها
class TeacherShell extends StatefulWidget {
  final WidgetBuilder chatBuilder;
  final WidgetBuilder storyBuilder;
  final WidgetBuilder behaviorBuilder;
  final WidgetBuilder toolkitBuilder;

  const TeacherShell({
    super.key,
    required this.chatBuilder,
    required this.storyBuilder,
    required this.behaviorBuilder,
    required this.toolkitBuilder,
  });

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int _index = 0;
  static const List<String> _titles = [
    'روزگار کودکی',
    'پیام‌ها',
    'داستان کلاس',
    'امتیاز و رفتار',
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      TeacherHomePage(
        onOpenTab: (i) => setState(() => _index = i),
        toolkitBuilder: widget.toolkitBuilder,
      ),
      widget.chatBuilder(context),
      widget.storyBuilder(context),
      widget.behaviorBuilder(context),
    ];

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          leading: _index == 0
              ? null
              : BackButton(onPressed: () => setState(() => _index = 0)),
          title: Text(_titles[_index]),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.navy,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.power_settings_new_rounded),
              tooltip: 'خروج',
              onPressed: () async {
                await Backend.signOut();
                if (!context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => buildWelcome(),
                  ),
                );
              },
            ),
          ],
        ),
        body: IndexedStack(index: _index, children: pages),
        
      ),
    );
  }
}
