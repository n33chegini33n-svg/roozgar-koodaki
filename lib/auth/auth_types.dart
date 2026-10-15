import 'package:flutter/widgets.dart';

/// نتیجهٔ ورود: یا پیام خطا، یا صفحهٔ اصلی نقش کاربر
class AuthResult {
  final String? error;
  final Widget? home;
  const AuthResult.error(String message)
      : error = message,
        home = null;
  const AuthResult.ok(Widget page)
      : home = page,
        error = null;
}

/// phone: شمارهٔ همراه | code: کد ورود (در حالت سرور همان رمز حساب است)
/// demoRole: فقط در حالت نمایشی (بدون سرور) برای انتخاب نقش
typedef AuthCallback = Future<AuthResult> Function(String phone, String code, String? demoRole);
