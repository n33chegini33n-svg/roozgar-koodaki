import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import '../services/backend.dart';
import 'parent_home_page.dart';

/// قاب اصلی بخش ولی: نوار پایین + صفحه‌ها
class ParentShell extends StatefulWidget {
  final WidgetBuilder chatBuilder;
  final WidgetBuilder storyBuilder;
  final WidgetBuilder progressBuilder;

  const ParentShell({
    super.key,
    required this.chatBuilder,
    required this.storyBuilder,
    required this.progressBuilder,
  });

  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  int _index = 0;
  static const List<String> _titles = [
    'روزگار کودکی',
    'پیام‌ها',
    'داستان کلاس',
    'پیشرفت کودک',
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ParentHomePage(onOpenTab: (i) => setState(() => _index = i)),
      widget.chatBuilder(context),
      widget.storyBuilder(context),
      widget.progressBuilder(context),
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
