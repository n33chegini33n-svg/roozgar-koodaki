import '../widgets/illustration_banner.dart';
import 'package:flutter/material.dart';
import '../models/nutrition_model.dart';
import '../models/permissions.dart';
import '../services/nutrition_request_service.dart';
import '../utils/jalali.dart';
import '../widgets/nutrition_views.dart';

/// تغذیه و سلامت: منوی هفتگی + بایگانی + حساسیت‌ها + درخواست‌های در انتظار
/// مدیر و ادمین مستقیم تغییر می‌دهند. آشپز پیشنهاد می‌دهد و مدیر تأیید می‌کند.
class ManagerNutritionPage extends StatefulWidget {
  const ManagerNutritionPage({super.key});

  @override
  State<ManagerNutritionPage> createState() => _ManagerNutritionPageState();
}

class _ManagerNutritionPageState extends State<ManagerNutritionPage> {
  static const Color _navy = Color(0xFF01579B);

  // وعده‌های رسمی منو (صبحانه نداریم)
  static const List<String> _meals = ['میان‌وعده', 'ناهار'];

  bool _loading = true;
  bool _busy = false;
  // منوی تأییدشدهٔ هفتهٔ پیش‌رو فقط با دکمهٔ «ویرایش» باز می‌شود
  bool _editing = false;

  // کنترلر هر وعده: کلید = «روز|وعده»
  final Map<String, TextEditingController> _ctrls = {};
  // متن تأییدشدهٔ فعلی؛ مبنا برای تشخیص تغییر
  Map<String, String> _baseline = {};
  // متنی که آشپز فرستاده ولی هنوز تأیید نشده؛ تا تغییر نکند دکمه دوباره فعال نمی‌شود
  final Map<String, String> _sent = {};

  MenuWeek? _week;
  List<MenuWeek> _archived = [];

  List<AllergyRecord> _allergies = [];
  List<NutritionRequest> _pending = [];
  List<NutritionRequest> _mine = [];
  Map<String, String> _studentNames = {};

  bool get _isKitchen => Session.role == AppRole.kitchen;
  bool get _isManager => Session.role == AppRole.manager || Session.role == AppRole.admin;
  bool get _canEdit => PermissionService.instance.can(Session.role, Perm.manageNutrition);
  bool get _canManageAllergy => PermissionService.instance.can(Session.role, Perm.manageAllergies);

