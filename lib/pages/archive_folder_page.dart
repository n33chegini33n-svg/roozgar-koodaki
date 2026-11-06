import 'package:flutter/material.dart';
import '../models/permissions.dart';
import '../services/backend.dart';
import '../services/tuition_agreement_service.dart';
import '../theme/app_colors.dart';
import '../utils/jalali.dart';
import 'student_payments_section.dart';

String _money(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('،');
    b.write(s[i]);
  }
  return faDigits(b.toString());
}

/// پوشهٔ بایگانی: بندهای بایگانی‌شدهٔ نوآموزان، درخواست‌های بایگانی و توافق‌نامه‌ها
class ArchiveFolderPage extends StatefulWidget {
  const ArchiveFolderPage({super.key});

  @override
  State<ArchiveFolderPage> createState() => _ArchiveFolderPageState();
}

class _ArchiveFolderPageState extends State<ArchiveFolderPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _groups = [];

  bool get _canAct => PermissionService.instance.can(Session.role, Perm.viewFinancial);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final plans = await Backend.client
          .from('tuition_plans')
          .select('id, student_id, total, archived_at, archive_reason, archive_requested_by, '
              'archive_requested_reason, students(full_name, classes(name)), tuition_schedule(amount, settled)')
          .or('archived_at.not.is.null,archive_requested_by.not.is.null')
          .order('archived_at', ascending: false);

      final agreements = await Backend.client
          .from('tuition_agreements')
          .select('student_id, body, status, confirmed_at, created_at')
          .order('created_at', ascending: false);

      final latestAgreement = <String, Map<String, dynamic>>{};
      for (final a in agreements) {
        final sid = '${a['student_id']}';
        latestAgreement.putIfAbsent(sid, () => Map<String, dynamic>.from(a));
      }

      final groups = <String, Map<String, dynamic>>{};
      for (final p in plans) {
        final sid = '${p['student_id']}';
        final st = p['students'];
        final g = groups.putIfAbsent(sid, () => {
              'studentId': sid,
              'name': st is Map ? '${st['full_name'] ?? ''}' : '',
              'class': st is Map && st['classes'] is Map ? '${st['classes']['name'] ?? ''}' : '',
              'plans': <Map<String, dynamic>>[],
              'agreement': latestAgreement[sid],
            });
        (g['plans'] as List<Map<String, dynamic>>).add(Map<String, dynamic>.from(p));
      }
      if (!mounted) return;
      setState(() {
        _groups = groups.values.toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('خواندن بایگانی انجام نشد: $e', Colors.red);
    }
  }

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
  }

  Future<void> _run(Future<void> Function() action, String ok) async {
    try {
      await action();
      _snack(ok, Colors.green);
      await _load();
    } catch (e) {
      _snack('❌ ${'$e'}', Colors.red);
    }
  }

  void _showAgreement(Map<String, dynamic> a, String name) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('توافق‌نامه: $name'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(child: SelectableText('${a['body'] ?? ''}', style: const TextStyle(height: 1.8))),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))],
        ),
      ),
    );
  }

  Widget _planTile(Map<String, dynamic> p) {
    final me = Backend.client.auth.currentUser?.id;
    final schedule = (p['tuition_schedule'] as List?) ?? const [];
    final paid = schedule.where((s) => s['settled'] == true).fold<int>(0, (a, s) => a + ((s['amount'] as num?)?.toInt() ?? 0));
    final total = (p['total'] as num?)?.toInt() ?? 0;
    final archived = p['archived_at'] != null;
    final requestedBy = '${p['archive_requested_by'] ?? ''}';
    final requested = requestedBy.isNotEmpty && !archived;
    final archivedDate = archived ? '${p['archived_at']}'.substring(0, 10) : '';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD5E3F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('بند مالی • مبلغ کل ${_money(total)} تومان • پرداخت‌شده ${_money(paid)} • مانده ${_money(total - paid)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          if (archived)
            Text('بایگانی‌شده در $archivedDate • دلیل: ${p['archive_reason'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          if (requested)
            Text('درخواست بایگانی (منتظر تأیید مدیر دوم): ${p['archive_requested_reason'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFE5484D), fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              if (_canAct && archived)
                OutlinedButton.icon(
                  onPressed: () => _run(() async {
                    await Backend.client.rpc('restore_plan', params: {'p_plan': p['id']});
                  }, '✅ بند به لیست فعال برگشت'),
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: const Text('بازگردانی'),
                ),
              if (_canAct && requested && requestedBy != me)
                FilledButton.icon(
                  onPressed: () => _run(() async {
                    await Backend.client.rpc('approve_plan_archive', params: {'p_plan': p['id']});
                  }, '✅ بایگانی تأیید شد'),
                  icon: const Icon(Icons.verified_rounded, size: 18),
                  label: const Text('تأیید بایگانی (مدیر دوم)'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _agreementRow(Map<String, dynamic>? a, String name) {
    if (a == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('توافق‌نامه‌ای ثبت نشده است', style: TextStyle(fontSize: 12, color: Colors.black54)),
      );
    }
    final status = TuitionAgreementService.statusText(a);
    final confirmed = '${a['status']}' == 'confirmed';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(confirmed ? Icons.verified_rounded : Icons.hourglass_bottom_rounded,
              size: 18, color: confirmed ? const Color(0xFF2E9E6B) : const Color(0xFFF59E0B)),
          const SizedBox(width: 6),
          Expanded(
            child: Text('توافق‌نامه: $status',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                    color: confirmed ? const Color(0xFF2E9E6B) : const Color(0xFFF59E0B))),
          ),
          TextButton.icon(
            onPressed: () => _showAgreement(a, name),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('مشاهده متن'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Text('بایگانی'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.navy,
          elevation: 0,
          actions: [IconButton(tooltip: 'به‌روزرسانی', icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _groups.isEmpty
                ? const Center(child: Text('بایگانی خالی است', style: TextStyle(color: AppColors.textGrey)))
                : ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      for (final g in _groups)
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${g['name']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy)),
                                Text('${g['class']}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                for (final p in (g['plans'] as List<Map<String, dynamic>>)) _planTile(p),
                                StudentPaymentsSection(
                                  studentId: '${g['studentId']}',
                                  studentName: '${g['name']}',
                                  canAct: _canAct,
                                  allowResolve: true,
                                  agreement: g['agreement'] as Map<String, dynamic>?,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}
