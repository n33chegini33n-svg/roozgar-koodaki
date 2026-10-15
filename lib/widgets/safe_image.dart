import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// شمارهٔ تصویر شخصیت هر نوآموز (فایل‌ها به شکل char_03.png هستند)
const Map<String, int> kStudentAvatarNumbers = {
  'مریم کریمی': 3,
  'سارا محمدی': 9,
  'علی احمدی': 2,
  'کارن رضایی': 13,
  'آرتین شجاعی': 7,
  'نیلا صادقی': 6,
  'هلیا موسوی': 12,
  'پارسا کاظمی': 18,
};

/// نام فایل شخصیت با صفر پیشرو: 3 ← char_03.png (مثل بقیهٔ فایل‌های پروژه)
String charAsset(int n) => 'char_${n.toString().padLeft(2, '0')}.png';

String _fullPath(String name) => name.startsWith('assets/') ? name : 'assets/images/$name';

/// تصویر از assets؛ اگر فایل پیدا نشد، به‌جای خطای قرمز یک جایگزین ساده نشان می‌دهد
class SafeAssetImage extends StatelessWidget {
  final String name;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final Widget? fallback;

  const SafeAssetImage(
    this.name, {
    super.key,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    Widget defaultFallback;
    if (name.contains('nutrition')) {
      defaultFallback = Container(
        width: width ?? double.infinity,
        height: height ?? 140,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu_rounded, size: 48, color: Color(0xFF2E9E6B)),
            SizedBox(height: 6),
            Text('منوی تغذیه و سلامت نوآموزان',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20), fontSize: 13)),
          ],
        ),
      );
    } else if (name.contains('announcement')) {
      defaultFallback = Container(
        width: width ?? double.infinity,
        height: height ?? 140,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFCE4EC), Color(0xFFF8BBD0)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_rounded, size: 48, color: Color(0xFFD81B60)),
            SizedBox(height: 6),
            Text('اطلاعیه‌ها و بخشنامه‌های مهم',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF880E4F), fontSize: 13)),
          ],
        ),
      );
    } else {
      defaultFallback = Container(
        width: width,
        height: height,
        color: AppColors.sky.withValues(alpha: 0.5),
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: AppColors.textGrey),
      );
    }

    return Image.asset(
      _fullPath(name),
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      errorBuilder: (context, error, stack) => fallback ?? defaultFallback,
    );
  }
}

/// آواتار دایره‌ای نوآموز. اگر عکسش نبود، حرف اول اسم روی رنگ ثابت نشان داده می‌شود.
class ChildAvatar extends StatelessWidget {
  final String name;
  final int? imageNumber;
  final double size;

  const ChildAvatar({super.key, required this.name, this.imageNumber, this.size = 42});

  static const List<Color> _palette = [
    Color(0xFFFFE0B2),
    Color(0xFFC8E6C9),
    Color(0xFFBBDEFB),
    Color(0xFFF8BBD0),
    Color(0xFFD1C4E9),
    Color(0xFFB2EBF2),
  ];

  @override
  Widget build(BuildContext context) {
    final n = imageNumber ?? kStudentAvatarNumbers[name];
    final bg = _palette[name.runes.fold<int>(0, (a, b) => a + b) % _palette.length];
    final initial = name.trim().isEmpty ? '؟' : String.fromCharCode(name.trim().runes.first);

    final fallback = Container(
      color: bg,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(fontSize: size * 0.45, fontWeight: FontWeight.bold, color: AppColors.navy),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Color(0xFFFFF3CD), shape: BoxShape.circle),
      child: ClipOval(
        child: n == null
            ? fallback
            : SafeAssetImage(
                charAsset(n),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                width: size,
                height: size,
                fallback: fallback,
              ),
      ),
    );
  }
}
