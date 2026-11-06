import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/tuition_agreement_service.dart';
import '../utils/jalali.dart';

const Color _navy = Color(0xFF01579B);

String _fa(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('،');
    b.write(s[i]);
  }
  return faDigits(b.toString());
}

/// متن توافق‌نامه بر اساس فیلدهای فرم ساخته می‌شود
String buildAgreementBody({
  required String manager,
  required String parent,
  required String parentNid,
  required String student,
  required String date,
  required int paid,
  required int refund,
  required int debt,
}) {
  final refundText = refund > 0
      ? 'مبلغ ${_fa(refund)} تومان به ولی عودت شده است و رسید آن در پروندهٔ نوآموز ثبت شده است.'
      : 'هیچ مبلغی به ولی عودت داده نمی‌شود.';
  final debtText = debt > 0
      ? 'مانده ${_fa(debt)} تومان که هنوز پرداخت نشده، بخشیده می‌شود و مدیریت حق مطالبهٔ آن را ندارد.'
      : 'مانده‌ای برای پرداخت وجود ندارد.';
  return '''توافق‌نامهٔ ادامهٔ مسیر و تعیین تکلیف مبالغ پرداختی

ماده ۱. طرفین: مدیریت مجموعهٔ آموزشی روزگار کودکی (به نمایندگی $manager) و آقای/خانم $parent با کد ملی $parentNid، ولی قانونی نوآموز $student.

ماده ۲. موضوع: نوآموز از تاریخ $date از ادامهٔ حضور در مجموعه انصراف داده است. طرفین با آگاهی از صورت‌حساب مالی ثبت‌شده در سامانه، تعیین تکلیف مبالغ زیر را توافق کرده‌اند.

ماده ۳. مبالغ پرداختی: مجموع مبالغی که ولی تا تاریخ انصراف پرداخت کرده، ${_fa(paid)} تومان است.

ماده ۴. عدم عودت: طرفین توافق دارند که مبالغ پرداختی بابت ثبت‌نام، خدمات آموزشی، غذا، سرویس و سایر خدماتی که تا تاریخ انصراف ارائه شده یا برای آن آماده‌سازی شده است، بهای خدمات انجام‌شده تلقی شود و قابل استرداد نباشد.

ماده ۵. عودت: $refundText

ماده ۶. مانده بدهی: $debtText

ماده ۷. ادامهٔ مسیر: در صورت بازگشت نوآموز به مجموعه، طرفین می‌توانند پرونده مالی جدیدی با شرایط جدید تنظیم کنند. این توافق مانع آن نیست.

ماده ۸. اقرار و رضایت: ولی اقرار می‌کند که مفاد این توافق و مبالغ آن را خوانده و با آگاهی و بدون اجبار پذیرفته است.

ماده ۹. اسناد: پیوست‌ها و سوابق ثبت‌شده در سامانهٔ مجموعه، همراه با رسیدهای پرداخت، مدارک مورد قبول طرفین است.

ماده ۱۰. حل اختلاف: در صورت اختلاف، طرفین ابتدا مذاکره می‌کنند و در غیر این صورت مرجع صالح دادگاه محل مجموعه است.

ماده ۱۱. تأیید: ولی با تیک «آگاه و موافقم» این توافق را تأیید می‌کند و تاریخ و زمان تأیید ثبت می‌شود.

مدیر: $manager        امضا/تأیید ولی: ..............''';
}

class TuitionAgreementDialog extends StatefulWidget {
  final String studentId;
  final String studentName;
  final int paid;
  final int debt;
  const TuitionAgreementDialog({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.paid,
    required this.debt,
  });

  @override
  State<TuitionAgreementDialog> createState() => _TuitionAgreementDialogState();
}

