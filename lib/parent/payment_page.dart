import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../services/backend.dart';
import '../services/payment_receipt_service.dart';
import '../models/permissions.dart';
import '../models/audit_log_model.dart';
import '../models/school_classes.dart';
import '../models/tuition_record_model.dart';
import '../utils/jalali.dart';
import 'parent_sections.dart' show SectionScaffold, softCard;

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _loading = true;
  List<TuitionRecord> _records = [];
  List<PaymentReceipt> _receipts = [];
  String? _loadError;

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
    if (Backend.ready) {
      try {
        final receipts = await PaymentReceiptService.mine();
        if (!mounted) return;
        setState(() {
          _receipts = receipts;
          _loadError = null;
          _loading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _loadError = '$e'.replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
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
    final ref = refCtrl.text.trim();

    if (Backend.ready) {
      try {
        await PaymentReceiptService.submit(amount: amount, referenceNo: ref);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رسید ثبت شد و منتظر تأیید مدیر است')));
      _load();
      return;
    }

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
      receiptNo: ref,
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
    if (status.contains('معوقه') || status == 'rejected') return const Color(0xFFE5484D);
    if (status.contains('انتظار') || status == 'pending') return const Color(0xFFF59E0B);
    return const Color(0xFF2E9E6B);
  }

  String _stateLabel(String s) {
    if (s == 'approved') return 'تأیید شد';
    if (s == 'rejected') return 'رد شد';
    return 'در انتظار تأیید';
  }

  Widget _serverReceipts() {
    if (_loadError != null) {
      return softCard(
        child: Text(_loadError!, style: const TextStyle(color: Color(0xFFE5484D), height: 1.6)),
      );
    }
    if (_receipts.isEmpty) {
      return softCard(
        child: Text('هنوز رسیدی برای ${Session.childName} ثبت نشده است',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
      );
    }
    return Column(
      children: [
        for (final r in _receipts)
          softCard(
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 44,
                  decoration: BoxDecoration(color: _color(r.state), borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_money(r.amount)} تومان',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                      Text('رسید ${r.referenceNo}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      if (r.decisionNote.isNotEmpty)
                        Text(r.decisionNote, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    ],
                  ),
                ),
                Text(_stateLabel(r.state),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _color(r.state))),
              ],
            ),
          ),
      ],
    );
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
          if (Backend.ready)
            _serverReceipts()
          else ...[
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
                    Text(r.status,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _color(r.status))),
                  ],
                ),
              ),
          ],
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
