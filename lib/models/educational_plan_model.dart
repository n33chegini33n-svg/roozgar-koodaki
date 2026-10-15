import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'audit_log_model.dart';
import 'permissions.dart';
import 'school_classes.dart';
import '../services/backend.dart';
import '../services/backend_directory.dart';
import '../utils/jalali.dart';

class EducationalPlan {
  final String id;
  final String title;
  final String description;
  final String className;
  final String date; // تاریخ شمسی ثبت
  final String createdBy;

  const EducationalPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.className,
    required this.date,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'className': className,
        'date': date,
        'createdBy': createdBy,
      };

  factory EducationalPlan.fromJson(Map<String, dynamic> j) => EducationalPlan(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        className: normalizeClassName(((j['className']) ?? '').toString()),
        date: j['date'] ?? '',
        createdBy: j['createdBy'] ?? '',
      );
}

class EducationalPlanService {
  static const String _key = 'educational_plans_v1';
  static List<EducationalPlan>? _cache;

  static Future<List<EducationalPlan>> _srvAll() async {
    final rows = await Backend.client
        .from('educational_plans')
        .select('id, title, description, created_at, classes(name), profiles(full_name)')
        .order('created_at', ascending: false)
        .limit(300);
    return [
      for (final r in rows)
        EducationalPlan(
          id: r['id'] as String,
          title: (r['title'] ?? '') as String,
          description: (r['description'] ?? '') as String,
          className: normalizeClassName(r['classes'] is Map ? ((r['classes']['name'] ?? '') as String) : ''),
          date: JalaliDate.fromDateTime(DateTime.parse(r['created_at'] as String).toLocal()).formatted,
          createdBy: r['profiles'] is Map ? ((r['profiles']['full_name'] ?? '') as String) : '',
        ),
    ];
  }

  static Future<List<EducationalPlan>> getAll() async {
    if (Backend.ready) return _srvAll();
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return _cache = [];
    try {
      final list = jsonDecode(raw) as List;
      return _cache = list.map((e) => EducationalPlan.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return _cache = [];
    }
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_cache!.map((e) => e.toJson()).toList()));
  }

  static Future<void> add(EducationalPlan plan) async {
    if (Backend.ready) {
      await ServerDirectory.ensureLoaded();
      final cid = ServerDirectory.classId(plan.className);
      if (cid == null) throw Exception('کلاس «${plan.className}» در سرور پیدا نشد');
      await Backend.client.from('educational_plans').insert({
        'title': plan.title,
        'description': plan.description,
        'class_id': cid,
      });
      return; // گزارش تغییرات را تریگر دیتابیس می‌نویسد
    }
    final all = await getAll();
    all.insert(0, plan);
    await _save();
    await AuditLogService.log(
      actor: Session.userName,
      role: Session.role.label,
      action: 'ثبت برنامهٔ آموزشی',
      details: '${plan.className} • ${plan.title}',
    );
  }

  static Future<void> remove(String id) async {
    if (Backend.ready) {
      await Backend.client.from('educational_plans').delete().eq('id', id);
      return;
    }
    final all = await getAll();
    final i = all.indexWhere((p) => p.id == id);
    if (i < 0) return;
    final p = all.removeAt(i);
    await _save();
    await AuditLogService.log(
      actor: Session.userName,
      role: Session.role.label,
      action: 'حذف برنامهٔ آموزشی',
      details: '${p.className} • ${p.title}',
    );
  }
}
