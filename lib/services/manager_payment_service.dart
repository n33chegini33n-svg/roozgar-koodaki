import 'package:supabase_flutter/supabase_flutter.dart' as sup;
import '../utils/jalali.dart';
import 'backend.dart';

/// یک پرداخت ولی که منتظر تأیید مدیر است
class PendingPayment {
  final String id;
  final String studentName;
  final String className;
  final int amount;
  final String receiptNo;
  final DateTime createdAt;
  final List<String> items;

  const PendingPayment({
    required this.id,
    required this.studentName,
    required this.className,
    required this.amount,
    required this.receiptNo,
    required this.createdAt,
    required this.items,
  });

  String get dateText => faDigits(JalaliDate.fromDateTime(createdAt).formatted);
}

class ManagerPaymentService {
  static int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

  /// پرداخت‌های در انتظار، قدیمی‌ترین اول
  static Future<List<PendingPayment>> pending() async {
    final rows = await Backend.client
        .from('tuition_payments')
        .select('id, amount, receipt_no, created_at, '
            'students(full_name, classes(name)), '
            'tuition_payment_items(amount, tuition_schedule(seq, tuition_charges(fee_title, payment_mode)))')
        .eq('status', 'pending')
        .order('created_at', ascending: true);

    return [
      for (final r in rows)
        _fromRow(Map<String, dynamic>.from(r)),
    ];
  }

  static PendingPayment _fromRow(Map<String, dynamic> r) {
    final st = r['students'];
    final cls = st is Map ? st['classes'] : null;
    final rawItems = (r['tuition_payment_items'] as List?) ?? const [];
    final items = <String>[];
    for (final it in rawItems) {
      final sched = it['tuition_schedule'];
      final charge = sched is Map ? sched['tuition_charges'] : null;
      final title = charge is Map ? '${charge['fee_title'] ?? ''}' : '';
      final mode = charge is Map ? '${charge['payment_mode'] ?? ''}' : '';
      final seq = sched is Map ? '${sched['seq'] ?? ''}' : '';
      items.add('$title • ${mode == 'installment' ? 'قسط' : 'مرحله'} $seq • ${_int(it['amount'])} تومان');
    }
    return PendingPayment(
      id: '${r['id']}',
      studentName: st is Map ? '${st['full_name'] ?? ''}' : '',
      className: cls is Map ? '${cls['name'] ?? ''}' : '',
      amount: _int(r['amount']),
      receiptNo: '${r['receipt_no'] ?? ''}',
      createdAt: DateTime.parse('${r['created_at']}').toLocal(),
      items: items,
    );
  }

  static Future<void> approve(String paymentId, {String note = ''}) async {
    try {
      await Backend.client.rpc('approve_tuition_payment', params: {
        'p_payment': paymentId,
        'p_note': note,
      });
    } on sup.PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  static Future<void> reject(String paymentId, String reason) async {
    try {
      await Backend.client.rpc('reject_tuition_payment', params: {
        'p_payment': paymentId,
        'p_reason': reason,
      });
    } on sup.PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }
}