  static final List<String> _cellKeys = [for (final d in kMenuDays) for (final m in _meals) '$d|$m'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String msg, [Color? color]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  String _err(Object e) => '$e'.replaceFirst('Exception: ', '');

  Future<void> _load() async {
    final w = await NutritionRequestService.upcomingWeek();
    final items = w == null ? <String, String>{} : await NutritionRequestService.weekItems(w.id);
    final archived = (_isManager || _isKitchen) ? await NutritionRequestService.archivedWeeks() : <MenuWeek>[];
    final allergies = await NutritionService.visibleTo(Session.role);
    final students = await StudentDirectory.load();
    final pending = _isManager ? await NutritionRequestService.pending() : <NutritionRequest>[];
    final mine = _isKitchen ? await NutritionRequestService.mine() : <NutritionRequest>[];
    if (!mounted) return;
    setState(() {
      _week = w;
      _baseline = items;
      _archived = archived;
      // آشپز آنچه فرستاده را می‌بیند تا تأیید یا رد شود؛ بقیه متن تأییدشده را
      for (final k in _cellKeys) {
        final text = _sent[k] ?? items[k] ?? '';
        final c = _ctrls[k];
        if (c == null) {
          _ctrls[k] = TextEditingController(text: text);
        } else {
          c.text = text;
        }
      }
      _allergies = List.of(allergies);
      _studentNames = {for (final s in students) s.id: s.name};
      _pending = pending;
      _mine = mine;
      _loading = false;
    });
  }

  /// کلیدهایی که متنشان با مبنا فرق دارد
  List<String> _changedKeys() {
    final out = <String>[];
    for (final k in _cellKeys) {
      final now = _ctrls[k]?.text.trim() ?? '';
      final ref = _sent[k] ?? _baseline[k] ?? '';
      if (now != ref) out.add(k);
    }
    return out;
  }

  Map<String, Map<String, String>> _menuFromControllers() {
    return {
      for (final d in kMenuDays)
        d: {for (final m in _meals) m: _ctrls['$d|$m']!.text.trim()},
    };
  }

  /// شروع هفتهٔ پیشنهادی: شنبهٔ همین هفته
  DateTime _proposalStart() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: ((now.weekday % 7) + 1) % 7));
  }

  Future<void> _saveChanges() async {
    if (_busy || !_canEdit) return;
    final keys = _changedKeys();
    if (keys.isEmpty) return;
    setState(() => _busy = true);
    try {
      if (_week == null) {
        // هفتهٔ جدید: مدیر مستقیم ثبت می‌کند، آشپز پیشنهاد می‌دهد
        final start = _proposalStart();
        final label = 'هفتهٔ ${JalaliDate.fromDateTime(start).formatted}';
        final menu = _menuFromControllers();
        if (_isKitchen) {
          await NutritionRequestService.submitMenu(
            weekStart: JalaliDate.isoDay(start),
            label: label,
            menu: menu,
          );
          for (final k in _cellKeys) {
            _sent[k] = _ctrls[k]!.text.trim();
          }
          _snack('✅ پیشنهاد هفته برای تأیید مدیر ارسال شد', Colors.green);
        } else {
          await NutritionRequestService.managerCreateWeek(
            weekStart: JalaliDate.isoDay(start),
            label: label,
            menu: menu,
          );
          _snack('✅ منوی هفته ثبت شد', Colors.green);
        }
      } else {
        // ویرایش یک یا چند وعده در هفتهٔ جاری
        final weekId = _week!.id;
        for (final k in keys) {
          final parts = k.split('|');
          final text = _ctrls[k]!.text.trim();
          if (_isKitchen) {
            await NutritionRequestService.submitMenuEdit(
              weekId: weekId,
              day: parts[0],
              meal: parts[1],
              content: text,
            );
            _sent[k] = text;
          } else {
            await NutritionRequestService.managerEditItem(
              weekId: weekId,
              day: parts[0],
              meal: parts[1],
              content: text,
            );
          }
        }
        _snack(_isKitchen ? '✅ تغییرات برای تأیید مدیر ارسال شد' : '✅ تغییرات ذخیره شد', Colors.green);
      }
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      _snack('ارسال انجام نشد: ${_err(e)}', Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _load();
  }

  String _rangeText(MenuWeek w) =>
      '${JalaliDate.fromDateTime(w.start).formatted} تا ${JalaliDate.fromDateTime(w.end).formatted}';

  Future<void> _addAllergyDialog() async {
    final students = await StudentDirectory.load();
    if (!mounted || students.isEmpty) return;
    StudentInfo selected = students.first;
    String severity = 'متوسط';
    final allergenCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('ثبت حساسیت غذایی'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<StudentInfo>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'نوآموز', border: OutlineInputBorder(), isDense: true),
                    items: [for (final s in students) DropdownMenuItem(value: s, child: Text('${s.name} • ${s.className}', overflow: TextOverflow.ellipsis))],
                    onChanged: (v) => setD(() => selected = v ?? selected),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: allergenCtrl,
                    decoration: const InputDecoration(labelText: 'مادهٔ حساسیت‌زا (مثلاً بادام‌زمینی)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in kSeverities)
                        ChoiceChip(
                          label: Text(s),
                          selected: severity == s,
                          selectedColor: severityColor(s).withValues(alpha: 0.25),
                          onSelected: (_) => setD(() => severity = s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
              FilledButton(
                onPressed: () {
                  if (allergenCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('ثبت'),
              ),
            ],
          ),
        ),
      ),
    );

    final allergen = allergenCtrl.text.trim();
    final notes = notesCtrl.text.trim();
    if (ok != true) return;

    try {
      if (_isKitchen) {
        await NutritionRequestService.submitAllergyAdd(
          studentId: selected.id,
          allergen: allergen,
          severity: severity,
          notes: notes,
        );
      } else {
        await NutritionService.addAllergy(
          AllergyRecord(
            id: 'ALG-${DateTime.now().millisecondsSinceEpoch}',
            studentId: selected.id,
            studentName: selected.name,
            className: selected.className,
            allergen: allergen,
            severity: severity,
            notes: notes,
          ),
        );
      }
    } catch (e) {
      _snack(_err(e), Colors.red);
      return;
    }
    await _load();
    _snack(_isKitchen ? '✅ حساسیت برای تأیید مدیر ارسال شد' : '✅ حساسیت ثبت شد', Colors.green);
  }

  Future<void> _confirmDelete(AllergyRecord a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(_isKitchen ? 'درخواست حذف حساسیت؟' : 'حذف حساسیت؟'),
          content: Text('${a.studentName} • ${a.allergen}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      if (_isKitchen) {
        await NutritionRequestService.submitAllergyRemove(a.id);
        _snack('✅ درخواست حذف برای تأیید مدیر ارسال شد', Colors.green);
      } else {
        await NutritionService.removeAllergy(a.id);
        _snack('حساسیت حذف شد', Colors.orange);
      }
    } catch (e) {
      _snack(_err(e), Colors.red);
      return;
    }
    await _load();
  }

  /// تأیید یا رد یک درخواست. رد بدون دلیل انجام می‌شود.
  Future<void> _decide(NutritionRequest r, bool approve) async {
    try {
      await NutritionRequestService.decide(id: r.id, approve: approve);
      _snack(approve ? '✅ تأیید شد' : 'درخواست رد شد', approve ? Colors.green : Colors.orange);
    } catch (e) {
      _snack(_err(e), Colors.red);
    }
    await _load();
  }

  Future<void> _rejectDialog(NutritionRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رد این پیشنهاد؟'),
          content: const Text('این پیشنهاد رد می‌شود و وضعیت آن برای آشپز نمایش داده می‌شود.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('رد کن')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _decide(r, false);
  }

  String _requestTitle(NutritionRequest r) {
    if (r.kind == 'menu') return 'منوی هفتگی پیشنهادی';
    if (r.kind == 'menu_edit') return 'تغییر یک وعده (${r.payload['day']} • ${r.payload['meal']})';
    if ('${r.payload['action']}' == 'remove') return 'درخواست حذف حساسیت';
    final name = _studentNames['${r.payload['student_id']}'] ?? '';
    return 'ثبت حساسیت${name.isEmpty ? '' : ' • $name'}';
  }

  List<Widget> _requestDetails(NutritionRequest r) {
    if (r.kind == 'menu_edit') {
      return [Text('متن جدید: ${r.payload['content']}', style: const TextStyle(fontSize: 13))];
    }
    if (r.kind == 'menu') {
      final menu = (r.payload['menu'] as Map?) ?? {};
      final lines = <Widget>[];
      for (final d in kMenuDays) {
        final day = menu[d] as Map?;
        if (day == null) continue;
        for (final m in _meals) {
          final text = '${day[m] ?? ''}'.trim();
          if (text.isEmpty) continue;
          lines.add(Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text('$d • $m: $text', style: const TextStyle(fontSize: 13)),
          ));
        }
      }
      return lines.isEmpty ? [const Text('منو خالی است', style: TextStyle(fontSize: 13))] : lines;
    }
    if ('${r.payload['action']}' == 'remove') {
      return [const Text('حذف یکی از حساسیت‌های ثبت‌شده', style: TextStyle(fontSize: 13))];
    }
    final notes = '${r.payload['notes'] ?? ''}'.trim();
    return [
      Text(
        '${r.payload['allergen']} • شدت: ${r.payload['severity']}${notes.isEmpty ? '' : '\n$notes'}',
        style: const TextStyle(fontSize: 13),
      ),
    ];
  }

  Widget _pendingSection() {
    if (!_isManager || _pending.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text('درخواست‌های در انتظار تأیید', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
        ),
        for (final r in _pending)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_requestTitle(r), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ..._requestDetails(r),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => _rejectDialog(r), child: const Text('رد')),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: () => _decide(r, true), child: const Text('تأیید')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _statusLabel(String s) {
    if (s == 'approved') return 'تأیید شد';
    if (s == 'rejected') return 'رد شد';
    return 'در انتظار تأیید';
  }

  Color _statusColor(String s) {
    if (s == 'approved') return const Color(0xFF2E9E6B);
    if (s == 'rejected') return const Color(0xFFE5484D);
    return const Color(0xFFF59E0B);
  }

  String _mineDate(NutritionRequest r) {
    final d = r.submittedAt;
    if (d == null) return '';
    return JalaliDate.fromDateTime(d.toLocal()).formatted;
  }

  /// سوابق آشپز: وضعیت هر درخواست (بدون دلیل)
  Widget _mineSection() {
    if (!_isKitchen || _mine.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text('سوابق درخواست‌های من', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
        ),
        for (final r in _mine)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              dense: true,
              title: Text(_requestTitle(r), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(_mineDate(r), style: const TextStyle(fontSize: 12)),
              trailing: Text(
                _statusLabel(r.status),
                style: TextStyle(color: _statusColor(r.status), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  /// بایگانی: منوی هفته‌های گذشته، هر هفته با تاریخ خودش. مدیر و آشپز می‌بینند.
  Widget _archiveTab() {
    if (_archived.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('هنوز منوی بایگانی‌شده‌ای نیست.\nهفته‌های گذشته اینجا می‌آیند.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const IllustrationBanner(
          image: 'ill_archive.png',
          title: 'بایگانی منوها',
          subtitle: 'برای دیدن منوی هر هفته، روی آن بزنید.',
          tint: Color(0xFFE1F5FE),
        ),
        for (final w in _archived)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: const Icon(Icons.folder_rounded, color: _navy),
              title: Text(w.label.isEmpty ? _rangeText(w) : w.label, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_rangeText(w), style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(builder: (_) => _ArchivedMenuWeekPage(week: w, canDelete: _isManager)),
                );
                if (changed == true) await _load();
              },
            ),
          ),
      ],
    );
  }

  /// دکمه‌های پایین منو: قفل/ویرایش، و در حالت ویرایش: انصراف و ذخیره یا ارسال
  Widget _actionRow(List<String> changed, String buttonText) {
    if (_week != null && !_editing) {
      return SizedBox(
        height: 50,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : () => setState(() => _editing = true),
          icon: const Icon(Icons.edit_rounded),
          label: const Text('ویرایش منو'),
        ),
      );
    }
    final saveButton = SizedBox(
      height: 50,
      child: FilledButton.icon(
        onPressed: (_busy || changed.isEmpty) ? null : _saveChanges,
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_rounded),
        label: Text(buttonText),
      ),
    );
    if (_week == null) return saveButton;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(onPressed: _busy ? null : _cancelEdit, child: const Text('انصراف')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: saveButton),
          ],
        ),
        if (_isKitchen && changed.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('تغییری برای ارسال نیست. بعد از ویرایش، دکمه فعال می‌شود.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
          ),
      ],
    );
  }

  /// لغو ویرایش: متن‌ها به آخرین مقدار معتبر برمی‌گردند و منو قفل می‌شود
  void _cancelEdit() {
    setState(() {
      _editing = false;
      for (final k in _cellKeys) {
        _ctrls[k]?.text = _sent[k] ?? _baseline[k] ?? '';
      }
    });
  }

  Widget _menuTab() {
    final changed = _changedKeys();
    final String header;
    if (_week != null) {
      header = 'منوی هفتهٔ پیش‌رو: ${_week!.label.isEmpty ? _rangeText(_week!) : _week!.label}';
    } else {
      header = _isKitchen
          ? 'هنوز منوی هفته‌ی بعد ثبت نشده. پیشنهاد هفته را بنویسید.'
          : 'هنوز منوی هفته‌ی بعد ثبت نشده. منوی هفته را وارد کنید.';
    }

    final String buttonText;
    if (_busy) {
      buttonText = 'در حال ارسال...';
    } else if (_isKitchen) {
      buttonText = _week == null ? 'ارسال پیشنهاد هفته برای تأیید مدیر' : 'ارسال تغییرات برای تأیید مدیر';
    } else {
      buttonText = _week == null ? 'ثبت منوی هفته' : 'ذخیرهٔ تغییرات';
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const IllustrationBanner(
          image: 'ill_menu.png',
          title: 'منوی هفتگی',
          subtitle: 'منوی هفتهٔ پیش‌رو برای والدین و مربیان نمایش داده می‌شود.',
          tint: Color(0xFFE8F5E9),
        ),
        _pendingSection(),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text(header, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
        ),
        for (final d in kMenuDays)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d, style: const TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 15)),
                  const SizedBox(height: 8),
                  for (final m in _meals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: _ctrls['$d|$m'],
                        enabled: _canEdit && (_week == null || _editing),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(labelText: m, border: const OutlineInputBorder(), isDense: true),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (_canEdit) _actionRow(changed, buttonText),
        _mineSection(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _allergyTab() {
    const banner = Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: IllustrationBanner(
        image: 'ill_food_allergy.png',
        title: 'حساسیت‌های غذایی',
        subtitle: 'مربی کلاس هنگام حضور و غیاب، هشدار این کودکان را می‌بیند.',
        tint: Color(0xFFFFEBEE),
      ),
    );
    if (_allergies.isEmpty) {
      return const Column(
        children: [
          banner,
          Expanded(child: Center(child: Text('هنوز حساسیتی ثبت نشده است.', style: TextStyle(color: Colors.grey)))),
        ],
      );
    }
    return Column(
      children: [
        banner,
        Expanded(child: _allergyList()),
      ],
    );
  }

  Widget _allergyList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _allergies.length,
      itemBuilder: (_, i) {
        final a = _allergies[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: severityColor(a.severity).withValues(alpha: 0.15),
              child: Icon(Icons.warning_amber_rounded, color: severityColor(a.severity)),
            ),
            title: Text('${a.studentName} • ${a.allergen}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${a.className} • شدت: ${a.severity}${a.notes.isEmpty ? '' : '\n${a.notes}'}', style: const TextStyle(fontSize: 12)),
            isThreeLine: a.notes.isNotEmpty,
            trailing: _canManageAllergy
                ? IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _confirmDelete(a))
                : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: const Color(0xFFF3F8FF),
          appBar: AppBar(
            title: const Text('تغذیه و سلامت'),
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            bottom: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [Tab(text: 'منوی هفتگی'), Tab(text: 'بایگانی'), Tab(text: 'حساسیت‌های غذایی')],
            ),
          ),
          floatingActionButton: (_canManageAllergy && !_loading)
              ? Builder(
                  builder: (ctx) => FloatingActionButton.extended(
                    onPressed: _addAllergyDialog,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(_isKitchen ? 'ثبت حساسیت (با تأیید مدیر)' : 'ثبت حساسیت'),
                  ),
                )
              : null,
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(children: [_menuTab(), _archiveTab(), _allergyTab()]),
        ),
      ),
    );
  }
}