class _TuitionAgreementDialogState extends State<TuitionAgreementDialog> {
  final _parent = TextEditingController();
  final _nid = TextEditingController();
  final _date = TextEditingController(text: JalaliDate.now().formatted);
  final _refund = TextEditingController(text: '0');
  final _debt = TextEditingController();
  final _body = TextEditingController();
  final _manager = TextEditingController(text: 'مدیریت مجموعه');
  bool _loading = true;
  bool _saving = false;
  String? _lastSaved;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _debt.text = '${widget.debt}';
    _load();
  }

  @override
  void dispose() {
    for (final c in [_parent, _nid, _date, _refund, _debt, _body, _manager]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final last = await TuitionAgreementService.latest(widget.studentId);
      if (last != null) {
        _body.text = '${last['body']}';
        final f = Map<String, dynamic>.from((last['fields'] as Map?) ?? {});
        _parent.text = '${f['parent'] ?? ''}';
        _nid.text = '${f['nid'] ?? ''}';
        _refund.text = '${f['refund'] ?? '0'}';
        _debt.text = '${f['debt'] ?? _debt.text}';
        _lastSaved = '${last['created_at']}'.substring(0, 10);
        _status = TuitionAgreementService.statusText(last);
      } else {
        _rebuild();
      }
    } catch (e) {
      _rebuild();
      _snack('خواندن نسخهٔ قبلی انجام نشد: $e', Colors.orange.shade800);
    }
    if (mounted) setState(() => _loading = false);
  }

  int _n(TextEditingController c) => int.tryParse(c.text.trim().replaceAll('،', '').replaceAll(',', '')) ?? 0;

  void _rebuild() {
    _body.text = buildAgreementBody(
      manager: _manager.text.trim(),
      parent: _parent.text.trim().isEmpty ? '..............' : _parent.text.trim(),
      parentNid: _nid.text.trim().isEmpty ? '..............' : _nid.text.trim(),
      student: widget.studentName,
      date: _date.text.trim(),
      paid: widget.paid,
      refund: _n(_refund),
      debt: _n(_debt),
    );
  }

  Map<String, String> _fields() => {
        'parent': _parent.text.trim(),
        'nid': _nid.text.trim(),
        'date': _date.text.trim(),
        'refund': _refund.text.trim(),
        'debt': _debt.text.trim(),
        'manager': _manager.text.trim(),
      };

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
  }

  Future<void> _save() async {
    if (_body.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await TuitionAgreementService.save(
        studentId: widget.studentId,
        studentName: widget.studentName,
        body: _body.text,
        fields: _fields(),
      );
      _snack('✅ توافق‌نامه در پروندهٔ نوآموز ذخیره شد', Colors.green);
      if (mounted) {
        setState(() {
          _lastSaved = JalaliDate.now().formatted;
          _status = 'در انتظار تأیید ولی';
        });
      }
    } catch (e) {
      _snack('❌ ذخیره انجام نشد: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String label, {bool number = false, bool readOnly = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          readOnly: readOnly,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 760,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
          padding: const EdgeInsets.all(18),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('توافق‌نامه: ${widget.studentName}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _navy)),
                    if (_lastSaved != null)
                      Text('آخرین ذخیره: $_lastSaved • وضعیت: $_status', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Row(children: [
                              Expanded(child: _field(_parent, 'نام ولی')),
                              const SizedBox(width: 8),
                              Expanded(child: _field(_nid, 'کد ملی ولی')),
                            ]),
                            Row(children: [
                              Expanded(child: _field(_date, 'تاریخ انصراف (شمسی)')),
                              const SizedBox(width: 8),
                              Expanded(child: _field(_manager, 'نام مدیر')),
                            ]),
                            Row(children: [
                              Expanded(child: _field(TextEditingController(text: _fa(widget.paid)), 'مجموع پرداختی (تومان)', readOnly: true)),
                              const SizedBox(width: 8),
                              Expanded(child: _field(_refund, 'مبلغ عودت (تومان، ۰ یعنی عودت نشده)', number: true)),
                            ]),
                            _field(_debt, 'مانده بخشیده‌شده (تومان)', number: true),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () => setState(_rebuild),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('ساخت دوباره متن از فرم (ویرایش‌های دستی پاک می‌شود)'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _body,
                              maxLines: 18,
                              decoration: const InputDecoration(
                                labelText: 'متن توافق‌نامه (قابل ویرایش)',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: _body.text));
                            _snack('متن کپی شد؛ در واتساپ یا ایتا جای‌گذاری کنید', Colors.green);
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('کپی متن برای ولی'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن')),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save_rounded),
                          label: Text(_saving ? 'در حال ذخیره...' : 'ذخیره در پروندهٔ نوآموز'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
