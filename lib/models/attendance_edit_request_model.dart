import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'attendance_archive_model.dart';
import 'audit_log_model.dart';
import 'school_classes.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sup;
import '../services/backend.dart';
import '../utils/jalali.dart';

/// درخواست اصلاح یک رکورد حضور و غیاب قفل‌شده
class AttendanceEditRequest {
  final String id;
  final String recordId;
  final String studentName;
  final String className;
  final String date;
  final String oldStatus;
  final String newStatus;
  final String reason;
  final String requestedBy;
  final int createdAt;
  final String state; // pending | approved | rejected
  final String decidedBy;
  final String decisionNote;
  final int decidedAt;

  const AttendanceEditRequest({
    required this.id,
    required this.recordId,
    required this.studentName,
    required this.className,
    required this.date,
    required this.oldStatus,
    required this.newStatus,
    required this.reason,
    required this.requestedBy,
    required this.createdAt,
    this.state = 'pending',
    this.decidedBy = '',
    this.decisionNote = '',
    this.decidedAt = 0,
  });

  AttendanceEditRequest decided({
    required bool approved,
    required String by,
    required String note,
  }) =>
      AttendanceEditRequest(
        id: id,
        recordId: recordId,
        studentName: studentName,
        className: className,
        date: date,
        oldStatus: oldStatus,
        newStatus: newStatus,
        reason: reason,
        requestedBy: requestedBy,
        createdAt: createdAt,
        state: approved ? 'approved' : 'rejected',
        decidedBy: by,
        decisionNote: note,
        decidedAt: DateTime.now().millisecondsSinceEpoch,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'recordId': recordId,
        'studentName': studentName,
        'className': className,
        'date': date,
        'oldStatus': oldStatus,
        'newStatus': newStatus,
        'reason': reason,
        'requestedBy': requestedBy,
        'createdAt': createdAt,
        'state': state,
        'decidedBy': decidedBy,
        'decisionNote': decisionNote,
        'decidedAt': decidedAt,
      };

  factory AttendanceEditRequest.fromJson(Map<String, dynamic> j) => AttendanceEditRequest(
        id: j['id'] ?? '',
        recordId: j['recordId'] ?? '',
        studentName: j['studentName'] ?? '',
        className: normalizeClassName(((j['className']) ?? '').toString()),
        date: j['date'] ?? '',
        oldStatus: j['oldStatus'] ?? '',
        newStatus: j['newStatus'] ?? '',
        reason: j['reason'] ?? '',
        requestedBy: j['requestedBy'] ?? '',
        createdAt: j['createdAt'] ?? 0,
        state: j['state'] ?? 'pending',
        decidedBy: j['decidedBy'] ?? '',
        decisionNote: j['decisionNote'] ?? '',
        decidedAt: j['decidedAt'] ?? 0,
      );
}

class EditRequestService {
  static final RegExp _uuidPattern =
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  /// شناسهٔ رکورد روی سرور باید uuid باشد. اگر رکورد تازه ثبت شده و هنوز شناسهٔ محلی دارد،
  /// شناسهٔ واقعی را از سرور می‌گیریم.
  static Future<String> _serverRecordId(AttendanceRecord record) async {
    if (_uuidPattern.hasMatch(record.id)) return record.id;
    final fresh = await AttendanceArchiveService.recordsFor(record.className, record.date);
    for (final r in fresh) {
      if (r.studentName == record.studentName && _uuidPattern.hasMatch(r.id)) return r.id;
    }
    throw Exception('رکورد این نوآموز روی سرور پیدا نشد؛ صفحه را دوباره باز کنید');
  }

  static const String _srvSel =
      'id, record_id, requested_status, old_status, reason, state, decision_note, created_at, decided_at, '
      'requester:profiles!attendance_edit_requests_requested_by_fkey(full_name), '
      'decider:profiles!attendance_edit_requests_decided_by_fkey(full_name), '
      'attendance_records(day, status, students(full_name), classes(name))';

  static String _nm(dynamic v) => v is Map && v['full_name'] is String ? v['full_name'] as String : '';

