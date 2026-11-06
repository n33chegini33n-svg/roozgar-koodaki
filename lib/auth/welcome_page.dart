import '../services/backend.dart';
import '../models/user_directory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../widgets/safe_image.dart';
import '../widgets/floating_stationery.dart';
import 'auth_types.dart';
import 'otp_page.dart';

/// تبدیل ارقام فارسی و عربی به انگلیسی
String normalizeDigits(String input) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  var out = input;
  for (var i = 0; i < 10; i++) {
    out = out.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
  }
  return out;
}

/// صفحهٔ خوش‌آمدگویی + وارد کردن شمارهٔ موبایل
class WelcomePage extends StatefulWidget {
  /// ورود: شمارهٔ همراه و کد را بررسی می‌کند و صفحهٔ اصلی نقش را برمی‌گرداند
  final AuthCallback authenticate;

  const WelcomePage({super.key, required this.authenticate});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final TextEditingController _phoneController = TextEditingController();
  String? _error;
  final GlobalKey _cardKey = GlobalKey();
  final ValueNotifier<double> _areaH = ValueNotifier<double>(0);

  @override
  void dispose() {
    _phoneController.dispose();
    _areaH.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = normalizeDigits(_phoneController.text.trim());
    final valid = RegExp(r'^09\d{9}$').hasMatch(phone);
    if (!valid) {
      setState(() => _error = 'شمارهٔ موبایل باید ۱۱ رقم باشد و با 09 شروع شود');
      return;
    }
    setState(() => _error = null);

    // بررسی سریع وجود شماره در سرور
    if (Backend.ready) {
      try {
        final res = await Backend.client.rpc('check_phone_exists', params: {'p_phone': phone});
        if (res == false) {
          if (mounted) {
            setState(() => _error = 'این شماره تلفن در سامانهٔ مدرسه ثبت نشده است');
          }
          return;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpPage(
          phone: phone,
          authenticate: widget.authenticate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final keyboard = media.viewInsets.bottom;

    // ارتفاع ناحیهٔ آبی = بالای کارت سفید (برای اشکال معلق)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rb = _cardKey.currentContext?.findRenderObject() as RenderBox?;
      if (rb == null || !rb.attached) return;
      final top = rb.localToGlobal(Offset.zero).dy;
      final v = (top - 4).clamp(0.0, size.height * 0.65);
      if ((v - _areaH.value).abs() > 0.5) _areaH.value = v;
    });

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.sky,
      body: Stack(
        children: [
          // لوگو و پس‌زمینه در بالای صفحه (با قابلیت تنظیم موقعیت کلی و فیت ماندن)
          Positioned(
            top: -15, // با تغییر این عدد می‌توانید کل مجموعه را بالا و پایین ببرید
            left: 0,
            right: 0,
            height: (size.height * 0.62) + 15,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ۱. تصویر زمینه (دایره‌های موجی و قاصدک‌ها) به صورت کاملاً فیت
                Positioned.fill(
                  child: const SafeAssetImage(
                    'logo_no_sun.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
                // ۲. خورشید خط‌مشکی با قابلیت تنظیم فاصله از پایین
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -10, // با تغییر این عدد می‌توانید خورشید را نسبت به خط سفید تنظیم کنید
                  child: Center(
                    child: Image.asset(
                      'assets/images/sun_outline.png',
                      width: size.width * 0.50,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // لوازم تحریر معلق (فقط در ناحیهٔ آبی)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FloatingStationery(areaHeight: _areaH),
          ),
          // کارت سفید پایین صفحه
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: keyboard),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: size.height - keyboard - media.padding.top,
                ),
                child: Container(
                  key: _cardKey,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 16,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'با هم می‌درخشیم',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 25),
                        const Text(
                          'شمارهٔ موبایلی که مدرسه برای شما ثبت کرده را وارد کنید',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          maxLength: 11,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9۰-۹٠-٩]'),
                            ),
                          ],
                          style: const TextStyle(fontSize: 30, letterSpacing: 2),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '09123456789',
                            errorText: _error,
                            prefixIcon: const Icon(
                              Icons.phone_android_rounded,
                              color: AppColors.navy,
                            ),
                            filled: true,
                            fillColor: AppColors.sky.withValues(alpha: 0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'ادامه',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}