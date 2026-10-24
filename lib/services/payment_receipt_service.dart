import 'package:supabase_flutter/supabase_flutter.dart' as sup;
import '../models/permissions.dart';
import 'backend.dart';

/// رسید پرداخت ولی (حالت سرور). RLS جدول payment_receipts مرجع نهایی دسترسی است.
class PaymentReceipt {
  final String id;
  final int amount;
  final String referenceNo;
  final String state; // pending | approved | rejected
  final String decisionNote;
  final DateTime createdAt;

  const PaymentReceipt({
    required this.id,
    required this.amount,
    required this.referenceNo,
    required this.state,
    required this.decisionNote,
    required this.createdAt,
  });

  factory PaymentReceipt.fromJson(Map<String, dynamic> j) => PaymentReceipt(
    id: '${j['id']}',
    amount: (j['amount'] as num?)?.toInt() ?? 0,
    referenceNo: '${j['reference_no'] ?? ''}',
    state: '${j['state'] ?? 'pending'}',
    decisionNote: '${j['decision_note'] ?? ''}',
    createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'reference_no': referenceNo,
    'state': state,
    'decision_note': decisionNote,
    'created_at': createdAt.toIso8601String(),
  };
}

class PaymentReceiptService {
  /// رسیدهای فرزند(ان) این ولی؛ جدیدترین اول. خطا به بالا پرتاب می‌شود.
  static Future<List<PaymentReceipt>> mine() async {
    final ids = Session.childStudentIds;
    if (ids.isEmpty) return [];
    final rows = await Backend.client
        .from('payment_receipts')
        .select('id, amount, reference_no, state, decision_note, created_at')
        .inFilter('student_id', ids)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map<PaymentReceipt>((r) => PaymentReceipt.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  /// ثبت رسید جدید با وضعیت pending. خطا به بالا پرتاب می‌شود.
  static Future<void> submit({required int amount, required String referenceNo}) async {
    final ids = Session.childStudentIds;
    if (ids.isEmpty) throw Exception('نوآموز مرتبط با این حساب پیدا نشد');
    final user = Backend.client.auth.currentUser;
    if (user == null) throw Exception('ابتدا وارد شوید');
    try {
      await Backend.client.from('payment_receipts').insert({
        'parent_id': user.id,
        'student_id': ids.first,
        'amount': amount,
        'reference_no': referenceNo,
        'state': 'pending',
      });
    } on sup.PostgrestException catch (e) {
      throw Exception('ثبت رسید انجام نشد: ${e.message}');
    }
  }
}