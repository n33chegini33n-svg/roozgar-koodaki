import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'parent_sections.dart' show SectionScaffold, softCard;

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    const plan = [
      ['شنبه', 'قرآن', 'ریاضی', 'نقاشی'],
      ['یکشنبه', 'نوشتن', 'بازی گروهی', 'قصه‌گویی'],
      ['دوشنبه', 'علوم', 'ریاضی', 'ورزش'],
      ['سه‌شنبه', 'نوشتن', 'هنر', 'موسیقی'],
      ['چهارشنبه', 'قصه‌گویی', 'ریاضی', 'بازی آزاد'],
    ];
    return SectionScaffold(
      title: 'برنامهٔ هفتگی',
      image: 'ill_calendar.png',
      child: Column(
        children: [
          for (final p in plan)
            softCard(
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(p[0], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                  ),
                  for (int i = 1; i < p.length; i++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: [const Color(0xFFE3F2FD), const Color(0xFFFFF3CD), const Color(0xFFE6F7EF)][i - 1],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(p[i], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

