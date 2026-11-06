import '../services/backend.dart';

/// سطل بازیافت ثبت‌نام: پرونده‌های حذف‌شده تا ۷ روز قابل بازیابی‌اند
class RegistrationBin {
  static const int retentionDays = 7;

  /// پرونده‌هایی که بیش از ۷ روز در سطل مانده‌اند را برای همیشه حذف می‌کند
  /// (منطق در تابع سمت سرور purge_registration_bin است و فقط برای کادر مجاز اجرا می‌شود)
  static Future<void> purgeExpired() async {
    try {
      await Backend.client.rpc('purge_registration_bin');
    } catch (_) {
      // اگر سرور در دسترس نبود، دفعهٔ بعد دوباره تلاش می‌شود
    }
  }
}
