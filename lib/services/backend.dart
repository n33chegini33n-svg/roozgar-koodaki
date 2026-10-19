import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sup;

import '../models/permissions.dart';
import '../models/school_classes.dart';
import '../models/attendance_archive_model.dart';
import '../models/user_directory.dart';
import 'backend_directory.dart';

/// اتصال به Supabase. اگر کلیدها داده نشده باشند، برنامه در «حالت نمایشی» (بدون سرور) اجرا می‌شود.
///
/// اجرا با کلیدها:
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class Backend {
  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool _ready = false;

  static bool get configured => _url.isNotEmpty && _anonKey.isNotEmpty;

  /// آدرس تمیز: فقط https://نام-پروژه.supabase.co (مسیرهای اضافه مثل /rest/v1 و فاصله‌ها حذف می‌شوند)
  static String get cleanUrl {
    var v = _url.trim().replaceAll('"', '').replaceAll("'", '');
    if (!v.startsWith('http://') && !v.startsWith('https://')) v = 'https://$v';
    final u = Uri.tryParse(v);
    if (u == null || u.host.isEmpty) return v;
    return '${u.scheme}://${u.host}';
  }

  /// true یعنی به سرور وصل هستیم و ورود واقعی فعال است
  static bool get ready => _ready;

  static sup.SupabaseClient get client => sup.Supabase.instance.client;

  static Future<void> init() async {
    if (!configured) return;
    try {
      await sup.Supabase.initialize(url: cleanUrl, publishableKey: _anonKey.trim());
      _ready = true;
    } catch (e) {
      debugPrint('Supabase init failed: $e');
    }
  }

  static String latinDigits(String input) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final ch in input.runes) {
      final c = String.fromCharCode(ch);
      final i = fa.indexOf(c);
      final j = ar.indexOf(c);
      b.write(i >= 0 ? '$i' : (j >= 0 ? '$j' : c));
    }
    return b.toString().trim();
  }

  /// شمارهٔ همراه به‌عنوان نام کاربری؛ در Supabase به‌صورت ایمیل مجازی ذخیره می‌شود
  static String emailFor(String input) {
    final v = latinDigits(input);
    // اگر ایمیل کامل وارد شده باشد همان استفاده می‌شود
    if (v.contains('@')) return v.toLowerCase();
    return '$v@roozgar.app';
  }

  /// null یعنی موفق؛ در غیر این صورت پیام خطا برای نمایش
  static Future<String?> signIn(String phone, String password) async {
    Session.reset();
    try {
      await client.auth.signInWithPassword(email: emailFor(phone), password: password);
      final error = await _loadSession();
      if (error != null) await _clearAuthState();
      return error;
    } on sup.AuthException catch (e) {
      await _clearAuthState();
      final m = e.message.toLowerCase();
      if (m.contains('invalid login')) {
        // در حالت توسعه، ایمیلی که برنامه امتحان کرده نشان داده می‌شود تا اشکال‌یابی ساده باشد
        return 'شمارهٔ همراه یا کد ورود اشتباه است${kDebugMode ? '\n(ایمیل ورود: ${emailFor(phone)})' : ''}';
      }
      if (m.contains('not confirmed')) {
        return 'حساب تأیید نشده است؛ در Supabase کاربر را Confirm کنید یا Confirm email را خاموش کنید';
      }
      if (m.contains('404')) {
        return 'آدرس سرور اشتباه است (${Uri.tryParse(cleanUrl)?.host}). SUPABASE_URL را از Supabase ← Project Settings ← API کپی کنید';
      }
      if (m.contains('invalid api key') || m.contains('401')) {
        return 'کلید SUPABASE_ANON_KEY اشتباه است (باید anon public باشد، نه service_role)';
      }
      return 'خطای ورود: ${e.message}';
    } catch (e) {
      await _clearAuthState();
      return 'ارتباط با سرور برقرار نشد: $e';
    }
  }

  /// نقش، نام، کلاس و فرزند را از دیتابیس می‌خواند (نقش هرگز از سمت کاربر تعیین نمی‌شود)
  static Future<String?> _loadSession() async {
    final user = client.auth.currentUser;
    if (user == null) return 'ورود ناموفق بود';

    final p = await client
        .from('profiles')
        .select('full_name, role, active, classes(name)')
        .eq('id', user.id)
        .maybeSingle();
    if (p == null) {
      await client.auth.signOut();
      return 'پروفایل این کاربر در جدول profiles ساخته نشده است (راهنمای README، مرحلهٔ «ساخت پروفایل»)';
    }
    if (p['active'] != true) {
      await client.auth.signOut();
      return 'حساب شما غیرفعال است؛ با مدیریت تماس بگیرید';
    }

    final roleName = p['role'];
    final matchingRoles = AppRole.values.where((r) => r.name == roleName);
    if (matchingRoles.isEmpty) {
      return 'نقش حساب معتبر نیست؛ از مدیریت بخواهید نقش حساب را اصلاح کند';
    }
    final role = matchingRoles.first;
    Session.signIn(role);
    final name = p['full_name'];
    if (name is String && name.isNotEmpty) Session.userName = name;
    final cls = p['classes'];
    if (cls is Map && cls['name'] is String) {
      Session.className = normalizeClassName(cls['name'] as String);
    }

    if (role == AppRole.parent) {
      final rows = await client
          .from('parent_students')
          .select('students(full_name, classes(name))')
          .eq('parent_id', user.id);
      if (rows.isNotEmpty) {
        final st = rows.first['students'];
        if (st is Map) {
          if (st['full_name'] is String) {
            Session.childName = st['full_name'] as String;
          }
          final c = st['classes'];
          if (c is Map && c['name'] is String) {
            Session.className = normalizeClassName(c['name'] as String);
          }
        }
      }
    }
    return null;
  }

  static Future<void> signOut() async {
    await _clearAuthState();
  }

  static Future<void> _clearAuthState() async {
    if (_ready) {
      try {
        await client.auth.signOut();
      } catch (_) {}
    }
    // پاک‌سازی همیشه انجام می‌شود؛ حتی اگر سرور در دسترس نباشد.
    Session.reset();
    ServerDirectory.reset();
    AttendanceArchiveService.clearCache();
    UserDirectory.clearCache();
  }
}
