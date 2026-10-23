import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'audit_log_model.dart';
import 'permissions.dart';
import 'school_classes.dart';
import 'user_directory.dart';
import '../services/backend.dart';
import '../services/backend_directory.dart';

const List<String> kMenuDays = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه'];
const List<String> kMeals = ['صبحانه', 'میان‌وعده', 'ناهار'];
const List<String> kSeverities = ['خفیف', 'متوسط', 'شدید'];

/// حساسیت یا محدودیت غذایی یک نوآموز (اطلاعات سلامت: فقط برای افراد مجاز)
class AllergyRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String className;
  final String allergen;
  final String severity;
  final String notes;

  const AllergyRecord({
    required this.id,
    this.studentId = '',
    required this.studentName,
    required this.className,
    required this.allergen,
    required this.severity,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentId': studentId,
        'studentName': studentName,
        'className': className,
        'allergen': allergen,
        'severity': severity,
        'notes': notes,
      };

  factory AllergyRecord.fromJson(Map<String, dynamic> j) => AllergyRecord(
        id: j['id'] ?? '',
        studentId: j['studentId'] ?? '',
        studentName: j['studentName'] ?? '',
        className: normalizeClassName(((j['className']) ?? '').toString()),
        allergen: j['allergen'] ?? '',
        severity: j['severity'] ?? 'متوسط',
        notes: j['notes'] ?? '',
      );
}

class StudentInfo {
  final String id;
  final String name;
  final String className;
  const StudentInfo(this.id, this.name, this.className);
}

/// فهرست نوآموزان؛ منبع واحد: UserDirectory
class StudentDirectory {
  /// تعداد کاربران یک نقش
  static Future<int?> countByRole(String role) async {
    final list = await UserDirectory.load();
    return list.where((u) => u.role == role).length;
  }

  static Future<List<StudentInfo>> load() async {
    if (Backend.ready) {
      await ServerDirectory.ensureLoaded();
      return [
        for (final student in ServerDirectory.students)
          StudentInfo(student.id, student.name, student.className),
      ];
    }
    final list = await UserDirectory.load();
    return [
      for (final u in list)
        if (u.role == 'student') StudentInfo(u.id, u.name, u.className),
    ];
  }
}

class NutritionService {
  static const String _menuKey = 'weekly_menu_v1';
  static const String _allergyKey = 'allergies_v1';
  static Map<String, Map<String, String>>? _menu;
  static List<AllergyRecord>? _allergies;

  static Map<String, Map<String, String>> _emptyMenu() => {
        for (final d in kMenuDays) d: {for (final m in kMeals) m: ''},
      };

  static Future<Map<String, Map<String, String>>> _srvMenu() async {
    final menu = _emptyMenu();
    final rows = await Backend.client.from('menu_items').select('day, meal, content');
    for (final r in rows) {
      final d = r['day'];
      final m = r['meal'];
      if (menu[d] != null && kMeals.contains(m)) menu[d]![m as String] = (r['content'] ?? '') as String;
    }
    return menu;
  }

  static Future<List<AllergyRecord>> _srvAllergies({Set<String>? studentIds}) async {
    var query = Backend.client
        .from('allergies')
        .select('id, student_id, allergen, severity, notes, students(full_name, classes(name))');
    if (studentIds != null) {
      if (studentIds.isEmpty) return [];
      query = query.inFilter('student_id', studentIds.toList());
    }
    final rows = await query.order('created_at', ascending: false);
    return [
      for (final r in rows)
        AllergyRecord(
          id: r['id'] as String,
          studentId: '${r['student_id'] ?? ''}',
          studentName: r['students'] is Map ? ((r['students']['full_name'] ?? '') as String) : '',
          className: normalizeClassName(
            r['students'] is Map && r['students']['classes'] is Map ? ((r['students']['classes']['name'] ?? '') as String) : '',
          ),
          allergen: (r['allergen'] ?? '') as String,
          severity: (r['severity'] ?? 'متوسط') as String,
          notes: (r['notes'] ?? '') as String,
        ),
    ];
  }

