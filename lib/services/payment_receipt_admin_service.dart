import 'package:supabase_flutter/supabase_flutter.dart' as sup;
import 'backend.dart';

/// رسید پرداخت برای مدیر (با نام نوآموز). RLS و تابع سمت سرور مرجع نهایی‌اند.
class AdminPaymentReceipt {
  final String id;
  final String studentName;
  final int amount;
  final String referenceNo;
  final String state; // pending | approved | rejected
  final String decisionNote;
  final DateTime createdAt;

  const AdminPaymentReceipt({
    required this.id,
    required this.studentName,
    required this.amount,
    required this.referenceNo,
    required this.state,
    required this.decisionNote,
    required this.createdAt,
  });

  factory AdminPaymentReceipt.fromJson(Map<String, dynamic> j) {
    final s = j['students'];
    return AdminPaymentReceipt(
      id: '${j['id']}',
      studentName: s is Map ? '${s['full_name'] ?? ''}' : '',
      amount: (j['amount'] as num?)?.toInt() ?? 0,
      referenceNo: '${j['reference_no'] ?? ''}',
      state: '${j['state'] ?? 'pending'}',
      decisionNote: '${j['decision_note'] ?? ''}',
      createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
    );
  }
}

class PaymentReceiptAdminService {
  /// همهٔ رسیدها؛ جدیدترین اول. خطا به بالا پرتاب می‌شود.
  static Future<List<AdminPaymentReceipt>> all() async {
    final rows = await Backend.client
        .from('payment_receipts')
        .select('id, amount, reference_no, state, decision_note, created_at, students(full_name)')
        .order('created_at', ascending: false)
        .limit(300);
    return rows
        .map<AdminPaymentReceipt>((r) => AdminPaymentReceipt.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// تأیید یا رد از طریق تابع سمت سرور. خطا به بالا پرتاب می‌شود.
  static Future<void> decide({
    required String receiptId,
    required bool approve,
    required String note,
  }) async {
    try {
      await Backend.client.rpc('decide_payment_receipt', params: {
        'p_receipt': receiptId,
        'p_approve': approve,
        'p_note': note,
      });
    } on sup.PostgrestException catch (e) {
      throw Exception('ثبت تصمیم انجام نشد: ${e.message}');
    }
  }
}
