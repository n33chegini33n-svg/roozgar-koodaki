import '../models/audit_log_model.dart';
import '../models/permissions.dart';
import 'backend.dart';

/// توافق‌نامه‌های نوآموز. هر ذخیره یک نسخهٔ جدید است.
/// وضعیت: pending (در انتظار تأیید ولی) | confirmed (تأیید شده) | superseded (نسخهٔ قدیمی)
class TuitionAgreementService {
  static Future<Map<String, dynamic>?> latest(String studentId) async {
    final rows = await Backend.client
        .from('tuition_agreements')
        .select('id, body, fields, status, confirmed_at, created_at')
        .eq('student_id', studentId)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  static Future<void> save({
    required String studentId,
    required String studentName,
    required String body,
    required Map<String, String> fields,
  }) async {
    await Backend.client.from('tuition_agreements').insert({
      'student_id': studentId,
      'body': body,
      'fields': fields,
      'status': 'pending',
      'created_by': Backend.client.auth.currentUser?.id,
    });
    await AuditLogService.log(
      actor: Session.userName,
      role: Session.role.label,
      action: 'ثبت توافق‌نامه مالی',
      details: studentName,
    );
  }

  /// برای ولی: توافق‌نامه‌های در انتظار تأیید فرزندان خودش
  static Future<List<Map<String, dynamic>>> parentPending() async {
    final rows = await Backend.client
        .from('tuition_agreements')
        .select('id, body, student_id, created_at, students(full_name)')
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> confirm(String id) async {
    await Backend.client.rpc('confirm_agreement', params: {'p_id': id});
  }

  static String statusText(Map<String, dynamic> row) {
    switch ('${row['status'] ?? ''}') {
      case 'confirmed':
        final at = '${row['confirmed_at'] ?? ''}';
        return 'تأییدشده توسط ولی${at.isEmpty ? '' : ' • ${at.substring(0, 10)}'}';
      case 'superseded':
        return 'نسخهٔ قدیمی';
      default:
        return 'در انتظار تأیید ولی';
    }
  }
}
