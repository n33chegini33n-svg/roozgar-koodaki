import 'dart:async';
import 'package:flutter/material.dart';
import '../models/permissions.dart';
import 'safe_image.dart';
import '../utils/jalali.dart';

/// بنر ساعت زنده: روز هفته، تاریخ شمسی و ساعت (هر ثانیه به‌روز می‌شود)
class LiveClockBanner extends StatefulWidget {
  final Color accent;
  final EdgeInsetsGeometry margin;
  final String? roleLabel; // اگر خالی باشد، نقش کاربر واردشده نشان داده می‌شود

  const LiveClockBanner({
    super.key,
    this.roleLabel,
    this.accent = const Color(0xFF1473C9),
    this.margin = const EdgeInsets.only(bottom: 14),
  });

  @override
  State<LiveClockBanner> createState() => _LiveClockBannerState();
}

class _LiveClockBannerState extends State<LiveClockBanner> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _greeting(int h) {
    if (h < 5) return 'شب بخیر';
    if (h < 12) return 'صبح بخیر';
    if (h < 17) return 'روز بخیر';
    if (h < 20) return 'عصر بخیر';
    return 'شب بخیر';
  }

  IconData _icon(int h) {
    if (h >= 5 && h < 17) return Icons.wb_sunny_rounded;
    if (h >= 17 && h < 20) return Icons.wb_twilight_rounded;
    return Icons.nights_stay_rounded;
  }

  // ساعت با ارقام انگلیسی؛ تاریخ فارسی می‌ماند
  /// عکس کوچک نقش کاربر (فقط روی عرض‌های کافی نمایش داده می‌شود)
  Widget _avatar() {
    final label = widget.roleLabel;
    if (label == 'دانش‌آموز') return ChildAvatar(name: Session.childName, size: 46);
    String file;
    switch (Session.role) {
      case AppRole.parent:
        file = '08_woman_hijab_pink_coat.png';
        break;
      case AppRole.teacher:
        file = '20_teacher_woman_bun_green.png';
        break;
      case AppRole.deputy:
        file = '11_teacher_woman_curly_pointer.png';
        break;
      case AppRole.manager:
        file = '15_teacher_man_beard.png';
        break;
      case AppRole.admin:
        file = 'ill_admin.png';
        break;
    }
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: widget.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: ClipOval(
        child: SafeAssetImage(file, fit: BoxFit.cover, alignment: Alignment.topCenter, width: 46, height: 46),
      ),
    );
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final j = JalaliDate.fromDateTime(_now);
    final c = widget.accent;
    return Container(
      margin: widget.margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.withValues(alpha: 0.18)),
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          // ساعت
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c, Color.lerp(c, const Color(0xFF0B2B4A), 0.45)!],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_two(_now.hour)}:${_two(_now.minute)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _two(_now.second),
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 14,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          if (MediaQuery.of(context).size.width >= 390) ...[
            _avatar(),
            const SizedBox(width: 12),
          ],
          // روز و تاریخ
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_icon(_now.hour), size: 16, color: c),
                    const SizedBox(width: 4),
                    Text(_greeting(_now.hour), style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Text(widget.roleLabel ?? Session.role.label, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(j.weekdayName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF244E76))),
                Text(
                  '${faDigits(j.day)} ${j.monthName} ${faDigits(j.year)}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7C93)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
