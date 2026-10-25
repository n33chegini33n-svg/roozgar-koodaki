import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../parent/parent_sections.dart';

export 'teacher_attendance_page.dart';
export 'teacher_homework_page.dart';
export 'teacher_announce_page.dart';
export 'class_report_page.dart';


/// قاب ساده برای صفحه‌هایی که خودشان اسکرول دارند
class PageHost extends StatelessWidget {
  final String title;
  final Widget child;
  const PageHost({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: SafeArea(child: child),
    );
  }
}
