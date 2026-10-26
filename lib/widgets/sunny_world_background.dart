import 'dart:math' as math;
import 'package:flutter/material.dart';

/// پس‌زمینهٔ «دنیای آفتابی»: آسمان آبی، خورشید درخشان، ابرهای آرام و تپه‌های سبز.
/// همهٔ صفحه‌ها می‌توانند محتوای خود را داخل [child] بگذارند.
class SunnyWorldBackground extends StatefulWidget {
  final Widget child;
  const SunnyWorldBackground({super.key, required this.child});

  @override
  State<SunnyWorldBackground> createState() => _SunnyWorldBackgroundState();
}

class _SunnyWorldBackgroundState extends State<SunnyWorldBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 120))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(painter: _SkyPainter(_c.value)),
            ),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _SkyPainter extends CustomPainter {
  final double t;
  const _SkyPainter(this.t);

  static const List<List<double>> _clouds = [
    // x، y، اندازه، سرعت
    [0.10, 0.10, 1.2, 1.0],
    [0.50, 0.20, 0.9, 1.6],
    [0.80, 0.07, 1.0, 1.3],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // آسمان
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3FB6F5), Color(0xFF8ED8FF), Color(0xFFDDF4FF)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // خورشید و هالهٔ نور
    final sun = Offset(w * 0.82, h * 0.12);
    final r = (math.min(w, h) * 0.08).clamp(28.0, 70.0);
    canvas.drawCircle(
      sun,
      r * 3.4,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xAAFFF3B0), Color(0x00FFF3B0)],
        ).createShader(Rect.fromCircle(center: sun, radius: r * 3.4)),
    );
    canvas.drawCircle(sun, r, Paint()..color = const Color(0xFFFFD54F));
    canvas.drawCircle(sun, r * 0.72, Paint()..color = const Color(0xFFFFE98A));

    // ابرها (آهسته حرکت می‌کنند)
    for (final c in _clouds) {
      final x = (((c[0] + t * c[3]) % 1.3) - 0.15) * w;
      _cloud(canvas, Offset(x, h * c[1]), c[2] * (w < 500 ? 0.9 : 1.3));
    }

    // تپه‌های پشتی و جلویی
    final back = Path()
      ..moveTo(0, h * 0.80)
      ..quadraticBezierTo(w * 0.25, h * 0.70, w * 0.55, h * 0.80)
      ..quadraticBezierTo(w * 0.80, h * 0.88, w, h * 0.78)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0xFF8BD66A));

    final front = Path()
      ..moveTo(0, h * 0.90)
      ..quadraticBezierTo(w * 0.30, h * 0.82, w * 0.60, h * 0.90)
      ..quadraticBezierTo(w * 0.85, h * 0.96, w, h * 0.88)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(front, Paint()..color = const Color(0xFF5CBF4A));
  }

  void _cloud(Canvas canvas, Offset o, double s) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.92);
    canvas.drawCircle(o, 14 * s, p);
    canvas.drawCircle(o + Offset(18 * s, -8 * s), 18 * s, p);
    canvas.drawCircle(o + Offset(40 * s, 0), 14 * s, p);
    canvas.drawRRect(
      RRect.fromLTRBR(o.dx - 14 * s, o.dy - 2 * s, o.dx + 54 * s, o.dy + 14 * s, Radius.circular(14 * s)),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.t != t;
}
