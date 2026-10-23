import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// تنظیمات ظاهر (برای تغییر سریع)
const int kStationeryCount = 41; // تعداد اشکال همزمان (از ۵۲ تصویر)
const double kStationeryMinSize = 79;
const double kStationeryMaxSize = 80;
const double kStationerySpeedMin = 3; // دیپی بر ثانیه
const double kStationerySpeedMax = 20;
const double kStationeryOpacity = 0.9;

class _Item {
  final String asset;
  final double base; // اندازهٔ پایه
  final double phase, pulseSpeed, spin, rot0;
  double x, y, vx, vy;
  _Item(this.asset, this.base, this.phase, this.pulseSpeed, this.spin, this.rot0, this.x, this.y, this.vx, this.vy);
  double scaleAt(double t) => 1 + 0.18 * math.sin(t * pulseSpeed + phase);
  double radiusAt(double t) => base * scaleAt(t) / 2;
}

/// اشکال لوازم‌التحریر معلق، فقط داخل ناحیهٔ آبی بالا.
/// [areaHeight]: ارتفاع ناحیهٔ آبی قابل‌دیدن (بالای کارت سفید)
/// ناحیهٔ ممنوعهٔ خورشید لوگو: مستطیل وسط ناحیه (قابل تنظیم در _sunRect)
class FloatingStationery extends StatefulWidget {
  final ValueNotifier<double> areaHeight;
  const FloatingStationery({super.key, required this.areaHeight});

  @override
  State<FloatingStationery> createState() => _FloatingStationeryState();
}



class _FloatingStationeryState extends State<FloatingStationery> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  final math.Random _rnd = math.Random();
  final List<_Item> _items = [];
  List<String> _pool = []; // همهٔ فایل‌های پوشهٔ stationery (خودکار)
  Duration _last = Duration.zero;
  double _t = 0;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    AssetManifest.loadFromAssetBundle(rootBundle).then((m) {
      final l = m.listAssets().where((a) => a.startsWith('assets/images/stationery/') && a.toLowerCase().endsWith('.png')).toList();
      if (mounted) _pool = l;
    });
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  /// ناحیهٔ خورشید: وسط افقی، از حدود نیمهٔ ارتفاع به پایین
  Rect _sunRect(double w, double h) {
    final half = math.max(w * 0.2, h * 0.4);
    return Rect.fromLTRB(w / 2 - half, h * 0.42, w / 2 + half, h + 200);
  }

  void _init(double w, double h) {
    if (_pool.isEmpty) return;
    final ids = List<String>.from(_pool)..shuffle(_rnd);
    _items.clear();
    final sun = _sunRect(w, h);
    for (final id in ids.take(kStationeryCount)) {
      final base = kStationeryMinSize + _rnd.nextDouble() * (kStationeryMaxSize - kStationeryMinSize);
      final r = base * 0.6;
      double x = 0, y = 0;
      for (var k = 0; k < 40; k++) {
        x = r + _rnd.nextDouble() * math.max(1, w - 2 * r);
        y = r + _rnd.nextDouble() * math.max(1, h - 2 * r);
        if (!sun.inflate(r).contains(Offset(x, y))) break;
      }
      final sp = kStationerySpeedMin + _rnd.nextDouble() * (kStationerySpeedMax - kStationerySpeedMin);
      final a = _rnd.nextDouble() * math.pi * 2;
      _items.add(_Item(
        id,
        base,
        _rnd.nextDouble() * 6.28,
        0.4 + _rnd.nextDouble() * 0.5,
        (_rnd.nextDouble() - 0.5) * 0.35,
        (_rnd.nextDouble() - 0.5) * 0.6,
        x, y, math.cos(a) * sp, math.sin(a) * sp,
      ));
    }
  }

  void _tick(Duration now) {
    final w = _size.width;
    final h = widget.areaHeight.value;
    if (w <= 0 || h <= 0) return;
    if (_items.isEmpty) _init(w, h);
    var dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0 || dt > 0.1) dt = 0.016;
    _t += dt;
    final sun = _sunRect(w, h);
    for (final it in _items) {
      it.x += it.vx * dt;
      it.y += it.vy * dt;
    }
    // برخورد اشکال با هم (کشسان؛ جرم برابر) تا از روی هم رد نشوند
    for (var i = 0; i < _items.length; i++) {
      for (var j = i + 1; j < _items.length; j++) {
        final a = _items[i], b = _items[j];
        final dx = a.x - b.x, dy = a.y - b.y;
        final minD = a.radiusAt(_t) + b.radiusAt(_t);
        final d2 = dx * dx + dy * dy;
        if (d2 >= minD * minD || d2 == 0) continue;
        final d = math.sqrt(d2);
        final nx = dx / d, ny = dy / d;
        final push = (minD - d) / 2;
        a.x += nx * push; a.y += ny * push;
        b.x -= nx * push; b.y -= ny * push;
        final rvn = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny;
        if (rvn < 0) {
          a.vx -= rvn * nx; a.vy -= rvn * ny;
          b.vx += rvn * nx; b.vy += rvn * ny;
        }
      }
    }
    for (final it in _items) {
      final r = it.base * 1.18 * 0.5; // بیشترین شعاع
      // برخورد با لبه‌های ناحیهٔ آبی
      if (it.x < r) { it.x = r; it.vx = it.vx.abs(); }
      if (it.x > w - r) { it.x = w - r; it.vx = -it.vx.abs(); }
      if (it.y < r) { it.y = r; it.vy = it.vy.abs(); }
      if (it.y > h - r) { it.y = h - r; it.vy = -it.vy.abs(); }
      // برخورد با خورشید (مستطیل ممنوعه)
      final z = sun.inflate(r);
      if (z.contains(Offset(it.x, it.y))) {
        final dl = it.x - z.left, dr = z.right - it.x, dtp = it.y - z.top;
        final m = math.min(dl, math.min(dr, dtp));
        if (m == dtp) { it.y = z.top; it.vy = -it.vy.abs(); }
        else if (m == dl) { it.x = z.left; it.vx = -it.vx.abs(); }
        else { it.x = z.right; it.vx = it.vx.abs(); }
      }
    }
    _frame.value++;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, box) {
        if (box.maxWidth != _size.width) {
          _size = Size(box.maxWidth, box.maxHeight);
          _items.clear();
        }
        return ValueListenableBuilder<double>(
          valueListenable: widget.areaHeight,
          builder: (context, h, _) => ClipRect(
            child: SizedBox(
              width: box.maxWidth,
              height: h,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _frame,
                  builder: (context, _) => Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      for (final it in _items)
                        Positioned(
                          left: it.x - it.base / 2,
                          top: it.y - it.base / 2,
                          width: it.base,
                          height: it.base,
                          child: Opacity(
                            opacity: kStationeryOpacity,
                            child: Transform.rotate(
                              angle: it.rot0 + it.spin * _t,
                              child: Transform.scale(
                                scale: it.scaleAt(_t),
                                child: Image.asset(it.asset, fit: BoxFit.contain, cacheWidth: 160, filterQuality: FilterQuality.medium),
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
        );
      }),
    );
  }
}
