import 'package:flutter/material.dart';
import '../pages/manager_classes_page.dart';
import '../services/accounts_service.dart';
import '../utils/jalali.dart';

/// کارت «کلاس‌ها» روی داشبورد مدیر
class ClassesDashboardCard extends StatefulWidget {
  const ClassesDashboardCard({super.key});

  @override
  State<ClassesDashboardCard> createState() => _ClassesDashboardCardState();
}

class _ClassesDashboardCardState extends State<ClassesDashboardCard> {
  int? _active;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _count();
  }

  Future<void> _count() async {
    try {
      final list = await AccountsService.allClasses();
      if (!mounted) return;
      setState(() {
        _active = list.where((c) => c.active).length;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _open() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagerClassesPage()));
    if (mounted) _count();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _failed
        ? 'خواندن فهرست انجام نشد'
        : (_active == null ? 'در حال خواندن...' : '${faDigits(_active!)} کلاس فعال • تعریف و مدیریت');

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFE1F5FE), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.school_rounded, color: Color(0xFF01579B), size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'کلاس‌ها',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: Color(0xFF01579B)),
            ],
          ),
        ),
      ),
    );
  }
}
