import 'package:flutter/material.dart';
import '../models/permissions.dart';
import '../services/backend.dart';
import '../services/parent_payment_service.dart';
import '../theme/app_colors.dart';
import '../utils/jalali.dart';
import '../widgets/school_bank_card.dart';
import 'agreements_card.dart';
import 'parent_sections.dart' show SectionScaffold, softCard;

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<ParentCharge> _charges = [];
  List<ParentPayment> _payments = [];
  final Set<String> _selected = {};
  final TextEditingController _ref = TextEditingController();

  bool get _allowed => PermissionService.instance.can(AppRole.parent, Perm.viewFinancial);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_allowed || !Backend.ready) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final charges = await ParentPaymentService.myCharges();
      final payments = await ParentPaymentService.myPayments();
      if (!mounted) return;
      final openIds = {for (final c in charges) for (final s in c.schedule) if (!s.settled) s.id};
      setState(() {
        _charges = charges;
        _payments = payments;
        _selected.removeWhere((id) => !openIds.contains(id));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e'.replaceFirst('Exception: ', '');
        _loading = false;
      });
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
    return faDigits(b.toString());
  }

  Set<String> get _selectedStudents => {
        for (final c in _charges)
          for (final s in c.schedule)
            if (_selected.contains(s.id)) c.studentId,
      };

  int get _selectedTotal => [
        for (final c in _charges)
          for (final s in c.schedule)
            if (_selected.contains(s.id)) s.amount,
      ].fold<int>(0, (a, b) => a + b);

  Future<void> _submit() async {
    final ref = _ref.text.trim();
    if (_selected.isEmpty) return;
    if (ref.length < 4) {
      _snack('شمارهٔ پیگیری را کامل وارد کن', Colors.orange.shade800);
      return;
    }
    setState(() => _submitting = true);
    try {
      final amount = await ParentPaymentService.submit(
        referenceNo: ref,
        scheduleIds: _selected.toList(),
      );
      _selected.clear();
      _ref.clear();
      _snack('✅ پرداخت ${_money(amount)} تومان ثبت شد و منتظر تأیید مدیر است', Colors.green);
      await _load();
    } catch (e) {
      _snack('❌ ${'$e'.replaceFirst('Exception: ', '')}', Colors.red);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _statusLabel(String s) {
    if (s == 'paid') return 'تأیید شده';
    if (s == 'failed') return 'رد شده';
    return 'در انتظار تأیید';
  }

  Color _statusColor(String s) {
    if (s == 'paid') return const Color(0xFF2E9E6B);
    if (s == 'failed') return const Color(0xFFE5484D);
    return const Color(0xFFF59E0B);
  }

  Widget _scheduleTile(ParentCharge c, ParentSchedule s) {
    final label = '${s.kind == 'cash' ? 'مرحله' : 'قسط'} ${faDigits(s.seq)}';
    if (s.settled) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E9E6B)),
        title: Text('$label • پرداخت شده'),
        trailing: Text('${_money(s.amount)} تومان'),
      );
    }
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: _selected.contains(s.id),
      onChanged: _submitting
          ? null
          : (v) => setState(() {
                if (v == true) {
                  _selected.add(s.id);
                } else {
                  _selected.remove(s.id);
                }
              }),
      title: Text('$label • ${_money(s.amount)} تومان'),
      subtitle: s.due.isEmpty ? null : Text('سررسید: ${s.due}'),
    );
  }

  Widget _chargeCard(ParentCharge c) {
    return softCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${c.studentName} • ${c.title}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
          const SizedBox(height: 4),
          Text(
            '${c.mode == 'mixed' ? 'پرداخت نقدی و قسطی' : (c.mode == 'cash' ? 'پرداخت نقدی' : 'پرداخت قسطی')} • مبلغ کل: ${_money(c.amount)} تومان',
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
          const Divider(),
          for (final s in c.schedule) _scheduleTile(c, s),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final multi = _selectedStudents.length > 1;
    return softCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('جمع انتخاب‌شده: ${_money(_selectedTotal)} تومان',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy)),
          if (multi)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('برای هر پرداخت، فقط موارد یک نوآموز را انتخاب کن.',
                  style: TextStyle(color: Color(0xFFE5484D))),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _ref,
            decoration: const InputDecoration(
              labelText: 'شمارهٔ پیگیری کارت‌به‌کارت',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (_selected.isEmpty || multi || _submitting) ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.receipt_long_rounded),
              label: Text(_submitting ? 'در حال ثبت...' : 'ثبت پرداخت'),
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

  Widget _historyCard() {
    return softCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('پرداخت‌های ثبت‌شده',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
          const SizedBox(height: 8),
          if (_payments.isEmpty)
            const Text('هنوز پرداختی ثبت نشده است', style: TextStyle(color: AppColors.textGrey)),
          for (final p in _payments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 40,
                    decoration: BoxDecoration(color: _statusColor(p.status), borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_money(p.amount)} تومان',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          'پیگیری ${p.receiptNo} • ${faDigits(JalaliDate.fromDateTime(p.createdAt).formatted)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                        ),
                      ],
                    ),
                  ),
                  Text(_statusLabel(p.status),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _statusColor(p.status))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (!_allowed) {
      return softCard(
        child: const Text('دسترسی به این بخش برای شما فعال نیست.', style: TextStyle(color: AppColors.textGrey)),
      );
    }
    if (!Backend.ready) {
      return softCard(
        child: const Text('برای پرداخت، برنامه باید به سرور وصل باشد.', style: TextStyle(color: AppColors.textGrey)),
      );
    }
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return softCard(
        child: Text(_error!, style: const TextStyle(color: Color(0xFFE5484D), height: 1.6)),
      );
    }

    final open = _charges.where((c) => c.schedule.any((s) => !s.settled)).toList();
    return Column(
      children: [
        const ParentAgreementsCard(),
        const SchoolBankCard(
          cardNumber: ParentPaymentService.schoolCardNumber,
          ownerName: ParentPaymentService.schoolCardOwner,
          bankName: ParentPaymentService.schoolBankName,
        ),
        const SizedBox(height: 12),
        softCard(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('روش پرداخت: کارت به کارت',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy)),
              SizedBox(height: 8),
              Text('۱) موارد پرداخت را تیک بزن.', style: TextStyle(height: 1.8)),
              Text('۲) مبلغ را به کارت مدرسه واریز کن.', style: TextStyle(height: 1.8)),
              Text('۳) شمارهٔ پیگیری را وارد کن و ثبت پرداخت را بزن.', style: TextStyle(height: 1.8)),
              Text('۴) بعد از تأیید مدیر، وضعیت پرداخت تغییر می‌کند.', style: TextStyle(height: 1.8)),
            ],
          ),
        ),
        if (open.isEmpty)
          softCard(
            child: const Text('بند پرداخت باز ندارید.', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
          )
        else
          for (final c in open) _chargeCard(c),
        _summaryCard(),
        _historyCard(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'پرداخت شهریه و هزینه‌ها',
      image: 'scene_payment.png',
      child: _body(),
    );
  }
}
