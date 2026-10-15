import '../models/school_classes.dart';
import 'backend.dart';

class ServerStudent {
  final String id;
  final String name;
  final String classId;
  final String className;
  const ServerStudent({required this.id, required this.name, required this.classId, required this.className});
}

/// فهرست کلاس‌ها و نوآموزان از سرور (آنچه RLS به کاربر فعلی اجازه می‌دهد).
/// برای تبدیل «نام» به «شناسه» هنگام ثبت در دیتابیس استفاده می‌شود.
class ServerDirectory {
  static bool _loaded = false;
  static final Map<String, String> _classIds = {}; // نام بدون ایموجی ← شناسه
  static final List<ServerStudent> _students = [];

  static List<ServerStudent> get students => List.unmodifiable(_students);

  /// کلاس‌ها (نام بدون ایموجی ← شناسه) برای انتخاب در فرم‌ها
  static List<MapEntry<String, String>> get classList => _classIds.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

  static Future<void> ensureLoaded({bool force = false}) async {
    if (_loaded && !force) return;
    final classes = await Backend.client.from('classes').select('id, name');
    _classIds.clear();
    for (final c in classes) {
      final name = c['name'];
      final id = c['id'];
      if (name is String && id is String) _classIds[normalizeClassName(name)] = id;
    }
    final rows = await Backend.client
        .from('students')
        .select('id, full_name, class_id, classes(name)')
        .order('full_name');
    _students.clear();
    for (final r in rows) {
      final cls = r['classes'];
      _students.add(
        ServerStudent(
          id: r['id'] as String,
          name: r['full_name'] as String,
          classId: (r['class_id'] ?? '') as String,
          className: normalizeClassName(cls is Map && cls['name'] is String ? cls['name'] as String : ''),
        ),
      );
    }
    _loaded = true;
  }

  static String? classId(String name) => _classIds[normalizeClassName(name)];

  static String? studentId(String name, String className) {
    for (final s in _students) {
      if (s.name == name && sameClass(s.className, className)) return s.id;
    }
    return null;
  }

  static void reset() {
    _loaded = false;
    _classIds.clear();
    _students.clear();
  }
}
