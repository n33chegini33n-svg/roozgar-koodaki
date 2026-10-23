import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../widgets/safe_image.dart';
import '../services/backend.dart';
import '../services/demo_auth_policy.dart';
import 'auth_types.dart';
import 'welcome_page.dart' show normalizeDigits;

/// صفحهٔ کد ورود
///
/// حالت سرور: کد همان رمز حساب است که مدیریت مدرسه برای کاربر تعیین کرده (۶ رقم).
/// حالت نمایشی (بدون سرور): هر کد ۶ رقمی پذیرفته می‌شود و نقش از فهرست کاربران یا انتخاب زیر می‌آید.
/// بعداً با سرویس پیامک، همین‌جا کد یک‌بارمصرف جایگزین می‌شود.
class OtpPage extends StatefulWidget {
  final String phone;
  final AuthCallback authenticate;

  const OtpPage({
    super.key,
    required this.phone,
    required this.authenticate,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  static const int _codeLength = 6;
  final TextEditingController _codeController = TextEditingController();
  String? _error;
  bool _busy = false;
  String _demoRole = 'student';

  bool get _demoAllowed => DemoAuthPolicy.isAllowed(
        isDebugBuild: kDebugMode,
        backendConfigured: Backend.configured,
        backendReady: Backend.ready,
      );

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;
    final code = normalizeDigits(_codeController.text.trim());
    if (code.length != _codeLength) {
      setState(() => _error = 'کد ۶ رقمی را کامل وارد کنید');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.authenticate(
      widget.phone,
      code,
      _demoAllowed ? _demoRole : null,
    );
    if (!mounted) return;
    if (result.error != null || result.home == null) {
      setState(() {
        _busy = false;
        _error = result.error ?? 'ورود ناموفق بود';
      });
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => result.home!),
      (route) => false,
    );
  }

  static const String _logo = 'logo_no_text.jpg';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sky,
      body: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          final wide = w > 600; // وب/تبلت: محتوا وسط و پس‌زمینه تار
          final contentW = wide ? 520.0 : w;
          // لوگو حدود نیمی از صفحه؛ با بازشدن کیبورد کوچک می‌شود
          final imgH = math.min(math.max(h * 0.52, 150.0), contentW);

          return Stack(
            children: [
              if (wide)
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: const SafeAssetImage(_logo, fit: BoxFit.cover),
                  ),
                ),
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: contentW,
                  height: h,
                  child: Column(
                    children: [
                      // لوگوی تمام‌عرض؛ پای بچه‌ها لبهٔ پایین تصویر است
                      SizedBox(
                        height: imgH,
                        width: contentW,
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: SafeAssetImage(_logo, fit: BoxFit.cover, alignment: Alignment.bottomCenter),
                            ),
                            PositionedDirectional(
                              top: MediaQuery.of(context).padding.top + 8,
                              start: 12,
                              child: Material(
                                color: Colors.white.withValues(alpha: 0.85),
                                shape: const CircleBorder(),
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
                                  tooltip: 'بازگشت',
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // فرم درست زیر پای بچه‌ها
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 14, offset: Offset(0, -3))],
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                            child: _form(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _form() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'کد ورود را وارد کنید',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy),
        ),
        const SizedBox(height: 8),
        Text(
          Backend.ready
              ? 'شمارهٔ ${widget.phone} • کد ورود را مدیریت مدرسه به شما داده است'
              : (_demoAllowed
                  ? 'شمارهٔ ${widget.phone} • حالت نمایشی توسعه: هر کد ۶ رقمی پذیرفته می‌شود'
                  : 'شمارهٔ ${widget.phone} • ورود موقتاً در دسترس نیست؛ اتصال سرور را بررسی کنید'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textGrey),
        ),
        if (_demoAllowed) ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _demoRole,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'نقش (اگر شماره در فهرست کاربران نباشد)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'student', child: Text('دانش‌آموز / نوآموز 🎒')),
              DropdownMenuItem(value: 'parent', child: Text('اولیاء (والدین) 👨‍👩‍👧')),
              DropdownMenuItem(value: 'teacher', child: Text('مربی / معلم 👩‍🏫')),
              DropdownMenuItem(value: 'deputy', child: Text('معاون / ناظم 🧑‍💼')),
              DropdownMenuItem(value: 'manager', child: Text('مدیریت مهد و مدرسه 🏫')),
              DropdownMenuItem(value: 'admin', child: Text('ادمین سیستم 🛡️')),
            ],
            onChanged: (v) => setState(() => _demoRole = v ?? _demoRole),
          ),
        ],
        const SizedBox(height: 22),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLength: _codeLength,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]')),
          ],
          style: const TextStyle(fontSize: 26, letterSpacing: 10),
          decoration: InputDecoration(
            counterText: '',
            errorText: _error,
            filled: true,
            fillColor: AppColors.sky.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _busy ? null : _verify,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('ورود', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ویرایش شمارهٔ موبایل'),
        ),
      ],
    );
  }
}
