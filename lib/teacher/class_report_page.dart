import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../parent/parent_sections.dart' show SectionScaffold, softCard;
import '../utils/export_helper.dart';

class ClassReportPage extends StatelessWidget {
  const ClassReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'گزارش کلاس',
      image: 'scene_report.png',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                onPressed: () {
                  ExportHelper.exportToExcel(
                    context: context,
                    title: 'گزارش ارزیابی و عملکرد کلاس',
                    headers: ['شاخص عملکرد', 'وضعیت کلاس'],
                    rows: [
                      ['میانگین انضباط', 'عالی (۹۵٪)'],
                      ['پیشرفت تحصیلی', 'بسیار خوب'],
                      ['فعالیت‌های گروهی', 'فعال'],
                    ],
                    fileName: 'class_report_${DateTime.now().millisecondsSinceEpoch}',
                  );
                },
                icon: const Icon(Icons.table_chart_rounded, size: 16),
                label: const Text('اکسل'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                onPressed: () {
                  ExportHelper.exportToPdf(
                    context: context,
                    title: 'گزارش رسمی عملکرد کلاس',
                    headers: ['شاخص عملکرد', 'وضعیت کلاس'],
                    rows: [
                      ['میانگین انضباط', 'عالی (۹۵٪)'],
                      ['پیشرفت تحصیلی', 'بسیار خوب'],
                      ['فعالیت‌های گروهی', 'فعال'],
                    ],
                    fileName: 'class_report_${DateTime.now().millisecondsSinceEpoch}',
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text('PDF'),
              ),
              /*print*/
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade700, foregroundColor: Colors.white),
                onPressed: () {
                  ExportHelper.printTable(
                    context: context,
                    title: 'گزارش رسمی عملکرد کلاس',
                    headers: ['شاخص عملکرد', 'وضعیت کلاس'],
                    rows: [
                      ['میانگین انضباط', 'عالی (۹۵٪)'],
                      ['پیشرفت تحصیلی', 'بسیار خوب'],
                      ['فعالیت‌های گروهی', 'فعال'],
                    ],
                    fileName: 'class_report_${DateTime.now().millisecondsSinceEpoch}',
                  );
                },
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('چاپ'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          softCard(
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('گزارش ماهیانه عملکرد کلاس پیش‌دبستانی آفتاب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                SizedBox(height: 8),
                Text('• میانگین حضور دانش‌آموزان: ۹۶٪\n• مشارکت در تکالیف گروهی: فوق‌العاده\n• انضباط و نظم عمومی کلاس: عالی', style: TextStyle(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
