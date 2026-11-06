import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'tuition_agreement_dialog.dart';
import 'archive_folder_page.dart';
import '../models/permissions.dart';
import '../services/backend.dart';
import '../services/backend_directory.dart';
import '../utils/export_helper.dart';
import '../utils/jalali.dart';
import 'school_card_preview_page.dart';
import 'campaign_dialog.dart';
import 'campaigns_page.dart';
import '../services/manager_payment_service.dart';
import '../services/payment_resolution_service.dart';

const List<String> kFeeTypes = ['شهریه', 'ناهار', 'میان‌وعده', 'نگهداری اضافه', 'اردو', 'سرویس', 'سایر'];

/// نسخهٔ ساده برای صفحهٔ ولی (آن صفحه هنوز از این کلاس استفاده می‌کند)
class TuitionRecord {
  final String id;
  final String studentName;
  final String className;
  final int amount;
  final String status;
  final String date;
  final String receiptNo;

  const TuitionRecord({
    required this.id,
    required this.studentName,
    required this.className,
    required this.amount,
    required this.status,
    required this.date,
    required this.receiptNo,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentName': studentName,
        'className': className,
        'amount': amount,
        'status': status,
        'date': date,
        'receiptNo': receiptNo,
      };

  factory TuitionRecord.fromJson(Map<String, dynamic> j) => TuitionRecord(
        id: '${j['id'] ?? ''}',
        studentName: '${j['studentName'] ?? ''}',
        className: '${j['className'] ?? ''}',
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        status: '${j['status'] ?? ''}',
        date: '${j['date'] ?? ''}',
        receiptNo: '${j['receiptNo'] ?? ''}',
      );
}

/// یک قسط یا مرحلهٔ پرداخت
class ScheduleItem {
  final String id;
  final int seq;
  final int amount;
  final String due;
  final bool settled;
  final String kind; // cash | installment

  const ScheduleItem({
    required this.id,
    required this.seq,
    required this.amount,
    required this.due,
    required this.settled,
    this.kind = 'installment',
  });
}

/// یک بند هزینه برای یک نوآموز
class Charge {
  final String id;
  final String studentId;
  final String studentName;
  final String className;
  final String feeType;
  final String title;
  final String mode; // cash | installment
  final int amount;
  final bool included;
  final List<ScheduleItem> schedule;
  final List<Map<String, dynamic>> lines;
  final String requestedBy;
  final String requestReason;

  const Charge({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.feeType,
    required this.title,
    required this.mode,
    required this.amount,
    required this.included,
    required this.schedule,
    this.lines = const [],
    this.requestedBy = '',
    this.requestReason = '',
  });

  int get paid => schedule.where((s) => s.settled).fold(0, (a, s) => a + s.amount);
  int get balance => amount - paid;

  String get status {
    if (schedule.isEmpty) return 'برنامه ثبت نشده';
    if (paid == 0) return 'معوقه / بدهکار';
    if (paid >= amount) return 'پرداخت‌شده';
    return 'نیمه‌پرداخت';
  }

  factory Charge.fromPlan(Map<String, dynamic> r) {
    final st = r['students'];
    final cl = st is Map ? st['classes'] : null;
    final rawSchedule = (r['tuition_schedule'] as List?) ?? const [];
    final schedule = [
      for (final s in rawSchedule)
        ScheduleItem(
          id: '${s['id']}',
          seq: (s['seq'] as num?)?.toInt() ?? 0,
          amount: (s['amount'] as num?)?.toInt() ?? 0,
          due: '${s['due_jalali'] ?? ''}',
          settled: s['settled'] == true,
          kind: '${s['kind'] ?? 'installment'}',
        ),
    ]..sort((a, b) => a.kind == b.kind ? a.seq.compareTo(b.seq) : (a.kind == 'cash' ? -1 : 1));
    final lines = [for (final l in (r['lines'] as List?) ?? const []) Map<String, dynamic>.from(l as Map)];
    final title = lines
        .map((l) => '${l['fee_title'] ?? l['fee_type'] ?? ''}')
        .where((t) => t.isNotEmpty)
        .join('، ');
    final hasCash = schedule.any((s) => s.kind == 'cash');
    final hasInst = schedule.any((s) => s.kind != 'cash');
    return Charge(
      id: '${r['id']}',
      studentId: '${r['student_id']}',
      studentName: st is Map ? '${st['full_name'] ?? ''}' : '',
      className: cl is Map ? '${cl['name'] ?? ''}' : '',
      feeType: '',
      title: title.isEmpty ? 'بند مالی' : title,
      mode: hasCash && hasInst ? 'mixed' : (hasCash ? 'cash' : 'installment'),
      amount: (r['total'] as num?)?.toInt() ?? 0,
      included: true,
      schedule: schedule,
      lines: lines,
      requestedBy: '${r['archive_requested_by'] ?? ''}',
      requestReason: '${r['archive_requested_reason'] ?? ''}',
    );
  }

