import 'package:supabase_flutter/supabase_flutter.dart' as sup;
import 'backend.dart';

/// یک قسط یا مرحلهٔ پرداخت
class ParentSchedule {
  final String id;
  final int seq;
  final int amount;
  final String due;
  final bool settled;
  final String kind; // cash | installment

  const ParentSchedule({
    required this.id,
    required this.seq,
    required this.amount,
    required this.due,
    required this.settled,
    this.kind = 'installment',
  });
}

/// یک پلن پرداخت برای فرزند ولی
class ParentCharge {
  final String id;
  final String studentId;
  final String studentName;
  final String title;
  final String feeType;
  final String mode; // cash | installment | mixed
  final int amount;
  final List<ParentSchedule> schedule;

  const ParentCharge({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.title,
    required this.feeType,
    required this.mode,
    required this.amount,
    required this.schedule,
  });
}

/// یک پرداخت ثبت‌شدهٔ ولی
class ParentPayment {
  final String id;
  final int amount;
  final String status; // pending | paid | failed
  final String receiptNo;
  final DateTime createdAt;

  const ParentPayment({
    required this.id,
    required this.amount,
    required this.status,
    required this.receiptNo,
    required this.createdAt,
  });
}

class ParentPaymentService {
  // شمارهٔ کارت نمونه؛ بعداً از تنظیمات سرور خوانده می‌شود
  static const String schoolCardNumber = '6037997012345678';
  static const String schoolCardOwner = 'مجموعه آموزشی روزگار کودکی';
  static const String schoolBankName = 'بانک نمونه';

  static int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

  /// پلن‌های فعال فرزندان این ولی (سرور فقط فرزندان خودش و بایگانی‌نشده‌ها را برمی‌گرداند)
  static Future<List<ParentCharge>> myCharges() async {
    final rows = await Backend.client
        .from('tuition_plans')
        .select('id, student_id, total, lines, created_at, students(full_name), '
            'tuition_schedule(id, seq, amount, due_jalali, settled, kind)')
        .order('created_at', ascending: true);

    final out = <ParentCharge>[];
    for (final r in rows) {
      final st = r['students'];
      final rawSchedule = (r['tuition_schedule'] as List?) ?? const [];
      final schedule = [
        for (final s in rawSchedule)
          ParentSchedule(
            id: '${s['id']}',
            seq: _int(s['seq']),
            amount: _int(s['amount']),
            due: '${s['due_jalali'] ?? ''}',
            settled: s['settled'] == true,
            kind: '${s['kind'] ?? 'installment'}',
          ),
      ]..sort((a, b) => a.kind == b.kind ? a.seq.compareTo(b.seq) : (a.kind == 'cash' ? -1 : 1));

      final lines = (r['lines'] as List?) ?? const [];
      final title = [
        for (final l in lines)
          if ('${l['fee_title'] ?? l['fee_type'] ?? ''}'.isNotEmpty) '${l['fee_title'] ?? l['fee_type']}',
      ].join('، ');
      final hasCash = schedule.any((s) => s.kind == 'cash');
      final hasInst = schedule.any((s) => s.kind != 'cash');

      out.add(ParentCharge(
        id: '${r['id']}',
        studentId: '${r['student_id']}',
        studentName: st is Map ? '${st['full_name'] ?? ''}' : '',
        title: title.isEmpty ? 'بند مالی' : title,
        feeType: '',
        mode: hasCash && hasInst ? 'mixed' : (hasCash ? 'cash' : 'installment'),
        amount: _int(r['total']),
        schedule: schedule,
      ));
    }
    return out;
  }

  static Future<List<ParentPayment>> myPayments() async {
    final rows = await Backend.client
        .from('tuition_payments')
        .select('id, amount, status, receipt_no, created_at')
        .order('created_at', ascending: false)
        .limit(50);
    return [
      for (final r in rows)
        ParentPayment(
          id: '${r['id']}',
          amount: _int(r['amount']),
          status: '${r['status'] ?? 'pending'}',
          receiptNo: '${r['receipt_no'] ?? ''}',
          createdAt: DateTime.parse('${r['created_at']}').toLocal(),
        ),
    ];
  }

  /// ثبت پرداخت. مبلغ را سرور از روی اقساط انتخابی محاسبه می‌کند، نه برنامه.
  static Future<int> submit({
    required String referenceNo,
    required List<String> scheduleIds,
  }) async {
    try {
      final res = await Backend.client.rpc('submit_tuition_payment', params: {
        'p_ref': referenceNo,
        'p_schedule_ids': scheduleIds,
      });
      return _int(res);
    } on sup.PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }
}
