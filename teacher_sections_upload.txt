import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../parent/parent_sections.dart';
import '../models/attendance_archive_model.dart';
import '../models/attendance_edit_request_model.dart';
import '../models/audit_log_model.dart';
import '../models/permissions.dart';
import '../models/announcement_model.dart';
import '../models/homework_model.dart';
import '../models/nutrition_model.dart';
import '../utils/export_helper.dart';
import '../widgets/safe_image.dart';
import '../utils/jalali.dart';
import '../models/school_classes.dart';

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

// ---------------------------------------------------------------------------
// حضور و غیاب (معلم)
// ---------------------------------------------------------------------------
class TeacherAttendancePage extends StatefulWidget {
  const TeacherAttendancePage({super.key});

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  static const List<String> _labels = ['حاضر 🟢', 'تأخیر 🟡', 'غایب 🔴'];

  // فهرست نوآموزان کلاس از «مدیریت کاربران» خوانده می‌شود
  List<String> _names = [];
  // ۰ = حاضر، ۱ = تأخیر، ۲ = غایب
  List<int> _status = [];

  bool _loading = true;
  bool _saving = false;
  // قفل برای هر نوآموز جدا: نوآموزی که امروز رکوردش ثبت شده قفل است، بقیه هنوز قابل ثبت‌اند
  final Map<String, AttendanceRecord> _todayRecords = {};
  final Map<String, String> _allergyHints = {}; // نام نوآموز ← مواد حساسیت‌زا (برای ایمنی)

  bool _isLocked(String name) => _todayRecords.containsKey(name);
  int get _recordedCount => _names.where(_todayRecords.containsKey).length;
  int get _pendingCount => _names.length - _recordedCount;

  String get _className => Session.className;
  String get _today => JalaliDate.now().formatted;

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  int _indexOfStatus(String s) {
    if (s.contains('غایب')) return 2;
    if (s.contains('تأخیر')) return 1;
    return 0;
  }

  Future<void> _loadToday() async {
    final records = await AttendanceArchiveService.recordsFor(_className, _today);
    final allergies = await NutritionService.visibleTo(Session.role);
    final students = await StudentDirectory.load();
    if (!mounted) return;
    setState(() {
      _names = students.where((st) => sameClass(st.className, _className)).map((st) => st.name).toList();
      _status = List<int>.filled(_names.length, 0);
      for (final a in allergies) {
        if (!sameClass(a.className, _className)) continue;
        final prev = _allergyHints[a.studentName];
        _allergyHints[a.studentName] = prev == null ? a.allergen : '$prev، ${a.allergen}';
      }
      _todayRecords.clear();
      for (final r in records) {
        _todayRecords[r.studentName] = r;
        final i = _names.indexOf(r.studentName);
        if (i >= 0) _status[i] = _indexOfStatus(r.status);
      }
      _loading = false;
    });
  }

  int _count(int s) => _status.where((x) => x == s).length;

