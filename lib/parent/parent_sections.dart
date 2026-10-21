import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/backend.dart';
import '../main.dart';
import '../models/attendance_archive_model.dart';
import '../models/permissions.dart';
import '../widgets/announcements_feed.dart';
import '../widgets/safe_image.dart';
import '../models/homework_model.dart';
import '../pages/manager_financial_page.dart' show TuitionRecord;
import '../utils/jalali.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audit_log_model.dart';
import '../models/school_classes.dart';

const Color kPageBg = Color(0xFFF3F8FF);

/// قاب مشترک همهٔ صفحه‌های داخلی بخش ولی
class SectionScaffold extends StatelessWidget {
  final String title;
  final String image;
  final Widget child;

  const SectionScaffold({
    super.key,
    required this.title,
    required this.image,
    required this.child,
  });

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  SizedBox(
                    height: 150,
                    child: SafeAssetImage(image, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 12),
                  child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget softCard({required Widget child, EdgeInsets? padding}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: padding ?? const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3)),
      ],
    ),
    child: child,
  );
}

// ---------------------------------------------------------------------------
// حضور و غیاب
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// تکالیف
// ---------------------------------------------------------------------------
class HomeworkPage extends StatefulWidget {
  const HomeworkPage({super.key});

  @override
  State<HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<HomeworkPage> {
  bool _loading = true;
  List<Homework> _items = [];
  Set<String> _done = {};

  bool get _allowed => PermissionService.instance.can(AppRole.parent, Perm.viewHomework);

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
    final items = await HomeworkService.forClass(Session.className);
    final done = await HomeworkService.doneIds(Session.childName);
    if (!mounted) return;
    setState(() {
      _items = items;
      _done = done;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'تکالیف',
      image: 'ill_homework_upload.png',
      child: _loading
          ? const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          : !_allowed
              ? softCard(
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: Text('دسترسی به این بخش برای شما فعال نیست.', style: TextStyle(color: AppColors.textGrey))),
                  ),
                )
              : _items.isEmpty
                  ? softCard(
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: Text('هنوز تکلیفی تعریف نشده است.', style: TextStyle(color: AppColors.textGrey))),
                      ),
                    )
                  : Column(
                      children: [
                        for (final h in _items)
                          softCard(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: CheckboxListTile(
                              value: _done.contains(h.id),
                              onChanged: (v) async {
                                final value = v ?? false;
                                await HomeworkService.setDone(Session.childName, h.id, value);
                                if (!mounted) return;
                                setState(() => value ? _done.add(h.id) : _done.remove(h.id));
                              },
                              activeColor: AppColors.navy,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                h.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navy,
                                  decoration: _done.contains(h.id) ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              subtitle: Text('${h.due}${h.description.isEmpty ? '' : '\n${h.description}'}'),
                              isThreeLine: h.description.isNotEmpty,
                            ),
                          ),
                        const Text('وضعیت انجام‌شدن برای مربی نیز نمایش داده می‌شود.',
                            style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                      ],
                    ),
    );
  }
}

// ---------------------------------------------------------------------------
// برنامهٔ هفتگی
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// اطلاعیه‌ها
// ---------------------------------------------------------------------------
class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) => const BulletinPage(role: AppRole.parent);
}

