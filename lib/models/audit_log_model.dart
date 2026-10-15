import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'permissions.dart';
import '../services/backend.dart';

/// یک ردیف گزارش تغییرات. این لاگ فقط افزودنی است: API حذف یا ویرایش ندارد.
class AuditEntry {
  final String id;
  final int timestamp;
  final String actor;
  final String role;
  final String action;
  final String details;

  const AuditEntry({
    required this.id,
    required this.timestamp,
    required this.actor,
    required this.role,
    required this.action,
    required this.details,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp,
        'actor': actor,
        'role': role,
        'action': action,
        'details': details,
      };

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        id: j['id'] ?? '',
        timestamp: j['timestamp'] ?? 0,
        actor: j['actor'] ?? '',
        role: j['role'] ?? '',
        action: j['action'] ?? '',
        details: j['details'] ?? '',
      );
}

class AuditLogService {
  static const String _key = 'audit_log_v1';
  static const int _maxEntries = 20000;
  static List<AuditEntry>? _cache;

  static Future<List<AuditEntry>> _serverAll() async {
    try {
      final rows = await Backend.client
          .from('audit_log')
          .select('id, actor_name, actor_role, action, details, created_at')
          .order('created_at', ascending: false)
          .limit(500);
      return [
        for (final r in rows)
          AuditEntry(
            id: '${r['id']}',
            timestamp: DateTime.parse(r['created_at'] as String).millisecondsSinceEpoch,
            actor: (r['actor_name'] ?? '') as String,
            role: AppRole.values.where((x) => x.name == r['actor_role']).map((x) => x.label).firstOrNull ?? '',
            action: (r['action'] ?? '') as String,
            details: (r['details'] ?? '') as String,
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<List<AuditEntry>> getAll() async {
    if (Backend.ready) return _serverAll();
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return _cache = [];
    try {
      final list = jsonDecode(raw) as List;
      return _cache = list.map((e) => AuditEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return _cache = [];
    }
  }

  /// ثبت یک رویداد (جدیدترین اول)
  static Future<void> log({
    required String actor,
    required String role,
    required String action,
    required String details,
  }) async {
    if (Backend.ready) {
      // در حالت سرور، هویت فرد را خود دیتابیس تعیین می‌کند
      try {
        await Backend.client.rpc('write_audit', params: {'p_action': action, 'p_details': details});
      } catch (_) {}
      return;
    }
    final all = await getAll();
    final now = DateTime.now().millisecondsSinceEpoch;
    all.insert(
      0,
      AuditEntry(id: 'AUD-$now-${all.length}', timestamp: now, actor: actor, role: role, action: action, details: details),
    );
    if (all.length > _maxEntries) all.removeRange(_maxEntries, all.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all.map((e) => e.toJson()).toList()));
  }
}
