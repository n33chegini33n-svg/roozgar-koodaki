import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'school_classes.dart';
import '../services/backend.dart';
import '../services/backend_directory.dart';

/// کاربر سامانه. نقش‌ها: student، parent، teacher، deputy، manager، admin
class UserModel {
  final String id;
  final String name;
  final String role;
  final String className;
  final String phone;
  final String linkedStudent; // فقط برای ولی: نام فرزند

  const UserModel({
    required this.id,
    required this.name,
    required this.role,
    required this.className,
    required this.phone,
    this.linkedStudent = '',
  });

  UserModel copyWith({String? name, String? role, String? className, String? phone, String? linkedStudent}) => UserModel(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        className: className ?? this.className,
        phone: phone ?? this.phone,
        linkedStudent: linkedStudent ?? this.linkedStudent,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'className': className,
        'phone': phone,
        'linkedStudent': linkedStudent,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final role = (json['role'] ?? 'student').toString();
    final cls = (json['className'] ?? kClassNames.first).toString();
    var linked = (json['linkedStudent'] ?? '').toString();
    // داده‌های قدیمی: ولی با نام کلاس «والد فلانی»
    if (role == 'parent' && linked.isEmpty && cls.startsWith('والد ')) {
      linked = cls.substring(5).trim();
    }
    return UserModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      role: role,
      className: normalizeClassName(cls),
      phone: (json['phone'] ?? '').toString(),
      linkedStudent: linked,
    );
  }
}

/// تنها منبع فهرست کاربران (نوآموز، ولی، کادر) در حالت نمایشی.
/// همهٔ صفحه‌ها از اینجا می‌خوانند. با اتصال کامل به سرور، همین‌جا از دیتابیس خوانده می‌شود.
class UserDirectory {
  static const String _key = 'manager_users_list_v2';
  static List<UserModel>? _cache;

  static List<UserModel> _defaults() {
    const c1 = 'پیش‌دبستانی آفتاب';
    return [
      const UserModel(id: 'U1', name: 'مریم کریمی', role: 'student', className: c1, phone: '09121111101'),
      const UserModel(id: 'U2', name: 'سارا محمدی', role: 'student', className: c1, phone: '09121111102'),
      const UserModel(id: 'U3', name: 'علی احمدی', role: 'student', className: c1, phone: '09121111103'),
      const UserModel(id: 'U4', name: 'کارن رضایی', role: 'student', className: c1, phone: '09121111104'),
      const UserModel(id: 'U5', name: 'آرتین شجاعی', role: 'student', className: c1, phone: '09121111105'),
      const UserModel(id: 'U6', name: 'نیلا صادقی', role: 'student', className: c1, phone: '09121111106'),
      const UserModel(id: 'U7', name: 'هلیا موسوی', role: 'student', className: c1, phone: '09121111107'),
      const UserModel(id: 'U8', name: 'پارسا کاظمی', role: 'student', className: c1, phone: '09121111108'),
      const UserModel(id: 'U9', name: 'خانم رضایی', role: 'teacher', className: c1, phone: '09123333333'),
      const UserModel(id: 'U10', name: 'آقای محمدی', role: 'teacher', className: 'اول دبستان ستاره', phone: '09124444444'),
      const UserModel(
          id: 'U11', name: 'جناب آقای شجاعی', role: 'parent', className: 'والدین و اولیاء', phone: '09125555105', linkedStudent: 'آرتین شجاعی'),
    ];
  }

  static void clearCache() => _cache = null;

  /// حالت سرور: خواندن تمامی کاربران (دانش‌آموزان، اولیاء، کادر، مدیران) از جدول profiles دیتابیس
  static Future<List<UserModel>> _loadServer() async {
    if (_cache != null) return _cache!;
    await ServerDirectory.ensureLoaded();
    final list = <UserModel>[];

    // ۱. لیست نوآموزان ثبت‌شده در جدول students
    for (final s in ServerDirectory.students) {
      list.add(UserModel(id: s.id, name: s.name, role: 'student', className: s.className, phone: ''));
    }

    try {
      // ۲. لیست تمام کاربران ثبت‌شده در جدول profiles
      final profiles = await Backend.client.from('profiles').select('id, full_name, role, phone, grade, classes(name)');
      final existingStudentNames = list.map((u) => u.name).toSet();

      for (final p in profiles) {
        final role = (p['role'] ?? 'parent').toString();
        final name = (p['full_name'] ?? '').toString();
        final phone = (p['phone'] ?? '').toString();
        final c = p['classes'];
        final className = normalizeClassName(c is Map && c['name'] is String ? c['name'] as String : (p['grade'] ?? ''));

        // اگر کاربر دانش‌آموز است و قبلاً از جدول students اضافه نشده، اضافه می‌شود
        if (role == 'student') {
          if (!existingStudentNames.contains(name) && name.isNotEmpty) {
            list.add(UserModel(id: p['id'] as String, name: name, role: 'student', className: className, phone: phone));
          }
        } else {
          list.add(UserModel(id: p['id'] as String, name: name, role: role, className: className, phone: phone));
        }
      }
    } catch (_) {}
    return _cache = list;
  }

  static Future<List<UserModel>> load() async {
    if (Backend.ready) return _loadServer();
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    List<UserModel> list;
    if (raw == null) {
      list = _defaults();
    } else {
      try {
        list = [
          for (final e in jsonDecode(raw) as List) UserModel.fromJson(Map<String, dynamic>.from(e as Map)),
        ];
      } catch (_) {
        list = _defaults();
      }
      list = _merge(list);
    }
    _cache = list;
    await _persist();
    return list;
  }

  /// نسخه‌های قدیمی را کامل می‌کند: همهٔ نوآموزان نمونه باشند
  static List<UserModel> _merge(List<UserModel> loaded) {
    final result = List<UserModel>.from(loaded);
    final names = result.where((u) => u.role == 'student').map((u) => u.name).toSet();
    for (final d in _defaults()) {
      if (d.role == 'student' && !names.contains(d.name)) {
        result.add(UserModel(id: 'S-${d.name.hashCode}', name: d.name, role: d.role, className: d.className, phone: d.phone));
      }
    }
    return result;
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final u in _cache ?? <UserModel>[]) u.toJson()]));
  }

  static Future<void> save(List<UserModel> users) async {
    if (Backend.ready) return; // در حالت سرور، تغییر کاربران از داشبورد Supabase انجام می‌شود
    _cache = List<UserModel>.from(users);
    await _persist();
  }

  static Future<List<UserModel>> byRole(String role) async {
    final all = await load();
    return all.where((u) => u.role == role).toList();
  }

  static Future<List<UserModel>> studentsOfClass(String className) async {
    final all = await load();
    return all.where((u) => u.role == 'student' && sameClass(u.className, className)).toList();
  }

  static Future<UserModel?> studentByName(String name) async {
    final all = await load();
    for (final u in all) {
      if (u.role == 'student' && u.name == name) return u;
    }
    return null;
  }
}
