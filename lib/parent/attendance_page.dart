import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/attendance_archive_model.dart';
import '../models/permissions.dart';
import 'parent_sections.dart' show SectionScaffold, softCard;

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  bool _loading = true;
  List<AttendanceRecord> _records = [];

  bool get _allowed => PermissionService.instance.can(AppRole.parent, Perm.viewAttendance);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_allowed) {
      setState(() => _loading = false);
      return;
    }
    final all = await AttendanceArchiveService.getRecords();
    // دامنهٔ «فرزند خودش»: فقط رکوردهای نوآموز مرتبط با این ولی
    final mine = all.where((r) => r.studentName == Session.childName).toList()
      ..sort((x, y) => y.timestamp.compareTo(x.timestamp));
    if (!mounted) return;
    setState(() {
      _records = mine.take(30).toList();
      _loading = false;
    });
  }

  Color _colorOf(String s) {
    if (s.contains('غایب')) return const Color(0xFFE5484D);
    if (s.contains('تأخیر')) return const Color(0xFFF59E0B);
    return const Color(0xFF2E9E6B);
  }

  int _count(String key) => _records.where((r) => r.status.contains(key)).length;

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'حضور و غیاب',
      image: 'scene_attendance.png',
      child: _loading
          ? const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          : !_allowed
              ? softCard(
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: Text('دسترسی به این بخش برای شما فعال نیست.', style: TextStyle(color: AppColors.textGrey))),
                  ),
                )
              : Column(
                  children: [
                    Text('وضعیت ${Session.childName} در ۳۰ ثبت اخیر',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _stat('حاضر', '${_count('حاضر')}', const Color(0xFF2E9E6B)),
                        const SizedBox(width: 8),
                        _stat('تأخیر', '${_count('تأخیر')}', const Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        _stat('غایب', '${_count('غایب')}', const Color(0xFFE5484D)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_records.isEmpty)
                      softCard(
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: Text('هنوز حضور و غیابی ثبت نشده است.', style: TextStyle(color: AppColors.textGrey))),
                        ),
                      ),
                    for (final r in _records)
                      softCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.day, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                                  Text(r.date, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: _colorOf(r.status).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(r.status, style: TextStyle(color: _colorOf(r.status), fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _stat(String label, String value, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: c)),
          ],
        ),
      ),
    );
  }
}