  static Future<List<AttendanceEditRequest>> _serverAll() async {
    final rows = await Backend.client
        .from('attendance_edit_requests')
        .select(_srvSel)
        .order('created_at', ascending: false)
        .limit(500);
    final out = <AttendanceEditRequest>[];
    for (final r in rows) {
      final rec = r['attendance_records'];
      final recMap = rec is Map ? rec : const {};
      final cls = recMap['classes'];
      final day = recMap['day'] is String ? DateTime.parse(recMap['day'] as String) : null;
      out.add(
        AttendanceEditRequest(
          id: r['id'] as String,
          recordId: r['record_id'] as String,
          studentName: _nm(recMap['students']),
          className: normalizeClassName(cls is Map && cls['name'] is String ? cls['name'] as String : ''),
          date: day == null ? '' : JalaliDate.fromDateTime(day).formatted,
          oldStatus: AttendanceStatusCodec.toLabel((r['old_status'] ?? recMap['status'] ?? 'present') as String),
          newStatus: AttendanceStatusCodec.toLabel(r['requested_status'] as String),
          reason: (r['reason'] ?? '') as String,
          requestedBy: _nm(r['requester']),
          createdAt: DateTime.parse(r['created_at'] as String).millisecondsSinceEpoch,
          state: (r['state'] ?? 'pending') as String,
          decidedBy: _nm(r['decider']),
          decisionNote: (r['decision_note'] ?? '') as String,
          decidedAt: r['decided_at'] is String ? DateTime.parse(r['decided_at'] as String).millisecondsSinceEpoch : 0,
        ),
      );
    }
    return out;
  }

  static const String _key = 'attendance_edit_requests_v1';
  static List<AttendanceEditRequest>? _cache;

  static Future<List<AttendanceEditRequest>> getAll() async {
    if (Backend.ready) return _serverAll();
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return _cache = [];
    try {
      final list = jsonDecode(raw) as List;
      return _cache =
          list.map((e) => AttendanceEditRequest.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return _cache = [];
    }
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_cache!.map((e) => e.toJson()).toList()));
  }

  /// ثبت درخواست. اگر برای همان رکورد درخواست «در انتظار» باشد، false برمی‌گردد.
  static Future<bool> create({
    required AttendanceRecord record,
    required String newStatus,
    required String reason,
    required String requestedBy,
    required String requesterRole,
  }) async {
    if (Backend.ready) {
      try {
        final serverId = await _serverRecordId(record);
        await Backend.client.from('attendance_edit_requests').insert({
          'record_id': serverId,
          'requested_status': AttendanceStatusCodec.toCode(newStatus),
          'old_status': AttendanceStatusCodec.toCode(record.status),
          'reason': reason,
        });
        return true;
      } on sup.PostgrestException catch (e) {
        if (e.code == '23505') return false; // برای این رکورد درخواست در انتظار هست
        throw Exception('ارسال درخواست انجام نشد: ${e.message}');
      }
    }
    final all = await getAll();
    if (all.any((r) => r.recordId == record.id && r.state == 'pending')) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    all.insert(
      0,
      AttendanceEditRequest(
        id: 'REQ-$now',
        recordId: record.id,
        studentName: record.studentName,
        className: record.className,
        date: record.date,
        oldStatus: record.status,
        newStatus: newStatus,
        reason: reason,
        requestedBy: requestedBy,
        createdAt: now,
      ),
    );
    await _save();
    await AuditLogService.log(
      actor: requestedBy,
      role: requesterRole,
      action: 'درخواست اصلاح حضور و غیاب',
      details: '${record.studentName} • ${record.date}: ${record.status} ← $newStatus • دلیل: $reason',
    );
    return true;
  }

  /// تأیید یا رد. در صورت تأیید، رکورد بایگانی اصلاح می‌شود.
  static Future<void> decide({
    required String requestId,
    required bool approved,
    required String by,
    required String byRole,
    required String note,
  }) async {
    if (Backend.ready) {
      try {
        await Backend.client.rpc('decide_attendance_edit', params: {
          'p_request': requestId,
          'p_approve': approved,
          'p_note': note,
        });
      } on sup.PostgrestException catch (e) {
        throw Exception('ثبت تصمیم انجام نشد: ${e.message}');
      }
      AttendanceArchiveService.clearCache();
      return;
    }
    final all = await getAll();
    final i = all.indexWhere((r) => r.id == requestId);
    if (i < 0 || all[i].state != 'pending') return;
    final req = all[i];
    if (approved) {
      await AttendanceArchiveService.updateStatus(req.recordId, req.newStatus);
    }
    all[i] = req.decided(approved: approved, by: by, note: note);
    await _save();
    await AuditLogService.log(
      actor: by,
      role: byRole,
      action: approved ? 'تأیید اصلاح حضور و غیاب' : 'رد اصلاح حضور و غیاب',
      details:
          '${req.studentName} • ${req.date}: ${req.oldStatus} ← ${req.newStatus} • درخواست‌دهنده: ${req.requestedBy}${note.isEmpty ? '' : ' • یادداشت: $note'}',
    );
  }
}