  static Future<Map<String, Map<String, String>>> getMenu() async {
    if (Backend.ready) return _srvMenu();
    if (_menu != null) return _menu!;
    final menu = _emptyMenu();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_menuKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final d in kMenuDays) {
          final inner = map[d];
          if (inner is Map) {
            for (final m in kMeals) {
              menu[d]![m] = '${inner[m] ?? ''}';
            }
          }
        }
      } catch (_) {}
    }
    return _menu = menu;
  }

  /// ذخیرهٔ کل منو با یک نوشتن
  static Future<void> saveMenu(Map<String, Map<String, String>> menu) async {
    if (Backend.ready) {
      await Backend.client.from('menu_items').upsert([
        for (final d in kMenuDays)
          for (final m in kMeals) {'day': d, 'meal': m, 'content': menu[d]?[m] ?? ''},
      ], onConflict: 'day,meal');
      await AuditLogService.log(
        actor: Session.userName,
        role: Session.role.label,
        action: 'ویرایش منوی غذایی',
        details: 'منوی هفتگی به‌روزرسانی شد',
      );
      return;
    }
    _menu = menu;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_menuKey, jsonEncode(menu));
    await AuditLogService.log(
      actor: Session.userName,
      role: Session.role.label,
      action: 'ویرایش منوی غذایی',
      details: 'منوی هفتگی به‌روزرسانی شد',
    );
  }

  static Future<List<AllergyRecord>> getAllergies() async {
    final role = Session.role;
    final scope = PermissionService.instance.scopeOf(role, Perm.viewHealthRecords);
    if (scope == Scope.none) return [];

    if (Backend.ready) {
      if (role == AppRole.parent) {
        final linkedIds = Session.childStudentIds.toSet();
        if (linkedIds.isEmpty) return [];
        return _srvAllergies(studentIds: linkedIds);
      }
      final rows = await _srvAllergies();
      if (scope == Scope.all) return rows;
      return rows.where((a) => sameClass(a.className, Session.className)).toList();
    }

    final local = await _loadAllLocal();
    return _filterLocalAllergies(local, role, scope);
  }

  static Future<List<AllergyRecord>> _loadAllLocal() async {
    if (_allergies != null) return _allergies!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_allergyKey);
    if (raw == null || raw.isEmpty) return _allergies = [];
    try {
      final list = jsonDecode(raw) as List;
      _allergies = list.map((e) => AllergyRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      _allergies = [];
    }
    return _allergies!;
  }

  static List<AllergyRecord> _filterLocalAllergies(List<AllergyRecord> records, AppRole role, Scope scope) {
    if (scope == Scope.all) return records;
    if (role == AppRole.parent) {
      return records.where((a) => a.studentName == Session.childName).toList();
    }
    return records.where((a) => sameClass(a.className, Session.className)).toList();
  }

  static Future<void> _saveAllergies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_allergyKey, jsonEncode(_allergies!.map((e) => e.toJson()).toList()));
  }

  static Future<void> addAllergy(AllergyRecord r) async {
    if (!PermissionService.instance.can(Session.role, Perm.manageNutrition)) {
      throw Exception('اجازهٔ ثبت اطلاعات سلامت را ندارید');
    }
    if (Backend.ready) {
      final sid = r.studentId;
      if (sid.isEmpty) throw Exception('شناسهٔ نوآموز در سرور پیدا نشد');
      await Backend.client.from('allergies').insert({
        'student_id': sid,
        'allergen': r.allergen,
        'severity': r.severity,
        'notes': r.notes,
      });
      return; // ثبت در گزارش تغییرات را تریگر دیتابیس انجام می‌دهد
    }
    final all = await _loadAllLocal();
    all.insert(0, r);
    await _saveAllergies();
    await AuditLogService.log(
      actor: Session.userName,
      role: Session.role.label,
      action: 'ثبت حساسیت غذایی',
      details: '${r.studentName} • ${r.allergen} • شدت: ${r.severity}',
    );
  }

  static Future<void> removeAllergy(String id) async {
    if (!PermissionService.instance.can(Session.role, Perm.manageNutrition)) {
      throw Exception('اجازهٔ حذف اطلاعات سلامت را ندارید');
    }
    if (Backend.ready) {
      await Backend.client.from('allergies').delete().eq('id', id);
      return;
    }
    final all = await _loadAllLocal();
    final i = all.indexWhere((a) => a.id == id);
    if (i < 0) return;
    final r = all.removeAt(i);
    await _saveAllergies();
    await AuditLogService.log(
      actor: Session.userName,
      role: Session.role.label,
      action: 'حذف حساسیت غذایی',
      details: '${r.studentName} • ${r.allergen}',
    );
  }

  /// حساسیت‌هایی که این نقش مجاز به دیدنشان است
  /// parent: فقط فرزند خودش | teacher/deputy با دامنهٔ own: فقط کلاس خودش
  static Future<List<AllergyRecord>> visibleTo(AppRole role) async {
    if (role != Session.role) return [];
    return getAllergies();
  }
}