  factory Charge.fromRow(Map<String, dynamic> r) {
    final st = r['students'];
    final cl = r['classes'];
    final rawSchedule = (r['tuition_schedule'] as List?) ?? const [];
    final schedule = [
      for (final s in rawSchedule)
        ScheduleItem(
          id: '${s['id']}',
          seq: (s['seq'] as num?)?.toInt() ?? 0,
          amount: (s['amount'] as num?)?.toInt() ?? 0,
          due: '${s['due_jalali'] ?? ''}',
          settled: s['settled'] == true,
          kind: '${s['kind'] ?? 'installment'}',
        ),
    ]..sort((a, b) => a.seq.compareTo(b.seq));
    return Charge(
      id: '${r['id']}',
      studentId: '${r['student_id']}',
      studentName: st is Map ? '${st['full_name'] ?? ''}' : '',
      className: cl is Map ? '${cl['name'] ?? ''}' : '',
      feeType: '${r['fee_type'] ?? ''}',
      title: '${r['fee_title'] ?? ''}',
      mode: '${r['payment_mode'] ?? 'cash'}',
      amount: (r['amount'] as num?)?.toInt() ?? 0,
      included: r['included'] == true,
      schedule: schedule,
    );
  }
}

class ManagerFinancialPage extends StatefulWidget {
  const ManagerFinancialPage({super.key});

  @override
  State<ManagerFinancialPage> createState() => _ManagerFinancialPageState();
}

class _ManagerFinancialPageState extends State<ManagerFinancialPage> {
  static const Color _navy = Color(0xFF01579B);
  bool _loading = true;
  List<Charge> _charges = [];
  List<PendingPayment> _pending = [];
  String _search = '';
  Map<String, List<Map<String, dynamic>>> _adjust = {};

  bool get _canWrite => Session.role == AppRole.manager || Session.role == AppRole.admin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await ServerDirectory.ensureLoaded(force: true);
      final rows = await Backend.client
          .from('tuition_plans')
          .select('id, student_id, total, lines, archive_requested_by, archive_requested_reason, '
              'students(full_name, classes(name)), tuition_schedule(id, seq, amount, due_jalali, settled, kind)')
          .filter('archived_at', 'is', null)
          .filter('archive_requested_by', 'is', null)
          .filter('campaign_id', 'is', null)
          .order('created_at', ascending: false)
          .limit(500);
      final list = [for (final r in rows) Charge.fromPlan(Map<String, dynamic>.from(r))];
      final pending = await ManagerPaymentService.pending();
      final adjRows = await PaymentResolutionService.adjustments([for (final c in list) c.id]);
      final adjMap = <String, List<Map<String, dynamic>>>{};
      for (final r in adjRows) {
        adjMap.putIfAbsent('${r['plan_id']}', () => []).add(r);
      }
      if (!mounted) return;
      setState(() {
        _charges = list;
        _pending = pending;
        _adjust = adjMap;
        _loading = false;
      });
    } catch (e) {
      debugPrint('financial load failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('❌ خواندن اطلاعات مالی انجام نشد: $e', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  String _money(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('،');
      b.write(s[i]);
    }
    return b.toString();
  }

  Future<void> _run(Future<void> Function() action, String okMsg) async {
    try {
      await action();
      _snack(okMsg, Colors.green);
      await _load();
    } catch (e) {
      debugPrint('financial action failed: $e');
      _snack('❌ انجام نشد: ${'$e'.replaceFirst('Exception: ', '')}', Colors.red);
    }
  }

  Future<void> _setSettled(ScheduleItem s, bool value) => _run(() async {
        await Backend.client.from('tuition_schedule').update({
          'settled': value,
          'settled_at': value ? DateTime.now().toUtc().toIso8601String() : null,
        }).eq('id', s.id);
      }, value ? '✅ پرداخت ثبت شد' : 'وضعیت پرداخت برگشت خورد');

