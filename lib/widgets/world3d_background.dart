import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'sunny_world_background.dart';

/// کلید بازگشت: false = ظاهر قبلی (آسمان و تپه‌های تخت)، true = دنیای جدید با عکس آبرنگی.
const bool kWorld3D = true;

/// بر پایهٔ [kWorld3D] یکی از دو پس‌زمینه را نشان می‌دهد.
class WorldBackground extends StatelessWidget {
  final Widget child;
  const WorldBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      kWorld3D ? World3DBackground(child: child) : SunnyWorldBackground(child: child);
}

/// پس‌زمینهٔ آبرنگی با عمق: عکس با حرکت ماوس یا انگشت جابه‌جا می‌شود
/// و دانه‌های قاصدک در دو لایهٔ عمق شناورند.
class World3DBackground extends StatefulWidget {
  final Widget child;
  const World3DBackground({super.key, required this.child});

  @override
  State<World3DBackground> createState() => _World3DBackgroundState();
}

class _World3DBackgroundState extends State<World3DBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 90))..repeat();
  Offset _target = Offset.zero;
  Offset _cur = Offset.zero;

  @override
  void initState() {
    super.initState();
    _c.addListener(() => _cur = Offset.lerp(_cur, _target, 0.07)!);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _move(Offset p, Size s) {
    if (s.width <= 0 || s.height <= 0) return;
    _target = Offset((p.dx / s.width * 2 - 1).clamp(-1.0, 1.0), (p.dy / s.height * 2 - 1).clamp(-1.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerHover: (e) => _move(e.localPosition, size),
          onPointerMove: (e) => _move(e.localPosition, size),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => Transform.translate(
                    offset: Offset(-_cur.dx * 18, -_cur.dy * 10),
                    child: Transform.scale(
                      scale: 1.07,
                      child: Image.asset(
                        'assets/images/world_bg.jpg',
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (c, e, s) => const ColoredBox(color: Color(0xFFBFE6FA)),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _SeedsPainter(_c, () => _cur)),
                  ),
                ),
              ),
              Positioned.fill(child: widget.child),
            ],
          ),
        );
      },
    );
  }
}

/// دانه‌های قاصدک که آرام بالا می‌روند.
class _SeedsPainter extends CustomPainter {
  final Animation<double> anim;
  final Offset Function() tilt;
  _SeedsPainter(this.anim, this.tilt) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final t = anim.value;
    final tl = tilt();
    final rnd = math.Random(11);
    final s = (math.min(w, h) / 600).clamp(0.8, 1.5);
    for (var i = 0; i < 16; i++) {
      final depth = 0.4 + rnd.nextDouble() * 0.9;
      final x0 = rnd.nextDouble();
      final y0 = rnd.nextDouble();
      final k = 1 + (i % 3);
      final x = (((x0 + t * k * 0.6) % 1.0) * (w + 80)) - 40 + math.sin(t * math.pi * 2 * 6 + i) * 14 * s - tl.dx * 26 * depth;
      final y = (((y0 - t * k * 1.0) % 1.0 + 1.0) % 1.0) * (h + 80) - 40 - tl.dy * 14 * depth;
      _seed(canvas, Offset(x, y), s * depth, t * math.pi * 2 * 3 + i);
    }
  }

  void _seed(Canvas canvas, Offset c, double s, double rot) {
    final glow = Paint()
      ..color = const Color(0x66FFFFFF)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * s);
    canvas.drawCircle(c, 9 * s, glow);
    final line = Paint()
      ..color = const Color(0xDDFFFFFF)
      ..strokeWidth = 1.1 * s
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final a = rot * 0.2 + i * math.pi * 2 / 9;
      canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * 11 * s, line);
    }
    canvas.drawCircle(c, 2.2 * s, Paint()..color = const Color(0xFFFFC107));
  }

  @override
  bool shouldRepaint(covariant _SeedsPainter old) => true;
}

/// کج‌شدن سه‌بعدی کارت با حرکت ماوس. روی لمس، بدون اثر می‌ماند.
class Tilt3D extends StatefulWidget {
  final Widget child;
  const Tilt3D({super.key, required this.child});

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> {
  Offset _p = Offset.zero;
  bool _hover = false;

  void _onHover(PointerEvent e) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.isEmpty) return;
    setState(() {
      _hover = true;
      _p = Offset(
        (e.localPosition.dx / box.size.width * 2 - 1).clamp(-1.0, 1.0),
        (e.localPosition.dy / box.size.height * 2 - 1).clamp(-1.0, 1.0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: _onHover,
      onExit: (_) => setState(() {
        _hover = false;
        _p = Offset.zero;
      }),
      child: TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(end: _p),
        duration: const Duration(milliseconds: 140),
        builder: (context, p, child) {
          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateX(-p.dy * 0.2)
            ..rotateY(p.dx * 0.2);
          return Transform.translate(
            offset: Offset(0, _hover ? -6 : 0),
            child: Transform(alignment: Alignment.center, transform: m, child: child),
          );
        },
        child: widget.child,
      ),
    );
  }
}
