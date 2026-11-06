import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'safe_image.dart';
import 'world3d_background.dart';

/// کاراکتر آزاد و بدون کادر؛ فقط سایهٔ نرم زیر پایش و عنوان با حاشیهٔ سفید.
class PopOutCard extends StatelessWidget {
  final String title;
  final String image;
  final VoidCallback onTap;
  final Color tint;
  final String? badge;

  const PopOutCard({
    super.key,
    required this.title,
    required this.image,
    required this.onTap,
    this.tint = const Color(0xFF1473C9),
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final card = LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        const style = TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.25);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
            children: [
              if (badge != null && badge!.isNotEmpty)
                Positioned(
                  top: 4,
                  left: 4,
                  right: 4,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC62828),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badge!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              // سایهٔ نرم زیر پا
              Positioned(
                left: w * 0.14,
                right: w * 0.14,
                top: h * 0.66,
                height: h * 0.12,
                child: CustomPaint(painter: _GroundShadow(Color.lerp(Colors.black, tint, 0.3)!)),
              ),
              // کاراکتر
              Positioned(
                left: 2,
                right: 2,
                top: 0,
                height: h * 0.74,
                child: SafeAssetImage(image, fit: BoxFit.contain, alignment: Alignment.bottomCenter),
              ),
              // عنوان بدون کادر
              Positioned(
                left: 4,
                right: 4,
                bottom: 2,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: style.copyWith(
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 5
                          ..strokeJoin = StrokeJoin.round
                          ..color = Colors.white,
                      ),
                    ),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: style.copyWith(color: AppColors.navy),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    return kWorld3D ? Tilt3D(child: card) : card;
  }
}

class _GroundShadow extends CustomPainter {
  final Color color;
  const _GroundShadow(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      Offset.zero & size,
      Paint()
        ..color = color.withValues(alpha: 0.34)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
  }

  @override
  bool shouldRepaint(covariant _GroundShadow old) => old.color != color;
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
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: w < 420 ? 0.82 : 0.95,
          children: children,
        );
      },
    );
  }
}
