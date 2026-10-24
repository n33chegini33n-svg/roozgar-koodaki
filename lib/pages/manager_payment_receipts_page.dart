import 'package:flutter/material.dart';
import '../models/permissions.dart';
import '../services/financial_access_policy.dart';
import '../services/payment_receipt_admin_service.dart';
import '../utils/jalali.dart';

/// رسیدهای پرداخت اولیا: مدیر و ادمین تأیید یا رد می‌کنند.
class ManagerPaymentReceiptsPage extends StatefulWidget {
  const ManagerPaymentReceiptsPage({super.key});

  @override
  State<ManagerPaymentReceiptsPage> createState() => _ManagerPaymentReceiptsPageState();
}

class _ManagerPaymentReceiptsPageState extends State<ManagerPaymentReceiptsPage> {
  static const Color _navy = Color(0xFF01579B);
  bool _loading = true;
  String? _error;
  List<AdminPaymentReceipt> _all = [];

  bool get _canRead => FinancialAccessPolicy.canReadManagementLedger(Session.role);
  bool get _canDecide => FinancialAccessPolicy.canManageLedger(Session.role);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_canRead) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await PaymentReceiptAdminService.all();
      if (!mounted) return;
      setState(() {
        _all = list;
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

  String _money(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('،');
      b.write(s[i]);
    }
    return faDigits(b.toString());
  }

  String _fmt(DateTime d) {
    final l = d.toLocal();
    final t = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    return '${faDigits(JalaliDate.fromDateTime(l).formatted)}  ${faDigits(t)}';
  }

  Color _color(String s) {
    if (s == 'approved') return const Color(0xFF2E9E6B);
    if (s == 'rejected') return const Color(0xFFE5484D);
    return const Color(0xFFF59E0B);
  }

  String _label(String s) {
    if (s == 'approved') return 'تأیید شد';
    if (s == 'rejected') return 'رد شد';
    return 'در انتظار';
  }

  Future<void> _decide(AdminPaymentReceipt r, bool approve) async {
    if (!_canDecide) return;
    final messenger = ScaffoldMessenger.of(context);
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(approve ? 'تأیید رسید' : 'رد رسید'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${r.studentName}\n${_money(r.amount)} تومان • رسید ${r.referenceNo}'),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: approve ? 'یادداشت (اختیاری)' : 'دلیل رد (الزامی)',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(approve ? 'تأیید' : 'رد')),
          ],
        ),
      ),
    );
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (ok != true) return;
    if (!approve && note.length < 3) {
      messenger.showSnackBar(const SnackBar(content: Text('برای رد، دلیل را بنویسید')));
      return;
    }
    try {
      await PaymentReceiptAdminService.decide(receiptId: r.id, approve: approve, note: note);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(approve ? 'رسید تأیید شد' : 'رسید رد شد'), backgroundColor: Colors.green),
    );
    if (!mounted) return;
    _load();
  }

  Widget _card(AdminPaymentReceipt r) {
    final c = _color(r.state);
    final pending = r.state == 'pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.studentName.isEmpty ? 'نوآموز نامشخص' : r.studentName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text(_label(r.state), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${_money(r.amount)} تومان', style: const TextStyle(fontWeight: FontWeight.bold, color: _navy)),
            const SizedBox(height: 2),
            Text('شمارهٔ پیگیری: ${r.referenceNo}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            Text(_fmt(r.createdAt), style: const TextStyle(fontSize: 11, color: Colors.black54)),
            if (r.decisionNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('یادداشت: ${r.decisionNote}', style: const TextStyle(fontSize: 12)),
            ],
            if (pending && _canDecide) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _decide(r, true),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('تأیید'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _decide(r, false),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('رد'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _list(List<AdminPaymentReceipt> items, String empty) {
    if (items.isEmpty) {
      return Center(child: Text(empty, style: const TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (_, i) => _card(items[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _all.where((r) => r.state == 'pending').toList();
    final done = _all.where((r) => r.state != 'pending').toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF3F8FF),
          appBar: AppBar(
            title: const Text('رسیدهای پرداخت'),
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'به‌روزرسانی',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _load,
              ),
            ],
            bottom: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(text: 'در انتظار (${faDigits(pending.length)})'),
                const Tab(text: 'سوابق'),
              ],
            ),
          ),
          body: !_canRead
              ? const Center(child: Text('شما اجازهٔ مشاهدهٔ رسیدها را ندارید.'))
              : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFE5484D))),
                          ),
                        )
                      : TabBarView(
                          children: [
                            _list(pending, 'رسید در انتظاری نیست'),
                            _list(done, 'هنوز سابقه‌ای نیست'),
                          ],
                        ),
        ),
      ),
    );
  }
}