// ---------------------------------------------------------------------------
// پرداخت و اشتراک
// ---------------------------------------------------------------------------
class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _loading = true;
  List<TuitionRecord> _records = [];

  bool get _allowed => PermissionService.instance.can(AppRole.parent, Perm.viewFinancial);

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
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('manager_financial_records_v1');
    var mine = <TuitionRecord>[];
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        mine = [
          for (final e in list)
            if (e is Map && e['studentName'] == Session.childName)
              TuitionRecord.fromJson(Map<String, dynamic>.from(e)),
        ];
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _records = mine;
      _loading = false;
    });
  }

  String _toLatin(String input) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    var out = input.trim();
    for (int i = 0; i < 10; i++) {
      out = out.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
    }
    return out.replaceAll(RegExp(r'[,،٬\s]'), '');
  }

  /// ثبت رسید پرداخت توسط ولی؛ مدیر آن را بررسی و تأیید می‌کند
  Future<void> _submitReceipt() async {
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('ثبت رسید پرداخت'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'مبلغ واریزی (تومان)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: InputDecoration(labelText: 'شمارهٔ پیگیری رسید', errorText: error, border: const OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
              ElevatedButton(
                onPressed: () {
                  final amount = int.tryParse(_toLatin(amountCtrl.text));
                  if (amount == null || amount <= 0 || refCtrl.text.trim().length < 4) {
                    setD(() => error = 'مبلغ و شمارهٔ پیگیری را درست وارد کنید');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('ثبت رسید'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final amount = int.parse(_toLatin(amountCtrl.text));
    final prefs = await SharedPreferences.getInstance();
    List all = [];
    final raw = prefs.getString('manager_financial_records_v1');
    if (raw != null) {
      try {
        all = jsonDecode(raw) as List;
      } catch (_) {}
    }
    final rec = TuitionRecord(
      id: 'P-${DateTime.now().millisecondsSinceEpoch}',
      studentName: Session.childName,
      className: normalizeClassName(Session.className),
      amount: amount,
      status: 'در انتظار تأیید 🟡',
      date: JalaliDate.now().formatted,
      receiptNo: refCtrl.text.trim(),
    );
    all.add(rec.toJson());
    await prefs.setString('manager_financial_records_v1', jsonEncode(all));
    await AuditLogService.log(
      actor: Session.userName,
      role: Session.role.label,
      action: 'ثبت رسید پرداخت',
      details: '${Session.childName} • $amount تومان • ${rec.receiptNo}',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رسید ثبت شد و منتظر تأیید مدیر است')));
    _load();
  }

  String _money(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('،');
      b.write(s[i]);
    }
    return faDigits(b.toString());
  }

  Color _color(String status) {
    if (status.contains('معوقه')) return const Color(0xFFE5484D);
    if (status.contains('انتظار')) return const Color(0xFFF59E0B);
    return const Color(0xFF2E9E6B);
  }

  @override
  Widget build(BuildContext context) {
    final overdue = _records.where((r) => r.status.contains('معوقه')).toList();
    final overdueSum = overdue.fold<int>(0, (a, r) => a + r.amount);
    return SectionScaffold(
      title: 'پرداخت و اشتراک',
      image: 'scene_payment.png',
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
                    softCard(
                      child: Row(
                        children: [
                          Icon(
                            _records.isEmpty
                                ? Icons.info_rounded
                                : (overdue.isEmpty ? Icons.verified_rounded : Icons.warning_amber_rounded),
                            color: _records.isEmpty
                                ? AppColors.textGrey
                                : (overdue.isEmpty ? const Color(0xFF2E9E6B) : const Color(0xFFE5484D)),
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _records.isEmpty
                                  ? 'سابقهٔ مالی برای ${Session.childName} ثبت نشده است'
                                  : (overdue.isEmpty
                                      ? 'حساب شما تسویه است'
                                      : 'مبلغ معوقه: ${_money(overdueSum)} تومان'),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final r in _records)
                      softCard(
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 44,
                              decoration: BoxDecoration(color: _color(r.status), borderRadius: BorderRadius.circular(4)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${_money(r.amount)} تومان',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                                  Text('${r.date} • رسید ${r.receiptNo}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                                ],
                              ),
                            ),
                            Text(r.status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _color(r.status))),
                          ],
                        ),
                      ),
                    softCard(
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('روش پرداخت: کارت به کارت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy)),
                          SizedBox(height: 10),
                          Text('۱) مبلغ را به کارت مدرسه واریز کنید.', style: TextStyle(height: 1.8)),
                          Text('۲) مبلغ و شمارهٔ پیگیری را با دکمهٔ «ثبت رسید» وارد کنید.', style: TextStyle(height: 1.8)),
                          Text('۳) بعد از تأیید مدیر، وضعیت شما به‌روز می‌شود.', style: TextStyle(height: 1.8)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _submitReceipt,
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: const Text('ثبت رسید پرداخت'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
