import '../widgets/illustration_banner.dart';
import 'package:flutter/material.dart';
import '../models/app_settings_model.dart';
import '../models/attendance_archive_model.dart';
import '../models/audit_log_model.dart';
import '../models/nutrition_model.dart';
import '../models/permissions.dart';

/// تنظیمات برنامه و اشتراک (فقط ادمین سیستم)
class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  static const Color _navy = Color(0xFF01579B);
  bool _loading = true;
  bool _saving = false;

  final _school = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _year = TextEditingController();
  final _plan = TextEditingController();
  final _expiry = TextEditingController();
  final _limit = TextEditingController();

  int _students = 0;
  int _attendanceCount = 0;
  int _auditCount = 0;

  bool get _canEdit => PermissionService.instance.can(Session.role, Perm.manageAppSettings);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_school, _phone, _address, _year, _plan, _expiry, _limit]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final s = await AppSettingsService.get();
    final students = await StudentDirectory.load();
    final att = await AttendanceArchiveService.getRecords();
    final audit = await AuditLogService.getAll();
    if (!mounted) return;
    setState(() {
      _school.text = s.schoolName;
      _phone.text = s.phone;
      _address.text = s.address;
      _year.text = s.academicYear;
      _plan.text = s.planName;
      _expiry.text = s.expiry;
      _limit.text = '${s.studentLimit}';
      _students = students.length;
      _attendanceCount = att.length;
      _auditCount = audit.length;
      _loading = false;
    });
  }

  void _snack(String msg, [Color? color]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _save() async {
    if (!_canEdit || _saving) return;
    final expiry = _expiry.text.trim();
    if (expiry.isNotEmpty && !RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(expiry)) {
      _snack('تاریخ انقضا را به شکل 1406/01/01 بنویسید', Colors.orange.shade800);
      return;
    }
    final limit = int.tryParse(_limit.text.trim());
    if (limit == null || limit < 1) {
      _snack('سقف نوآموز باید یک عدد مثبت باشد', Colors.orange.shade800);
      return;
    }
    setState(() => _saving = true);
    await AppSettingsService.save(
      AppSettings(
        schoolName: _school.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        academicYear: _year.text.trim(),
        planName: _plan.text.trim(),
        expiry: expiry,
        studentLimit: limit,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _snack('✅ تنظیمات ذخیره شد', Colors.green);
  }

  Widget _field(TextEditingController c, String label, {TextInputType? type, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        enabled: _canEdit,
        keyboardType: type,
        decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), isDense: true),
      ),
    );
  }

  Widget _stat(String label, int value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFE1F5FE), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Icon(icon, color: _navy),
            const SizedBox(height: 4),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _navy)),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Text('تنظیمات برنامه و اشتراک'),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  const IllustrationBanner(
                    image: 'ill_admin.png',
                    title: 'ادمین سیستم',
                    subtitle: 'اطلاعات مجموعه، اشتراک و آمار برنامه',
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(14)),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_rounded, color: Color(0xFFF59E0B)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'این اطلاعات فعلاً فقط روی همین دستگاه ذخیره می‌شود. '
                            'اشتراک واقعی و پرداخت، بعد از اتصال به سرور فعال می‌شود.',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _stat('نوآموز ثبت‌شده', _students, Icons.child_care_rounded),
                      const SizedBox(width: 8),
                      _stat('رکورد حضور', _attendanceCount, Icons.how_to_reg_rounded),
                      const SizedBox(width: 8),
                      _stat('ردیف لاگ', _auditCount, Icons.history_rounded),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('اطلاعات مجموعه', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navy)),
                  const SizedBox(height: 8),
                  _field(_school, 'نام مجموعه'),
                  _field(_phone, 'تلفن تماس', type: TextInputType.phone),
                  _field(_address, 'نشانی'),
                  _field(_year, 'سال تحصیلی', hint: '1405-1406'),
                  const SizedBox(height: 8),
                  const Text('اشتراک', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navy)),
                  const SizedBox(height: 8),
                  _field(_plan, 'نام طرح'),
                  _field(_expiry, 'تاریخ انقضا', hint: '1406/01/01'),
                  _field(_limit, 'سقف تعداد نوآموز', type: TextInputType.number),
                  if (_students > (int.tryParse(_limit.text.trim()) ?? 1 << 30))
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text('⚠️ تعداد نوآموزان از سقف اشتراک بیشتر است.', style: TextStyle(color: Color(0xFFE5484D))),
                    ),
                  const SizedBox(height: 6),
                  if (_canEdit)
                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded),
                        label: Text(_saving ? 'در حال ذخیره...' : 'ذخیره'),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
      ),
    );
  }
}