/// صفحهٔ یک هفتهٔ بایگانی‌شده: همهٔ روزها و وعده‌ها. فقط مدیر می‌تواند حذف کند.
class _ArchivedMenuWeekPage extends StatefulWidget {
  final MenuWeek week;
  final bool canDelete;
  const _ArchivedMenuWeekPage({required this.week, required this.canDelete});

  @override
  State<_ArchivedMenuWeekPage> createState() => _ArchivedMenuWeekPageState();
}

class _ArchivedMenuWeekPageState extends State<_ArchivedMenuWeekPage> {
  static const Color _navy = Color(0xFF01579B);

  Map<String, String>? _items;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await NutritionRequestService.weekItems(widget.week.id);
    if (!mounted) return;
    setState(() => _items = items);
  }

  String get _range =>
      '${JalaliDate.fromDateTime(widget.week.start).formatted} تا ${JalaliDate.fromDateTime(widget.week.end).formatted}';

  String _cell(Map<String, String> items, String d, String m) {
    final t = (items['$d|$m'] ?? '').trim();
    return t.isEmpty ? '—' : t;
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف از بایگانی؟'),
          content: Text('منوی $_range برای همیشه حذف می‌شود و آشپز هم دیگر آن را نمی‌بیند.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() => _deleting = true);
    try {
      await NutritionRequestService.deleteWeek(widget.week.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final title = widget.week.label.isEmpty ? _range : widget.week.label;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(title: Text(title), backgroundColor: _navy, foregroundColor: Colors.white),
        body: items == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(_range, style: const TextStyle(color: _navy, fontWeight: FontWeight.bold)),
                  ),
                  for (final d in kMenuDays)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d, style: const TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 15)),
                            const SizedBox(height: 6),
                            for (final m in kMeals)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('$m: ${_cell(items, d, m)}', style: const TextStyle(fontSize: 13)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (widget.canDelete) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _deleting ? null : _delete,
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE5484D)),
                        label: const Text('حذف از بایگانی', style: TextStyle(color: Color(0xFFE5484D))),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
