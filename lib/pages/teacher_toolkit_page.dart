import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'class_timer_dialog.dart';

class TeacherToolkitPage extends StatefulWidget {
  const TeacherToolkitPage({super.key});

  @override
  State<TeacherToolkitPage> createState() => _TeacherToolkitPageState();
}

class _TeacherToolkitPageState extends State<TeacherToolkitPage> {
  final List<String> studentList = [
    'آرتین شجاعی',
    'سارا محمدی',
    'علی احمدی',
    'مریم کریمی',
    'کارن رضایی'
  ];

  void _openRandomPicker() {
    String selectedStudent = '';
    bool isSpinning = false;
    Timer? spinTimer; // برای لغو تایمر هنگام بسته‌شدن دیالوگ

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.casino_rounded, color: Color(0xFF0288D1)),
                    SizedBox(width: 8),
                    Text('انتخاب‌گر تصادفی دانش‌آموز'),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      selectedStudent.isEmpty ? 'روی دکمه قرعه‌کشی کلیک کنید' : selectedStudent,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF01579B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB300),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: isSpinning
                      ? null
                      : () {
                    setDialogState(() {
                      isSpinning = true;
                    });
                    int spins = 0;
                    spinTimer?.cancel();
                    spinTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
                      if (!ctx.mounted) {
                        t.cancel();
                        return;
                      }
                      spins++;
                      setDialogState(() {
                        selectedStudent = studentList[Random().nextInt(studentList.length)];
                      });
                      if (spins > 15) {
                        t.cancel();
                        setDialogState(() {
                          isSpinning = false;
                        });
                      }
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('چرخاندن گردونه شانس 🎯', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))
            ],
          ),
        ),
      ),
    ).then((_) => spinTimer?.cancel());
  }

  void _openTimerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const Directionality(
        textDirection: TextDirection.rtl,
        child: ClassTimerDialog(),
      ),
    );
  }

  void _openGroupMaker() {
    List<List<String>> groups = [];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('👥 گروه‌‌بندی تصادفی دانش‌آموزان'),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white),
                    onPressed: () {
                      List<String> shuffled = List.from(studentList)..shuffle();
                      groups = [
                        [shuffled[0], shuffled[1]],
                        [shuffled[2], shuffled[3], if (shuffled.length > 4) shuffled[4]],
                      ];
                      setDialogState(() {});
                    },
                    icon: const Icon(Icons.groups_rounded),
                    label: const Text('ساخت گروه‌های ۲ و ۳ نفره'),
                  ),
                  const SizedBox(height: 16),
                  if (groups.isNotEmpty)
                    Column(
                      children: groups.asMap().entries.map((e) {
                        return Card(
                          color: Colors.amber.shade50,
                          child: ListTile(
                            title: Text('گروه ${e.key + 1}:', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(e.value.join(' - ')),
                          ),
                        );
                      }).toList(),
                    )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🧰 ابزارهای کلاس:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
              ),
              const SizedBox(height: 16),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 130,
                ),
                children: [
                  _buildToolCard('قرعه‌کشی شانس', 'انتخاب تصادفی دانش‌آموز', Icons.casino_rounded, Colors.purple, _openRandomPicker),
                  _buildToolCard('تایمر کلاسی', 'زمان‌بندی فعالیت‌ها', Icons.timer_rounded, Colors.orange, _openTimerDialog),
                  _buildToolCard('گروه‌بندی بچه‌ها', 'ساخت گروه تصادفی', Icons.groups_rounded, Colors.teal, _openGroupMaker),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
