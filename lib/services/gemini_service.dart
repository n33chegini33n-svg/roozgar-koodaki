import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AiTurn {
  final bool fromUser;
  final String text;
  const AiTurn(this.fromUser, this.text);
}

/// اتصال به Gemini.
/// کلید به یکی از این دو روش داده می‌شود (در کد نوشته نمی‌شود):
/// ۱) آرگومان اجرا: --dart-define=GEMINI_API_KEY=کلید
/// ۲) داخل صفحهٔ دستیار هوشمند (دکمهٔ تنظیمات)؛ روی همین دستگاه ذخیره می‌شود.
class GeminiService {
  static const String _envKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _envModel = String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-2.5-flash');
  static const String _keyStore = 'gemini_api_key';
  static const String _modelStore = 'gemini_model';

  static const String _systemPrompt =
      'تو دستیار آموزشی یک مجموعهٔ مهدکودک، پیش‌دبستانی و دبستان هستی و با مربیان، معاونان و مدیران صحبت می‌کنی. '
      'همیشه فارسی و کوتاه و کاربردی جواب بده. ایده‌های کلاسی، توضیح ساده، برنامهٔ درسی و بازی آموزشی بده. '
      'محتوای نامناسب کودکان، توصیهٔ پزشکی یا حقوقی قطعی و اطلاعات شخصی کودکان را تولید نکن.';

  static Future<String> get apiKey async {
    if (_envKey.trim().isNotEmpty) return _envKey.trim();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStore)?.trim() ?? '';
  }

  static Future<String> get model async {
    final prefs = await SharedPreferences.getInstance();
    final m = prefs.getString(_modelStore)?.trim() ?? '';
    return m.isNotEmpty ? m : _envModel;
  }

  static Future<bool> get configured async => (await apiKey).isNotEmpty;

  static Future<void> saveSettings({String? key, String? model}) async {
    final prefs = await SharedPreferences.getInstance();
    if (key != null) {
      key.trim().isEmpty ? await prefs.remove(_keyStore) : await prefs.setString(_keyStore, key.trim());
    }
    if (model != null) {
      model.trim().isEmpty ? await prefs.remove(_modelStore) : await prefs.setString(_modelStore, model.trim());
    }
  }

  static String _friendly(int status, String body) {
    var msg = body;
    try {
      final j = jsonDecode(body);
      final m = j['error']?['message'];
      if (m is String && m.isNotEmpty) msg = m;
    } catch (_) {}
    final low = msg.toLowerCase();
    if (low.contains('location is not supported')) {
      return 'این سرویس از موقعیت فعلی شما پشتیبانی نمی‌شود (دسترسی از ایران محدود است).';
    }
    if (low.contains('api key not valid') || status == 401) return 'کلید معتبر نیست؛ در تنظیمات دوباره وارد کنید.';
    if (status == 404) return 'نام مدل درست نیست؛ در تنظیمات نام مدل را عوض کنید. ($msg)';
    if (status == 429) return 'سقف درخواست رایگان پر شده؛ کمی بعد دوباره امتحان کنید.';
    return 'خطای سرویس ($status): $msg';
  }

  /// گفتگوی چندمرحله‌ای؛ آخرین پیام باید از کاربر باشد.
  static Future<String> chat(List<AiTurn> history) async {
    final key = await apiKey;
    if (key.isEmpty) throw StateError('کلید تنظیم نشده است.');
    final m = await model;
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent');

    final http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'x-goog-api-key': key},
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {'text': _systemPrompt}
                ]
              },
              'contents': [
                for (final t in history.length > 12 ? history.sublist(history.length - 12) : history)
                  {
                    'role': t.fromUser ? 'user' : 'model',
                    'parts': [
                      {'text': t.text}
                    ]
                  },
              ],
              'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 1024},
            }),
          )
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw Exception('ارتباط برقرار نشد؛ اینترنت یا دسترسی به سرویس را بررسی کنید.');
    }

    if (res.statusCode != 200) throw Exception(_friendly(res.statusCode, res.body));

    final data = jsonDecode(res.body);
    final c = data['candidates'];
    if (c is List && c.isNotEmpty) {
      final parts = c.first['content']?['parts'];
      if (parts is List && parts.isNotEmpty) {
        final text = parts.map((p) => p['text'] ?? '').join();
        if (text.trim().isNotEmpty) return text.trim();
      }
    }
    throw Exception('پاسخی دریافت نشد (ممکن است محتوا مسدود شده باشد).');
  }

  static Future<String> generateText(String prompt) => chat([AiTurn(true, prompt)]);
}
