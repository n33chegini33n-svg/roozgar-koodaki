import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'safe_image.dart';

/// کارت شیشه‌ای که کاراکتر از بالای آن بیرون زده و روی صفحه برجسته دیده می‌شود.
/// کاراکتر در کادر محبوس نیست؛ زیر پایش یک سایهٔ نرم است تا ملموس‌تر شود.
class PopOutCard extends StatelessWidget {
  final String title;
  final String image;
  final VoidCallback onTap;
  final Color tint;

  const PopOutCard({
    super.key,
    required this.title,
    required this.image,
    required this.onTap,
    this.tint = const Color(0xFF1473C9),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
            children: [
              // بدنهٔ شیشه‌ای
              Positioned(
                left: 0,
                right: 0,
                top: h * 0.26,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(color: tint.withValues(alpha: 0.30), blurRadius: 18, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.82),
                              Color.lerp(Colors.white, tint, 0.18)!.withValues(alpha: 0.70),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.95), width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // عنوان (درشت برای موبایل)
              Positioned(
                left: 8,
                right: 8,
                bottom: 10,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy, height: 1.3),
                ),
              ),
              // سایهٔ زیر پای کاراکتر
              Positioned(
                left: w * 0.22,
                right: w * 0.22,
                top: h * 0.64,
                height: 12,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 10)],
                  ),
                ),
              ),
              // کاراکتر برجسته
              Positioned(
                left: 6,
                right: 6,
                top: 0,
                height: h * 0.68,
                child: SafeAssetImage(image, fit: BoxFit.contain, alignment: Alignment.bottomCenter),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// شبکهٔ ریسپانسیو: روی گوشی دو ستون درشت، روی تبلت و وب سه یا چهار ستون.
class PopOutGrid extends StatelessWidget {
  final List<Widget> children;
  const PopOutGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final cols = w >= 1000 ? 4 : (w >= 700 ? 3 : 2);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: w < 420 ? 0.80 : 0.92,
          children: children,
        );
      },
    );
  }
}
