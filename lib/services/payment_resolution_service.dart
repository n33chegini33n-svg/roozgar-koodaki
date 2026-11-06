import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart' as sup;
import 'backend.dart';

/// تعیین تکلیف پرداخت‌ها و اسناد عودت و اصلاح بندهای مالی
class PaymentResolutionService {
  static const String bucket = 'financial-receipts';

  static Future<List<Map<String, dynamic>>> paidOfStudent(String studentId) async {
    final rows = await Backend.client
        .from('tuition_payments')
        .select('id, amount, receipt_no, created_at, resolution, refund_amount, refund_date, '
            'refund_receipt_path, resolution_note, forgiven_amount')
        .eq('student_id', studentId)
        .eq('status', 'paid')
        .order('created_at', ascending: false);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<List<Map<String, dynamic>>> adjustments(List<String> planIds) async {
    if (planIds.isEmpty) return [];
    final rows = await Backend.client
        .from('charge_adjustments')
        .select('id, plan_id, payment_id, ref_id, kind, old_amount, new_amount, refund_amount, '
            'doc_date, receipt_path, reason, created_at')
        .inFilter('plan_id', planIds)
        .order('created_at', ascending: true);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<String> uploadReceipt(String folder, String fileName, Uint8List bytes) async {
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$folder/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await Backend.client.storage
        .from(bucket)
        .uploadBinary(path, bytes, fileOptions: const sup.FileOptions(upsert: false));
    return path;
  }

  static Future<String> signedUrl(String path) =>
      Backend.client.storage.from(bucket).createSignedUrl(path, 300);

  static Future<void> resolveSplit({
    required String paymentId,
    required int refund,
    String? refundDate,
    String? receiptPath,
    required int forgiven,
    required String note,
  }) async {
    await Backend.client.rpc('resolve_payment_split', params: {
      'p_payment': paymentId,
      'p_refund': refund,
      'p_refund_date': refundDate,
      'p_receipt': receiptPath,
      'p_forgiven': forgiven,
      'p_note': note,
    });
  }

  static Future<void> adjustAmount({
    required String planId,
    required int newAmount,
    required String reason,
  }) async {
    await Backend.client.rpc('adjust_plan_amount', params: {
      'p_plan': planId,
      'p_new': newAmount,
      'p_reason': reason,
    });
  }

  static Future<void> overpayRefund({
    required String planId,
    required String paymentId,
    required int amount,
    required String date,
    required String receiptPath,
    required String reason,
  }) async {
    await Backend.client.rpc('record_overpay_refund', params: {
      'p_plan': planId,
      'p_payment': paymentId,
      'p_amount': amount,
      'p_date': date,
      'p_receipt': receiptPath,
      'p_reason': reason,
    });
  }

  static Future<void> updateRefundReceipt({
    required String refId,
    required String receiptPath,
    required String date,
    required String reason,
  }) async {
    await Backend.client.rpc('update_refund_receipt', params: {
      'p_ref': refId,
      'p_receipt': receiptPath,
      'p_date': date,
      'p_reason': reason,
    });
  }
}