  Future<void> _submitAttendance() async {
    if (_saving || _names.isEmpty || _pendingCount == 0) return;
    if (!PermissionService.instance.allows(Session.role, Perm.recordAttendance, className: _className)) {
      _snack('شما اجازهٔ ثبت حضور و غیاب این کلاس را ندارید', Colors.red);
      return;
    }
    setState(() => _saving = true);

    final now = DateTime.now();
    final j = JalaliDate.fromDateTime(now);

    // همهٔ رکوردها یکجا ساخته و با «یک» عملیات ذخیره می‌شوند
    final records = [
      for (int i = 0; i < _names.length; i++)
        if (!_isLocked(_names[i]))
          AttendanceRecord(
          id: 'ATT-${now.millisecondsSinceEpoch}-$i',
          studentName: _names[i],
          className: _className,
          status: _labels[_status[i]],
          date: j.formatted,
          year: j.year,
          month: j.monthName,
          week: j.weekName,
          day: j.weekdayName,
          teacherName: Session.userName,
          timestamp: now.millisecondsSinceEpoch,
        ),
    ];

    try {
      await AttendanceArchiveService.addRecords(records);
      // رکوردهای ذخیره‌شده را دوباره می‌خوانیم تا شناسهٔ واقعی (سرور) را داشته باشند.
      // بدون این کار، درخواست اصلاح با شناسهٔ محلی «ATT-...» به سرور می‌رفت و خطا می‌داد.
      final saved = await AttendanceArchiveService.recordsFor(_className, j.formatted);
      await AuditLogService.log(
        actor: Session.userName,
        role: Session.role.label,
        action: 'ثبت حضور و غیاب',
        details: '$_className • ${j.formatted} • ${records.length} نفر • حاضر ${records.where((r) => r.status.contains('حاضر')).length} / تأخیر ${records.where((r) => r.status.contains('تأخیر')).length} / غایب ${records.where((r) => r.status.contains('غایب')).length}',
      );
      if (!mounted) return;
      setState(() {
        for (final r in (saved.isEmpty ? records : saved)) {
          _todayRecords[r.studentName] = r;
        }
      });
      _snack('✅ حضور و غیاب ${records.length} نفر ثبت و قفل شد', Colors.green);
    } catch (e) {
      _snack('❌ ثبت انجام نشد: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _openEditRequestDialog() async {
    final recorded = _names.where(_todayRecords.containsKey).toList();
    if (recorded.isEmpty) {
      _snack('هنوز حضور و غیابی برای امروز ثبت نشده که قابل اصلاح باشد', Colors.orange.shade800);
      return;
    }
    String? student = recorded.first;
    int newStatus = 0;
    final reasonCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('درخواست اصلاح حضور و غیاب'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: SafeAssetImage('ill_correction.png', height: 96, fit: BoxFit.contain)),
                  const SizedBox(height: 8),
                  const Text('رکورد ثبت‌شده قفل است و مستقیم تغییر نمی‌کند. درخواست شما برای ناظم یا مدیر ارسال می‌شود.',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: student,
                    decoration: const InputDecoration(labelText: 'نوآموز', border: OutlineInputBorder(), isDense: true),
                    items: [for (final n in recorded) DropdownMenuItem(value: n, child: Text(n))],
                    onChanged: (v) => setD(() => student = v),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (int s = 0; s < 3; s++)
                        ChoiceChip(
                          label: Text(_labels[s]),
                          selected: newStatus == s,
                          onSelected: (_) => setD(() => newStatus = s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'دلیل اصلاح (الزامی)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
              FilledButton(
                onPressed: () async {
                  final reason = reasonCtrl.text.trim();
                  final record = _todayRecords[student];
                  if (record == null) {
                    _snack('رکورد این نوآموز پیدا نشد', Colors.red);
                    return;
                  }
                  if (reason.length < 5) {
                    _snack('دلیل اصلاح را کامل‌تر بنویسید', Colors.orange.shade800);
                    return;
                  }
                  if (_labels[newStatus] == record.status) {
                    _snack('وضعیت جدید با وضعیت فعلی یکسان است', Colors.orange.shade800);
                    return;
                  }
                  bool ok;
                  try {
                    ok = await EditRequestService.create(
                      record: record,
                      newStatus: _labels[newStatus],
                      reason: reason,
                      requestedBy: Session.userName,
                      requesterRole: Session.role.label,
                    );
                  } catch (e) {
                    _snack('$e', Colors.red);
                    return;
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _snack(
                    ok ? '✅ درخواست اصلاح برای ناظم/مدیر ارسال شد' : 'برای این رکورد قبلاً درخواست در انتظار ثبت شده است',
                    ok ? Colors.green : Colors.orange.shade800,
                  );
                },
                child: const Text('ارسال درخواست'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<List<dynamic>> get _exportRows =>
      List.generate(_names.length, (i) => [_names[i], _labels[_status[i]], Session.userName]);

  @override
  Widget build(BuildContext context) {
    const labels = ['حاضر', 'تأخیر', 'غایب'];
    const colors = [Color(0xFF2E9E6B), Color(0xFFF59E0B), Color(0xFFE5484D)];
    final perms = PermissionService.instance;
    final canExport = perms.can(Session.role, Perm.exportReports);
    final canRequestEdit = perms.can(Session.role, Perm.requestAttendanceEdit);

    return SectionScaffold(
      title: 'حضور و غیاب',
      image: 'scene_attendance.png',
      child: _loading
          ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          : Column(
              children: [
                if (_recordedCount > 0)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _pendingCount == 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _pendingCount == 0 ? Icons.lock_rounded : Icons.info_rounded,
                          color: _pendingCount == 0 ? const Color(0xFF2E7D32) : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _pendingCount == 0
                                ? 'حضور و غیاب امروز ثبت و قفل شده است. برای اصلاح، درخواست بدهید.'
                                : 'برای $_recordedCount نفر امروز ثبت و قفل شده است؛ $_pendingCount نفر هنوز ثبت نشده‌اند.',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (canExport)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                        onPressed: () => ExportHelper.exportToExcel(
                          context: context,
                          title: 'حضور و غیاب کلاس $_className',
                          headers: ['نام نوآموز', 'وضعیت', 'مربی ثبت‌کننده'],
                          rows: _exportRows,
                          fileName: 'teacher_attendance_${DateTime.now().millisecondsSinceEpoch}',
                        ),
                        icon: const Icon(Icons.table_chart_rounded, size: 16),
                        label: const Text('اکسل'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                        onPressed: () => ExportHelper.exportToPdf(
                          context: context,
                          title: 'گزارش حضور و غیاب کلاس $_className',
                          headers: ['نام نوآموز', 'وضعیت', 'مربی ثبت‌کننده'],
                          rows: _exportRows,
                          fileName: 'teacher_attendance_${DateTime.now().millisecondsSinceEpoch}',
                        ),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: const Text('PDF'),
                      ),
                      /*print*/
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade700, foregroundColor: Colors.white),
                        onPressed: () => ExportHelper.printTable(
                          context: context,
                          title: 'گزارش حضور و غیاب کلاس $_className',
                          headers: ['نام نوآموز', 'وضعیت', 'مربی ثبت‌کننده'],
                          rows: _exportRows,
                          fileName: 'teacher_attendance_${DateTime.now().millisecondsSinceEpoch}',
                        ),
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('چاپ'),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: colors[i].withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Text('${_count(i)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colors[i])),
                              Text(labels[i], style: TextStyle(color: colors[i])),
                            ],
                          ),
                        ),
                      ),
                      if (i < 2) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < _names.length; i++)
                  softCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ChildAvatar(name: _names[i], size: 42),
                            const SizedBox(width: 12),
                            Text(_names[i], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                          ],
                        ),
                        if (_allergyHints[_names[i]] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('⚠️ حساسیت غذایی: ${_allergyHints[_names[i]]}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFFE5484D), fontWeight: FontWeight.bold)),
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (int s = 0; s < 3; s++)
                              ChoiceChip(
                                label: Text(labels[s]),
                                selected: _status[i] == s,
                                selectedColor: colors[s].withValues(alpha: 0.22),
                                onSelected: _isLocked(_names[i]) ? null : (_) => setState(() => _status[i] = s),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                if (_pendingCount > 0)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _submitAttendance,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_rounded),
                      label: Text(_saving ? 'در حال ثبت...' : 'ثبت و قفل حضور و غیاب ($_pendingCount نفر)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                if (_pendingCount > 0 && _recordedCount > 0 && canRequestEdit) const SizedBox(height: 10),
                if (_recordedCount > 0 && canRequestEdit)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _openEditRequestDialog,
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('درخواست اصلاح'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.navy,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// تکالیف (معلم)
// ---------------------------------------------------------------------------
class TeacherHomeworkPage extends StatefulWidget {
  const TeacherHomeworkPage({super.key});

  @override
  State<TeacherHomeworkPage> createState() => _TeacherHomeworkPageState();
}

class _TeacherHomeworkPageState extends State<TeacherHomeworkPage> {
  bool _loading = true;
  List<Homework> _items = [];
  final Map<String, int> _doneCount = {};

  bool get _canManage =>
      PermissionService.instance.allows(Session.role, Perm.manageHomework, className: Session.className);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await HomeworkService.forClass(Session.className);
    final counts = <String, int>{};
    for (final h in items) {
      counts[h.id] = (await HomeworkService.doneBy(h.id)).length;
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _doneCount
        ..clear()
        ..addAll(counts);
      _loading = false;
    });
  }

  void _snack(String msg, [Color? color]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _addDialog() async {
    if (!_canManage) {
      _snack('شما اجازهٔ تعریف تکلیف ندارید', Colors.red);
      return;
    }
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final dueCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تعریف تکلیف جدید'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'عنوان تکلیف', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'توضیحات', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: dueCtrl, decoration: const InputDecoration(labelText: 'مهلت (مثلاً تا سه‌شنبه)', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('ثبت'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await HomeworkService.add(
      Homework(
        id: 'HW-${DateTime.now().millisecondsSinceEpoch}',
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        due: dueCtrl.text.trim().isEmpty ? 'بدون مهلت' : dueCtrl.text.trim(),
        className: Session.className,
        createdBy: Session.userName,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _load();
    _snack('✅ تکلیف برای والدین نمایش داده می‌شود', Colors.green);
  }

  Future<void> _showDone(Homework h) async {
    final names = await HomeworkService.doneBy(h.id);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('انجام‌شده: ${h.title}'),
          content: Text(names.isEmpty ? 'هنوز کسی علامت نزده است.' : names.join('\n')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))],
        ),
      ),
    );
  }

  Future<void> _delete(Homework h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف تکلیف؟'),
          content: Text(h.title),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await HomeworkService.remove(h.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'تکالیف کلاس',
      image: 'ill_homework_upload.png',
      child: _loading
          ? const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          : Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('تکالیف فعال کلاس', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    if (_canManage)
                      ElevatedButton.icon(
                        onPressed: _addDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('تعریف تکلیف جدید'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_items.isEmpty)
                  softCard(
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: Text('هنوز تکلیفی تعریف نشده است.', style: TextStyle(color: AppColors.textGrey))),
                    ),
                  ),
                for (final item in _items)
                  softCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                              child: Text(item.due, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                            ),
                          ],
                        ),
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(item.description, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('انجام‌شده: ${_doneCount[item.id] ?? 0} نفر', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _showDone(item),
                                  icon: const Icon(Icons.visibility_rounded, size: 16),
                                  label: const Text('چه کسانی؟'),
                                ),
                                if (_canManage)
                                  IconButton(
                                    tooltip: 'حذف',
                                    onPressed: () => _delete(item),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                  ),
                              ],
                            ),
                          ],
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
// اطلاعیه برای اولیا (معلم)
// ---------------------------------------------------------------------------
class TeacherAnnouncePage extends StatefulWidget {
  const TeacherAnnouncePage({super.key});

  @override
  State<TeacherAnnouncePage> createState() => _TeacherAnnouncePageState();
}

class _TeacherAnnouncePageState extends State<TeacherAnnouncePage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _send() async {
    if (_sending) return;
    final perms = PermissionService.instance;
    if (!perms.allows(Session.role, Perm.sendParentAnnouncement, className: Session.className)) {
      _snack('شما اجازهٔ ارسال اطلاعیه برای این کلاس را ندارید', Colors.red);
      return;
    }
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _snack('موضوع و متن اطلاعیه را کامل کنید', Colors.orange.shade800);
      return;
    }
    setState(() => _sending = true);
    await AnnouncementService.send(
      title: title,
      body: body,
      audience: Audience.classOnly,
      className: Session.className,
    );
    if (!mounted) return;
    _title.clear();
    _body.clear();
    setState(() => _sending = false);
    _snack('✅ اطلاعیه برای والدین ${Session.className} ارسال شد', Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'اطلاعیه برای اولیا',
      image: 'ill_announcement.png',
      child: Column(
        children: [
          softCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ارسال اطلاعیه جدید', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 4),
                Text('مخاطب: والدین ${Session.className}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                const SizedBox(height: 10),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'موضوع اطلاعیه', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _body,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'متن پیام برای والدین...', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(_sending ? 'در حال ارسال...' : 'ارسال به والدین'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: Colors.white),
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
// گزارش کلاس (معلم)
// ---------------------------------------------------------------------------
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
