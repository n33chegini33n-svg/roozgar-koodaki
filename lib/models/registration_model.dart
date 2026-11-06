import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backend.dart';
import 'audit_log_model.dart';
import 'permissions.dart';

const String kRegTable = 'registration_records';
const String kRegBucket = 'registration-docs';
const String kRegNameKey = 'نام نوآموز';
const String kRegAttachKey = 'لینک/پیوست شناسنامه';
const String kRegNoChange = 'بدون تغییر در فیلدها';

/// یک پرونده = یک فرزند. کلید یکتا: id
class RegistrationDraft {
  final String id;
  final String parentId;
  final String studentName;
  final Map<String, String> values;
  final String status; // draft | submitted | approved | rejected
  final String? rejectionReason;
  final String? attachmentUrl; // مسیر فایل در باکت؛ منبع واحد
  final int editCount;
  final bool isDeleted;

  const RegistrationDraft({
    required this.id,
    required this.parentId,
    required this.studentName,
    required this.values,
    required this.status,
    this.rejectionReason,
    this.attachmentUrl,
    this.editCount = 0,
    this.isDeleted = false,
  });

  factory RegistrationDraft.fromJson(Map<String, dynamic> j) {
    final raw = j['data'];
    final values = raw is Map ? raw.map((k, v) => MapEntry('$k', '${v ?? ''}')) : <String, String>{};
    final att = j['attachment_url']?.toString();
    return RegistrationDraft(
      id: '${j['id'] ?? ''}',
      parentId: '${j['parent_id'] ?? ''}',
      studentName: '${j['student_name'] ?? values[kRegNameKey] ?? ''}',
      values: Map<String, String>.from(values),
      status: '${j['status'] ?? 'draft'}',
      rejectionReason: j['rejection_reason']?.toString(),
      attachmentUrl: (att == null || att.isEmpty) ? null : att,
      editCount: (j['edit_count'] as num?)?.toInt() ?? 0,
      isDeleted: j['is_deleted'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'parent_id': parentId,
    'student_name': studentName,
    'data': values,
    'status': status,
    'rejection_reason': rejectionReason,
    'attachment_url': attachmentUrl,
    'edit_count': editCount,
    'is_deleted': isDeleted,
  };

  RegistrationDraft copyWith({
    String? studentName,
    Map<String, String>? values,
    String? status,
    String? rejectionReason,
    bool clearReason = false,
    String? attachmentUrl,
    int? editCount,
    bool? isDeleted,
  }) =>
      RegistrationDraft(
        id: id,
        parentId: parentId,
        studentName: studentName ?? this.studentName,
        values: values ?? this.values,
        status: status ?? this.status,
        rejectionReason: clearReason ? null : (rejectionReason ?? this.rejectionReason),
        attachmentUrl: attachmentUrl ?? this.attachmentUrl,
        editCount: editCount ?? this.editCount,
        isDeleted: isDeleted ?? this.isDeleted,
      );
}

class RegistrationDraftService {
  static String get _uid => Backend.ready ? (Backend.client.auth.currentUser?.id ?? 'anon') : 'demo';
  static String get _localKey => 'registration_children_v2_${_uid}';
  static String _now() => DateTime.now().toUtc().toIso8601String();

  static String label(String s) => switch (s) {
    'approved' => 'تأیید شده',
    'submitted' => 'در انتظار بررسی',
    'rejected' => 'نیاز به اصلاح',
    _ => 'پیش‌نویس',
  };

  static Future<void> _audit(String action, String details) => AuditLogService.log(
    actor: Session.userName,
    role: Session.role.label,
    action: action,
    details: details,
  );

  /// فهرست تغییر: «فیلد: قبل ← بعد» (فیلد مدرک نادیده گرفته می‌شود)
  static String diff(Map<String, String> before, Map<String, String> after) {
    final lines = <String>[];
    for (final k in {...before.keys, ...after.keys}) {
      if (k == kRegAttachKey) continue;
      final a = before[k] ?? '';
      final b = after[k] ?? '';
      if (a != b) lines.add('$k: $a ← $b');
    }
    return lines.isEmpty ? kRegNoChange : lines.join(' | ');
  }

  // ---------- حالت محلی (بدون سرور) ----------
  static Future<List<RegistrationDraft>> _localAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return [for (final e in jsonDecode(raw) as List) RegistrationDraft.fromJson(Map<String, dynamic>.from(e as Map))];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _localPut(List<RegistrationDraft> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localKey, jsonEncode([for (final d in list) d.toJson()]));
  }

  static Future<void> _localUpdate(String id, RegistrationDraft Function(RegistrationDraft d) f) async {
    final list = await _localAll();
    final i = list.indexWhere((d) => d.id == id);
    if (i < 0) return;
    list[i] = f(list[i]);
    await _localPut(list);
  }

  // ---------- سمت والد ----------
  /// فرزندان فعال این ولی (هر فرزند یک رکورد مستقل)
  static Future<List<RegistrationDraft>> myChildren() async {
    if (!Backend.ready) return (await _localAll()).where((d) => !d.isDeleted).toList();
    final uid = Backend.client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await Backend.client
        .from(kRegTable)
        .select('*')
        .eq('parent_id', uid)
        .eq('is_deleted', false)
        .order('created_at');
    return [for (final r in rows) RegistrationDraft.fromJson(Map<String, dynamic>.from(r))];
  }

  static Future<RegistrationDraft> createChild(String name) async {
    if (!Backend.ready) {
      final d = RegistrationDraft(
        id: 'L-${DateTime.now().millisecondsSinceEpoch}',
        parentId: _uid,
        studentName: name,
        values: {kRegNameKey: name},
        status: 'draft',
      );
      final list = await _localAll();
      list.add(d);
      await _localPut(list);
      return d;
    }
    final uid = Backend.client.auth.currentUser!.id;
    final row = await Backend.client
        .from(kRegTable)
        .insert({
      'parent_id': uid,
      'student_name': name,
      'data': {kRegNameKey: name},
      'status': 'draft',
      'is_deleted': false,
      'edit_count': 0,
    })
        .select('*')
        .single();
    return RegistrationDraft.fromJson(Map<String, dynamic>.from(row));
  }

  /// ذخیرهٔ پیش‌رفت (پیش‌نویس یا نیازمند اصلاح). وضعیت و سهمیه تغییر نمی‌کند.
  static Future<void> saveDraft(RegistrationDraft d, Map<String, String> values) async {
    if (d.status == 'approved' || d.status == 'submitted') {
      throw Exception('این پرونده در این وضعیت با ذخیرهٔ پیش‌نویس ویرایش نمی‌شود');
    }
    final name = values[kRegNameKey] ?? d.studentName;
    final merged = {...values, kRegAttachKey: d.attachmentUrl ?? ''};
    if (!Backend.ready) {
      await _localUpdate(d.id, (x) => x.copyWith(values: merged, studentName: name));
      return;
    }
    await Backend.client
        .from(kRegTable)
        .update({'data': merged, 'student_name': name, 'updated_at': _now()})
        .eq('id', d.id);
  }

  /// ارسال یا ارسال مجدد. ویرایش پرونده ارسال‌شده فقط یک بار مجاز است.
  static Future<void> submitRecord(RegistrationDraft d, Map<String, String> values, {required bool confirmed}) async {
    if (!confirmed) throw Exception('تأیید تعهدنامه الزامی است');
    if (d.status == 'approved') throw Exception('این پرونده تأیید شده و قابل ارسال نیست');
    final name = values[kRegNameKey] ?? d.studentName;
    final merged = {...values, kRegAttachKey: d.attachmentUrl ?? ''};
    final changed = diff(d.values, merged) != kRegNoChange;
    var count = d.editCount;
    if (d.status == 'submitted' && changed) {
      if (count >= 1) throw Exception('سهمیه ویرایش این پرونده تمام شده است');
      count += 1;
    }
    if (!Backend.ready) {
      await _localUpdate(
        d.id,
            (x) => x.copyWith(
          values: merged,
          studentName: name,
          status: 'submitted',
          clearReason: true,
          editCount: count,
        ),
      );
    } else {
      await Backend.client.from(kRegTable).update({
        'data': merged,
        'student_name': name,
        'status': 'submitted',
        'submitted_at': _now(),
        'rejection_reason': null,
        'edit_count': count,
        'updated_at': _now(),
      }).eq('id', d.id);
    }
    if (changed) await _audit('ویرایش پرونده نوآموز: $name', diff(d.values, merged));
    if (d.status != 'submitted') {
      await _audit('تغییر وضعیت پرونده ثبت‌نام', '$name: ${label(d.status)} ← ${label('submitted')}');
    }
  }

  /// آپلود مدرک: مسیر فقط در attachment_url و کپی آن در data نگهداری می‌شود
  static Future<RegistrationDraft> uploadDocument(RegistrationDraft d, Uint8List bytes, String ext) async {
    if (!Backend.ready) throw Exception('ارسال مدرک فقط با اتصال به سرور ممکن است');
    final uid = Backend.client.auth.currentUser!.id;
    final path = '$uid/${d.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await Backend.client.storage.from(kRegBucket).uploadBinary(path, bytes);
    final values = {...d.values, kRegAttachKey: path};
    await Backend.client
        .from(kRegTable)
        .update({'attachment_url': path, 'data': values, 'updated_at': _now()})
        .eq('id', d.id);
    return d.copyWith(attachmentUrl: path, values: values);
  }

  /// حذف یا بازیابی نرم (سطل بازیافت)
  static Future<void> setDeleted({required String id, required String name, required bool deleted}) async {
    if (!Backend.ready) {
      await _localUpdate(id, (x) => x.copyWith(isDeleted: deleted));
    } else {
      await Backend.client
          .from(kRegTable)
          .update({'is_deleted': deleted, 'deleted_at': deleted ? _now() : null})
          .eq('id', id);
    }
    await _audit(deleted ? 'حذف پرونده ثبت‌نام' : 'بازیابی پرونده ثبت‌نام', name);
  }

  // ---------- سمت مدیر (فقط سرور) ----------
  static Future<List<Map<String, dynamic>>> staffRows({required bool deleted}) async {
    if (!Backend.ready) return [];
    final rows = await Backend.client
        .from(kRegTable)
        .select('*')
        .eq('is_deleted', deleted)
        .order('updated_at', ascending: false);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  static Future<String> documentUrl(String path) =>
      Backend.client.storage.from(kRegBucket).createSignedUrl(path, 300);

  /// تغییر وضعیت با شناسهٔ رکورد
  static Future<void> setStatus({
    required String id,
    required String name,
    required String from,
    required String to,
    String? reason,
  }) async {
    final r = (reason ?? '').trim();
    if (to == 'rejected' && r.isEmpty) throw Exception('برای رد پرونده، دلیل را بنویسید');
    if (!Backend.ready) return;
    await Backend.client.from(kRegTable).update({
      'status': to,
      'rejection_reason': to == 'rejected' ? r : null,
      'updated_at': _now(),
    }).eq('id', id);
    await _audit(
      'تغییر وضعیت پرونده ثبت‌نام',
      '$name: ${label(from)} ← ${label(to)}${to == 'rejected' ? ' • دلیل: $r' : ''}',
    );
  }

  /// ویرایش توسط مدیر با شناسهٔ رکورد (بدون تأثیر روی فرزندان دیگر)
  static Future<void> staffSave({
    required String id,
    required String oldName,
    required Map<String, String> before,
    required Map<String, String> after,
  }) async {
    if (!Backend.ready) return;
    final name = after[kRegNameKey] ?? oldName;
    final merged = {...after, kRegAttachKey: before[kRegAttachKey] ?? ''};
    await Backend.client.from(kRegTable).update({
      'data': merged,
      'student_name': name,
      'updated_at': _now(),
    }).eq('id', id);
    await _audit('ویرایش پرونده نوآموز: $name', diff(before, merged));
  }
}