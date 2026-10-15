import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'audit_log_model.dart';
import 'permissions.dart';

/// تنظیمات مجموعه و اشتراک. تا زمان وجود سرور، فقط روی همین دستگاه ذخیره می‌شود.
class AppSettings {
  final String schoolName;
  final String phone;
  final String address;
  final String academicYear;
  final String planName;
  final String expiry; // مثلاً 1406/01/01
  final int studentLimit;

  const AppSettings({
    this.schoolName = 'مهد و دبستان روزگار کودکی',
    this.phone = '',
    this.address = '',
    this.academicYear = '',
    this.planName = 'آزمایشی',
    this.expiry = '',
    this.studentLimit = 200,
  });

  Map<String, dynamic> toJson() => {
        'schoolName': schoolName,
        'phone': phone,
        'address': address,
        'academicYear': academicYear,
        'planName': planName,
        'expiry': expiry,
        'studentLimit': studentLimit,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        schoolName: j['schoolName'] ?? 'مهد و دبستان روزگار کودکی',
        phone: j['phone'] ?? '',
        address: j['address'] ?? '',
        academicYear: j['academicYear'] ?? '',
        planName: j['planName'] ?? 'آزمایشی',
        expiry: j['expiry'] ?? '',
        studentLimit: j['studentLimit'] ?? 200,
      );
}

class AppSettingsService {
  static const String _key = 'app_settings_v1';
  static AppSettings? _cache;

  static Future<AppSettings> get() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        return _cache = AppSettings.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {}
    }
    return _cache = const AppSettings();
  }

  static Future<void> save(AppSettings s) async {
    // فقط ادمین سیستم اجازهٔ تغییر دارد (بررسی داخل خود عملیات)
    if (!PermissionService.instance.can(Session.role, Perm.manageAppSettings)) return;
    _cache = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(s.toJson()));
    await AuditLogService.log(
      actor: Session.userName,
      role: Session.role.label,
      action: 'تغییر تنظیمات برنامه و اشتراک',
      details: 'طرح: ${s.planName} • انقضا: ${s.expiry.isEmpty ? 'نامشخص' : s.expiry} • سقف نوآموز: ${s.studentLimit}',
    );
  }
}