  Future<String?> _askReason(String title, String hint) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            maxLines: 2,
            decoration: InputDecoration(labelText: hint, border: const OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ثبت')),
          ],
        ),
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return null;
    if (text.length < 5) {
      _snack('دلیل را کامل‌تر بنویس (حداقل ۵ حرف)', Colors.orange.shade800);
      return null;
    }
    return text;
  }

  Future<void> _approveArchive(Charge c) => _run(() async {
        await Backend.client.rpc('approve_plan_archive', params: {'p_plan': c.id});
      }, '✅ بایگانی تأیید شد');

  Future<void> _archiveStudent(String studentId, String name) async {
    final reason = await _askReason('بایگانی مالی «$name»', 'دلیل بایگانی');
    if (reason == null) return;
    await _run(() async {
      await Backend.client.rpc('archive_student_plans', params: {'p_student': studentId, 'p_reason': reason});
    }, '✅ بندهای این نوآموز بایگانی یا برای تأیید ثبت شدند');
  }

  Future<void> _addDialog({Charge? editing}) async {
    await ServerDirectory.ensureLoaded(force: true);
    if (!mounted) return;
    final students = ServerDirectory.students;
    if (students.isEmpty) {
      _snack('هنوز نوآموزی ثبت نشده است', Colors.orange.shade800);
      return;
    }

    ServerStudent? student = students.first;
    final feeOn = {for (final f in kFeeTypes) f: false};
    final feeAmt = {for (final f in kFeeTypes) f: TextEditingController()};
    bool cashOn = true;
    bool instOn = false;
    final cashSet = _StageSet(1);
    final instSet = _StageSet(3);
    final paidAlready = editing?.paid ?? 0;

    int feeTotal() => kFeeTypes.fold<int>(
        0, (a, f) => a + (feeOn[f]! ? (int.tryParse(feeAmt[f]!.text.trim()) ?? 0) : 0));
    int dueTotal() => feeTotal() - paidAlready;
    int cashPart() {
      final t = dueTotal();
      if (cashOn && instOn) {
        final sum = cashSet.values.fold<int>(0, (a, b) => a + (b < 0 ? 0 : b));
        return sum > t ? t : sum;
      }
      return cashOn ? t : 0;
    }

    int instPart() => dueTotal() - cashPart();
    void syncStages() {
      final t = dueTotal();
      if (cashOn && !instOn) cashSet.regen(t);
      if (instOn && !cashOn) instSet.regen(t);
      if (cashOn && instOn) instSet.regen(t - cashPart());
    }

    if (editing != null) {
      final e = editing;
      student = students.firstWhere((x) => x.id == e.studentId, orElse: () => students.first);
      for (final l in e.lines) {
        final f = '${l['fee_type']}';
        if (feeOn.containsKey(f)) {
          feeOn[f] = true;
          feeAmt[f]!.text = '${l['amount']}';
        }
      }
      final cs = e.schedule.where((x) => x.kind == 'cash' && !x.settled).toList();
      final ins = e.schedule.where((x) => x.kind != 'cash' && !x.settled).toList();
      cashOn = cs.isNotEmpty;
      instOn = ins.isNotEmpty;
      if (cs.isNotEmpty) {
        cashSet.count = cs.length;
        cashSet.regen(0);
        for (int i = 0; i < cs.length; i++) {
          cashSet.amounts[i].text = '${cs[i].amount}';
          cashSet.dues[i].text = cs[i].due;
        }
      }
      if (ins.isNotEmpty) {
        instSet.count = ins.length;
        instSet.regen(0);
        for (int i = 0; i < ins.length; i++) {
          instSet.amounts[i].text = '${ins[i].amount}';
          instSet.dues[i].text = ins[i].due;
        }
      }
    } else {
      syncStages();
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final total = feeTotal();
          final cT = cashPart();
          final iT = instPart();
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              child: Container(
                width: 760,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.92),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(editing == null ? 'ثبت بند مالی جدید' : 'ویرایش بند مالی',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (editing != null)
                              InputDecorator(
                                decoration: const InputDecoration(labelText: 'نوآموز', border: OutlineInputBorder(), isDense: true),
                                child: Text('${student?.name ?? ''} • ${student?.className ?? ''}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              )
                            else
                            DropdownButtonFormField<ServerStudent>(
                              initialValue: student,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'نوآموز', border: OutlineInputBorder(), isDense: true),
                              items: [
                                for (final s in students)
                                  DropdownMenuItem(
                                      value: s, child: Text('${s.name} • ${s.className}', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (v) => setD(() => student = v),
                            ),
                            const SizedBox(height: 14),
                            _sectionTitle('۱) هزینه‌هایی که شامل این نوآموز می‌شود'),
                            for (final f in kFeeTypes)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: feeOn[f],
                                      activeColor: _navy,
                                      onChanged: (v) => setD(() {
                                        feeOn[f] = v ?? false;
                                        syncStages();
                                      }),
                                    ),
                                    Expanded(child: Text(f, style: const TextStyle(fontWeight: FontWeight.w600))),
                                    SizedBox(
                                      width: 180,
                                      child: TextField(
                                        controller: feeAmt[f],
                                        enabled: feeOn[f] == true,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setD(syncStages),
                                        decoration: const InputDecoration(
                                            labelText: 'مبلغ (تومان)', border: OutlineInputBorder(), isDense: true),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 6, bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFE1F5FE), borderRadius: BorderRadius.circular(12)),
                              child: Text('مبلغ کل (جمع هزینه‌های تیک‌خورده): ${_money(total)} تومان',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: _navy)),
                            ),
                            const SizedBox(height: 10),
                            _sectionTitle('۲) روش پرداخت (هر دو را می‌توانی انتخاب کنی)'),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilterChip(
                                  label: const Text('نقدی'),
                                  selected: cashOn,
                                  onSelected: (v) => setD(() {
                                    if (!v && !instOn) return;
                                    cashOn = v;
                                    if (v && instOn) cashSet.regen(0);
                                    syncStages();
                                  }),
                                ),
                                FilterChip(
                                  label: const Text('قسطی'),
                                  selected: instOn,
                                  onSelected: (v) => setD(() {
                                    if (!v && !cashOn) return;
                                    instOn = v;
                                    if (v && cashOn) cashSet.regen(0);
                                    syncStages();
                                  }),
                                ),
                              ],
                            ),
                            if (cashOn)
                              _stageEditor(
                                title: 'بخش نقدی',
                                set: cashSet,
                                target: cT,
                                regenTotal: instOn ? 0 : dueTotal(),
                                mustMatch: !instOn,
                                maxCount: 3,
                                labelWord: 'مرحله',
                                update: setD,
                              ),
                            if (instOn)
                              _stageEditor(
                                title: 'بخش قسطی',
                                set: instSet,
                                target: iT,
                                regenTotal: iT,
                                mustMatch: true,
                                maxCount: 10,
                                labelWord: 'قسط',
                                update: setD,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Text('مبلغ کل پرداخت: ${_money(total)} تومان'
                              '${paidAlready > 0 ? ' • پرداخت‌شده: ${_money(paidAlready)} • باقی‌مانده: ${_money(total - paidAlready)}' : ''}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
                        ),
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
                        const SizedBox(width: 8),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ثبت')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    try {
      if (ok != true) return;
      final chosen = student;
      if (chosen == null) {
        _snack('نوآموز را انتخاب کن', Colors.orange.shade800);
        return;
      }
      final fees = <MapEntry<String, int>>[
        for (final f in kFeeTypes)
          if (feeOn[f]!) MapEntry(f, int.tryParse(feeAmt[f]!.text.trim()) ?? 0),
      ];
      if (fees.isEmpty) {
        _snack('حداقل یک هزینه را تیک بزن', Colors.orange.shade800);
        return;
      }
      final badFee = fees.where((e) => e.value <= 0).map((e) => e.key).toList();
      if (badFee.isNotEmpty) {
        _snack('مبلغ «${badFee.first}» را وارد کن', Colors.orange.shade800);
        return;
      }
      if (!cashOn && !instOn && dueTotal() > 0) {
        _snack('حداقل یکی از نقدی یا قسطی را انتخاب کن', Colors.orange.shade800);
        return;
      }
      if (feeTotal() < paidAlready) {
        _snack('مبلغ کل نمی‌تواند از مبلغ پرداخت‌شده کمتر باشد', Colors.orange.shade800);
        return;
      }
      final total = dueTotal();
      if (cashOn && instOn && total > 0) {
        final c = cashPart();
        if (c <= 0 || c >= total) {
          _snack('مبلغ نقدی باید بیشتر از صفر و کمتر از کل باشد', Colors.orange.shade800);
          return;
        }
      }
      final cashVals = cashOn ? cashSet.values : <int>[];
      final instVals = instOn ? instSet.values : <int>[];
      if (cashVals.any((v) => v < 0) || instVals.any((v) => v < 0)) {
        _snack('مبلغ مرحله‌ها و قسط‌ها را درست وارد کن', Colors.orange.shade800);
        return;
      }
      if (cashOn && cashVals.fold<int>(0, (a, b) => a + b) != cashPart()) {
        _snack('جمع مرحله‌های نقدی باید ${_money(cashPart())} تومان باشد', Colors.orange.shade800);
        return;
      }
      if (instOn && instVals.fold<int>(0, (a, b) => a + b) != instPart()) {
        _snack('جمع قسط‌ها باید ${_money(instPart())} تومان باشد', Colors.orange.shade800);
        return;
      }

      final lines = [
        for (final e in fees) {'fee_type': e.key, 'fee_title': e.key, 'amount': e.value, 'included': true},
      ];
      final schedule = <Map<String, dynamic>>[];
      var sc = 0;
      for (int j = 0; j < cashVals.length; j++) {
        if (cashVals[j] <= 0) continue;
        schedule.add({'seq': ++sc, 'kind': 'cash', 'amount': cashVals[j], 'due_jalali': cashSet.dues[j].text.trim()});
      }
      var si = 0;
      for (int j = 0; j < instVals.length; j++) {
        if (instVals[j] <= 0) continue;
        schedule.add({'seq': ++si, 'kind': 'installment', 'amount': instVals[j], 'due_jalali': instSet.dues[j].text.trim()});
      }
      final planTotal = fees.fold<int>(0, (a, e) => a + e.value);

      await _run(() async {
        if (editing == null) {
          await Backend.client.rpc('create_tuition_plan', params: {
            'p_student': chosen.id,
            'p_total': planTotal,
            'p_lines': lines,
            'p_schedule': schedule,
          });
        } else {
          await Backend.client.rpc('replace_tuition_plan', params: {
            'p_old': editing.id,
            'p_student': chosen.id,
            'p_total': planTotal,
            'p_lines': lines,
            'p_schedule': schedule,
          });
        }
      }, editing == null ? '✅ بند مالی ثبت شد' : '✅ بند مالی ویرایش شد (نسخهٔ قبلی بایگانی شد)');
    } finally {
      cashSet.dispose();
      instSet.dispose();
      for (final c in feeAmt.values) {
        c.dispose();
      }
    }
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: _navy)),
      );

  Widget _stageEditor({
    required String title,
    required _StageSet set,
    required int target,
    required int regenTotal,
    required bool mustMatch,
    required int maxCount,
    required String labelWord,
    required void Function(VoidCallback) update,
  }) {
    final sum = set.values.fold<int>(0, (a, b) => a + (b < 0 ? 0 : b));
    final remaining = target - sum;
    final String footer;
    final Color color;
    if (mustMatch) {
      if (remaining == 0) {
        footer = 'جمع کامل شد ✔';
        color = const Color(0xFF2E9E6B);
      } else if (remaining > 0) {
        footer = 'باقی‌مانده: ${_money(remaining)} تومان';
        color = const Color(0xFFE5484D);
      } else {
        footer = 'بیشتر از مبلغ این بخش است: ${_money(-remaining)} تومان';
        color = const Color(0xFFE5484D);
      }
    } else {
      footer = 'جمع وارد شده: ${_money(sum)} تومان';
      color = const Color(0xFF244E76);
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD5E3F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('$title (${_money(target)} تومان)', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              DropdownButton<int>(
                value: set.count,
                items: [
                  for (int i = 1; i <= maxCount; i++) DropdownMenuItem(value: i, child: Text('$i $labelWord')),
                ],
                onChanged: (v) => update(() {
                  set.count = v ?? set.count;
                  set.regen(regenTotal);
                }),
              ),
            ],
          ),
          for (int i = 0; i < set.amounts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text('$labelWord ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: set.amounts[i],
                      keyboardType: TextInputType.number,
                      onChanged: (_) => update(() {}),
                      decoration: const InputDecoration(labelText: 'مبلغ', border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: set.dues[i],
                      decoration: const InputDecoration(
                          labelText: 'تاریخ سررسید', hintText: '۱۴۰۶/۰۱/۱۵', border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                ],
              ),
            ),
          Text(footer, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Future<void> _exportExcel() async {
    await ExportHelper.exportToExcel(
      context: context,
      title: 'گزارش مالی و شهریه',
      headers: const ['نوآموز', 'کلاس', 'بخش', 'عنوان', 'مبلغ', 'شمول', 'پرداخت‌شده', 'مانده', 'وضعیت'],
      rows: _exportRows(),
      fileName: 'financial_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<void> _exportPdf() async {
    await ExportHelper.exportToPdf(
      context: context,
      title: 'گزارش رسمی مالی و شهریه',
      headers: const ['نوآموز', 'کلاس', 'عنوان', 'مبلغ', 'پرداخت‌شده', 'مانده', 'وضعیت'],
      rows: [
        for (final c in _charges.where(_matchesSearch))
          [c.studentName, c.className, c.title, _money(c.amount), _money(c.paid), _money(c.balance), c.status],
      ],
      fileName: 'financial_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  List<List<dynamic>> _exportRows() => [
        for (final c in _charges.where(_matchesSearch))
          [
            c.studentName,
            c.className,
            c.feeType,
            c.title,
            c.amount,
            c.included ? 'شامل' : 'غیرشمول',
            c.paid,
            c.balance,
            c.status,
          ],
      ];

  bool _matchesSearch(Charge c) {
    if (_search.trim().isEmpty) return true;
    final q = _search.trim().toLowerCase();
    return c.studentName.toLowerCase().contains(q) ||
        c.className.toLowerCase().contains(q) ||
        c.title.toLowerCase().contains(q) ||
        c.feeType.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _charges.where(_matchesSearch).toList();
    final byStudent = <String, List<Charge>>{};
    for (final c in visible) {
      byStudent.putIfAbsent(c.studentName, () => []).add(c);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Text('امور مالی و شهریه'),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'کمپین‌های مالی',
              icon: const Icon(Icons.folder_special_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CampaignsPage()),
              ).then((_) => _load()),
            ),
            IconButton(
              tooltip: 'ساخت کمپین مالی',
              icon: const Icon(Icons.campaign_rounded),
              onPressed: () => showCampaignDialog(context),
            ),
            IconButton(tooltip: 'اکسل', icon: const Icon(Icons.table_chart_rounded), onPressed: _exportExcel),
            IconButton(tooltip: 'PDF', icon: const Icon(Icons.picture_as_pdf_rounded), onPressed: _exportPdf),
            IconButton(
              tooltip: 'پیش‌نمایش کارت مدرسه',
              icon: const Icon(Icons.credit_card_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SchoolCardPreviewPage()),
              ),
            ),
            IconButton(
              tooltip: 'بایگانی',
              icon: const Icon(Icons.folder_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArchiveFolderPage()),
              ).then((_) => _load()),
            ),
            IconButton(tooltip: 'به‌روزرسانی', icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          ],
        ),
        floatingActionButton: _canWrite
            ? FloatingActionButton.extended(
                onPressed: _addDialog,
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('بند مالی جدید'),
              )
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'جستجوی نوآموز، کلاس یا عنوان هزینه...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  if (_pending.isNotEmpty) _pendingSection(),
                  Expanded(
                    child: byStudent.isEmpty
                        ? const Center(child: Text('هنوز بند مالی ثبت نشده است.', style: TextStyle(color: Colors.grey)))
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                            children: [for (final e in byStudent.entries) _studentCard(e.key, e.value)],
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _pendingSection() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('پرداخت‌های در انتظار تأیید (${_pending.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 15)),
          ),
          for (final p in _pending) _pendingCard(p),
        ],
      ),
    );
  }

  Widget _pendingCard(PendingPayment p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${p.studentName} • ${p.className}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text('مبلغ: ${_money(p.amount)} تومان • شماره پیگیری: ${p.receiptNo}',
                style: const TextStyle(fontSize: 13)),
            Text('ثبت شده: ${p.dateText}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            for (final it in p.items)
              Text('• $it', style: const TextStyle(fontSize: 12, color: Colors.black87)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _approve(p),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('تأیید'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reject(p),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('رد'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(PendingPayment p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأیید پرداخت؟'),
          content: Text('مبلغ ${_money(p.amount)} تومان از ${p.studentName} تأیید شود؟\n'
              'اقلام مربوط تسویه می‌شوند. فقط وقتی تأیید کن که پیام واریز را دیده‌ای.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأیید')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _run(() => ManagerPaymentService.approve(p.id), '✅ پرداخت تأیید شد');
  }

  Future<void> _reject(PendingPayment p) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رد پرداخت'),
          content: TextField(
            controller: ctrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'دلیل رد (الزامی)', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('رد پرداخت')),
          ],
        ),
      ),
    );
    final reason = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return;
    if (reason.length < 5) {
      _snack('دلیل رد را کامل بنویس', Colors.orange.shade800);
      return;
    }
    await _run(() => ManagerPaymentService.reject(p.id, reason), 'پرداخت رد شد و دلیل ثبت شد');
  }

  int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

  Widget _rtlDialog(Widget child) => Directionality(textDirection: TextDirection.rtl, child: child);

  Future<void> _adjustMenu(Charge c) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.keyboard_return_rounded),
                title: const Text('عودت مبلغ اضافه پرداختی'),
                onTap: () => Navigator.pop(ctx, 'refund')),
            ListTile(
                leading: const Icon(Icons.receipt_long_rounded),
                title: const Text('به‌روزرسانی رسید عودت'),
                onTap: () => Navigator.pop(ctx, 'receipt')),
          ],
        ),
      ),
    );
    if (choice == 'refund') await _overpayDialog(c);
    if (choice == 'receipt') await _receiptUpdateDialog(c);
  }

  Future<void> _overpayDialog(Charge c) async {
    final paid = await PaymentResolutionService.paidOfStudent(c.studentId);
    if (paid.isEmpty) {
      _snack('پرداخت تأییدشده‌ای برای این نوآموز نیست', Colors.orange.shade800);
      return;
    }
    String payId = '${paid.first['id']}';
    final amt = TextEditingController();
    final date = TextEditingController(text: JalaliDate.now().formatted);
    final reason = TextEditingController();
    XFile? file;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => _rtlDialog(AlertDialog(
          title: const Text('عودت مبلغ اضافه پرداختی'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: payId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'کدام پرداخت', border: OutlineInputBorder(), isDense: true),
                items: [
                  for (final p in paid)
                    DropdownMenuItem(
                        value: '${p['id']}',
                        child: Text('${_money(_toInt(p['amount']))} تومان • پیگیری ${p['receipt_no']}',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setD(() => payId = v ?? payId),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: amt,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'مبلغ عودت (تومان)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                  controller: date,
                  decoration: const InputDecoration(labelText: 'تاریخ عودت (شمسی)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                  controller: reason,
                  decoration: const InputDecoration(labelText: 'دلیل (الزامی)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
                  if (f != null) setD(() => file = f);
                },
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(file == null ? 'انتخاب عکس رسید عودت' : 'رسید: ${file!.name}'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ثبت')),
          ],
        )),
      ),
    );
    final amount = int.tryParse(amt.text.trim()) ?? 0;
    final d = date.text.trim();
    final r = reason.text.trim();
    final pid = payId;
    final f = file;
    amt.dispose();
    date.dispose();
    reason.dispose();
    if (ok != true) return;
    if (amount <= 0) {
      _snack('مبلغ عودت را درست وارد کن', Colors.orange.shade800);
      return;
    }
    if (f == null) {
      _snack('رسید عودت را انتخاب کن', Colors.orange.shade800);
      return;
    }
    if (r.length < 5) {
      _snack('دلیل را کامل‌تر بنویس', Colors.orange.shade800);
      return;
    }
    await _run(() async {
      final path = await PaymentResolutionService.uploadReceipt('refund_${c.id}', f.name, await f.readAsBytes());
      await PaymentResolutionService.overpayRefund(
          planId: c.id, paymentId: pid, amount: amount, date: d, receiptPath: path, reason: r);
    }, '✅ عودت ثبت شد');
  }

  Future<void> _receiptUpdateDialog(Charge c) async {
    final refunds = (_adjust[c.id] ?? const <Map<String, dynamic>>[]).where((a) => a['kind'] == 'refund').toList();
    if (refunds.isEmpty) {
      _snack('عودتی برای این بند ثبت نشده', Colors.orange.shade800);
      return;
    }
    String refId = '${refunds.last['id']}';
    final date = TextEditingController(text: JalaliDate.now().formatted);
    final reason = TextEditingController();
    XFile? file;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => _rtlDialog(AlertDialog(
          title: const Text('به‌روزرسانی رسید عودت'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: refId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'کدام عودت', border: OutlineInputBorder(), isDense: true),
                items: [
                  for (final a in refunds)
                    DropdownMenuItem(
                        value: '${a['id']}',
                        child: Text('${_money(_toInt(a['refund_amount']))} تومان • ${a['doc_date'] ?? ''}',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setD(() => refId = v ?? refId),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: date,
                  decoration: const InputDecoration(labelText: 'تاریخ سند (شمسی)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                  controller: reason,
                  decoration: const InputDecoration(labelText: 'دلیل به‌روزرسانی (الزامی)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
                  if (f != null) setD(() => file = f);
                },
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(file == null ? 'انتخاب رسید جدید' : 'رسید: ${file!.name}'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ثبت')),
          ],
        )),
      ),
    );
    final d = date.text.trim();
    final r = reason.text.trim();
    final rid = refId;
    final f = file;
    date.dispose();
    reason.dispose();
    if (ok != true) return;
    if (f == null) {
      _snack('رسید جدید را انتخاب کن', Colors.orange.shade800);
      return;
    }
    if (r.length < 5) {
      _snack('دلیل را کامل‌تر بنویس', Colors.orange.shade800);
      return;
    }
    await _run(() async {
      final path = await PaymentResolutionService.uploadReceipt('refund_adj_${c.id}', f.name, await f.readAsBytes());
      await PaymentResolutionService.updateRefundReceipt(refId: rid, receiptPath: path, date: d, reason: r);
    }, '✅ رسید عودت به‌روز شد');
  }

  Widget _adjustLine(Map<String, dynamic> a) {
    final kind = '${a['kind']}';
    final reason = '${a['reason'] ?? ''}';
    final date = '${a['doc_date'] ?? ''}';
    final String text;
    if (kind == 'amount_fix') {
      text = 'اصلاح مبلغ: ${_money(_toInt(a['old_amount']))} ← ${_money(_toInt(a['new_amount']))} • $reason';
    } else if (kind == 'refund') {
      text = 'عودت: ${_money(_toInt(a['refund_amount']))} تومان • $date • $reason';
    } else {
      text = 'به‌روزرسانی رسید عودت: $date • $reason';
    }
    final path = a['receipt_path'];
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, size: 14, color: _navy),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11))),
          if (path != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'نمایش رسید',
              icon: const Icon(Icons.image_outlined, size: 18),
              onPressed: () => _viewReceipt('$path'),
            ),
        ],
      ),
    );
  }

  Future<void> _viewReceipt(String path) async {
    try {
      final url = await PaymentResolutionService.signedUrl(path);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(url))),
      );
    } catch (e) {
      _snack('نمایش رسید ممکن نیست: $e', Colors.red);
    }
  }

  Widget _studentCard(String name, List<Charge> items) {
    final included = items.where((c) => c.included).toList();
    final total = included.fold<int>(0, (a, c) => a + c.amount);
    final paid = included.fold<int>(0, (a, c) => a + c.paid);
    final balance = total - paid;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'کلاس: ${items.first.className} • جمع: ${_money(total)} • پرداخت‌شده: ${_money(paid)} • مانده: ${_money(balance)}',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          if (_canWrite)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _archiveStudent(items.first.studentId, name),
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: const Text('بایگانی'),
              ),
            ),
          if (_canWrite)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => TuitionAgreementDialog(
                    studentId: items.first.studentId,
                    studentName: name,
                    paid: items.fold<int>(0, (a, c) => a + c.paid),
                    debt: items.fold<int>(0, (a, c) => a + c.balance),
                  ),
                ),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('متن توافق‌نامه'),
              ),
            ),
          for (final c in items) _chargeTile(c),
        ],
      ),
    );
  }

  Widget _chargeTile(Charge c) {
    final me = Backend.client.auth.currentUser?.id;
    final hasRequest = c.requestedBy.isNotEmpty;
    final canApprove = hasRequest && c.requestedBy != me;
    final modeLabel = c.mode == 'mixed' ? 'نقدی و قسطی' : (c.mode == 'cash' ? 'نقدی' : 'قسطی');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade300))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Text('${_money(c.amount)} تومان', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (_canWrite) ...[
                IconButton(
                  tooltip: 'ویرایش هزینه‌ها',
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  onPressed: () => _addDialog(editing: c),
                ),
                IconButton(
                  tooltip: 'اصلاح مبلغ، عودت یا رسید',
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  onPressed: () => _adjustMenu(c),
                ),
              ],
            ],
          ),
          Text(
            '$modeLabel • پرداخت‌شده: ${_money(c.paid)} • مانده: ${_money(c.balance)} • ${c.status}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          for (final a in (_adjust[c.id] ?? const <Map<String, dynamic>>[])) _adjustLine(a),
          if (hasRequest)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'درخواست بایگانی ثبت شده: ${c.requestReason}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFE5484D), fontWeight: FontWeight.bold),
              ),
            ),
          if (canApprove)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => _approveArchive(c),
                child: const Text('تأیید بایگانی (مدیر دوم)'),
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in c.schedule)
                FilterChip(
                  selected: s.settled,
                  label: Text(
                    '${s.kind == 'cash' ? 'مرحله' : 'قسط'} ${s.seq} • ${_money(s.amount)}${s.due.isEmpty ? '' : ' • ${s.due}'}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  selectedColor: Colors.green.shade100,
                  onSelected: _canWrite ? (v) => _setSettled(s, v) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }

}

/// یک مجموعه مرحله (نقدی) یا قسط (قسطی) در فرم بند مالی
class _StageSet {
  int count;
  List<TextEditingController> amounts = [];
  List<TextEditingController> dues = [];

  _StageSet(this.count);

  List<int> get values => [for (final c in amounts) int.tryParse(c.text.trim()) ?? -1];

  /// مبلغ را مساوی بین مرحله‌ها تقسیم می‌کند؛ باقی‌مانده به آخرین مرحله می‌رود
  void regen(int total) {
    final n = count;
    final base = total ~/ n;
    final remainder = total - base * n;
    final oldDues = [for (final d in dues) d.text];
    for (final c in amounts) {
      c.dispose();
    }
    for (final d in dues) {
      d.dispose();
    }
    amounts = [
      for (int i = 0; i < n; i++) TextEditingController(text: '${i == n - 1 ? base + remainder : base}'),
    ];
    dues = [
      for (int i = 0; i < n; i++) TextEditingController(text: i < oldDues.length ? oldDues[i] : ''),
    ];
  }

  void dispose() {
    for (final c in amounts) {
      c.dispose();
    }
    for (final d in dues) {
      d.dispose();
    }
  }
}
