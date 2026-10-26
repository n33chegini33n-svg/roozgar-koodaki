import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/attendance_archive_model.dart';
import '../../models/evaluation_feedback_model.dart';
import '../../services/evaluation_service.dart';
import '../../services/financial_analytics_service.dart';

/// کارت خلاصهٔ مواردی که به پیگیری مدیریت نیاز دارند.
class ManagerPendingActionBanner extends StatelessWidget {
  final int pendingReceipts;
  final int pendingAttendanceEdits;
  final int pendingRegistrations;
  final VoidCallback onOpenReceipts;
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenRegistrations;

  const ManagerPendingActionBanner({
    super.key,
    required this.pendingReceipts,
    required this.pendingAttendanceEdits,
    required this.pendingRegistrations,
    required this.onOpenReceipts,
    required this.onOpenRequests,
    required this.onOpenRegistrations,
  });

  @override
  Widget build(BuildContext context) {
    final total = pendingReceipts + pendingAttendanceEdits + pendingRegistrations;
    const orange = Color(0xFFEF6C00);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFFF8E1), Color(0xFFFFF3E0), Colors.white],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: orange.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: orange.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: orange),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'موارد نیازمند پیگیری',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '$total مورد',
                  style: const TextStyle(color: orange, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PendingCountChip(
                icon: Icons.receipt_long_rounded,
                label: 'فیش منتظر تأیید',
                count: pendingReceipts,
                color: const Color(0xFF1565C0),
                onTap: onOpenReceipts,
              ),
              _PendingCountChip(
                icon: Icons.edit_note_rounded,
                label: 'اصلاح در انتظار',
                count: pendingAttendanceEdits,
                color: const Color(0xFF8E24AA),
                onTap: onOpenRequests,
              ),
              _PendingCountChip(
                icon: Icons.assignment_ind_rounded,
                label: 'پیش‌ثبت‌نام',
                count: pendingRegistrations,
                color: const Color(0xFF00897B),
                onTap: onOpenRegistrations,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingCountChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _PendingCountChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: color.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(width: 7),
              Text('$count', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

/// امتیازها باید در بازهٔ ۱ تا ۵ باشند؛ نوارها نسبت به امتیاز ۵ نمایش داده می‌شوند.
class _ParentSatisfactionCard extends StatelessWidget {
  final double educationScore;
  final double teachersScore;
  final double nutritionScore;
  final double environmentScore;

  const _ParentSatisfactionCard({
    required this.educationScore,
    required this.teachersScore,
    required this.nutritionScore,
    required this.environmentScore,
  });

  double _normalized(double score) => score.clamp(1, 5) / 5;

  @override
  Widget build(BuildContext context) {
    final average = (educationScore + teachersScore + nutritionScore + environmentScore) / 4;
    return _PerformanceCardShell(
      title: 'رضایت اولیا',
      subtitle: 'میانگین امتیاز کیفی',
      icon: Icons.favorite_rounded,
      accent: const Color(0xFFD81B60),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(average.toStringAsFixed(1), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
              const Padding(
                padding: EdgeInsets.only(bottom: 5, right: 4),
                child: Text('از ۵', style: TextStyle(color: Colors.black54, fontSize: 12)),
              ),
              const Spacer(),
              const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 27),
            ],
          ),
          const SizedBox(height: 12),
          _SatisfactionMetric(label: 'آموزش', score: educationScore, value: _normalized(educationScore), color: const Color(0xFF1565C0)),
          _SatisfactionMetric(label: 'مربیان', score: teachersScore, value: _normalized(teachersScore), color: const Color(0xFF00897B)),
          _SatisfactionMetric(label: 'تغذیه', score: nutritionScore, value: _normalized(nutritionScore), color: const Color(0xFFEF6C00)),
          _SatisfactionMetric(label: 'محیط', score: environmentScore, value: _normalized(environmentScore), color: const Color(0xFF8E24AA)),
        ],
      ),
    );
  }
}

class _SatisfactionMetric extends StatelessWidget {
  final String label;
  final double score;
  final double value;
  final Color color;

  const _SatisfactionMetric({
    required this.label,
    required this.score,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              Text(score.clamp(1, 5).toStringAsFixed(1), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.10),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// بخش شاخص‌های عملکرد مدیر.
/// نرخ حضور هفتگی اگر داده نشود، از AttendanceArchiveService خوانده می‌شود.
class SchoolPerformanceAnalyticsPage extends StatefulWidget {
  /// اگر خالی باشد، از آرشیو حضور و غیاب واقعی محاسبه می‌شود.
  final Map<String, double> weeklyAttendanceRates;

  const SchoolPerformanceAnalyticsPage({
    super.key,
    this.weeklyAttendanceRates = const {},
  });

  @override
  State<SchoolPerformanceAnalyticsPage> createState() => _SchoolPerformanceAnalyticsPageState();
}

class _SchoolPerformanceAnalyticsPageState extends State<SchoolPerformanceAnalyticsPage> {
  Map<String, double> _weeklyRates = const {};
  bool _loadingAttendance = true;
  FinancialAnalyticsData? _financialAnalytics;
  bool _loadingFinancialAnalytics = true;
  bool _financialAnalyticsFailed = false;
  EvaluationStats? _evaluationStats;
  bool _loadingEvaluationStats = true;
  bool _evaluationStatsFailed = false;

  @override
  void initState() {
    super.initState();
    _loadWeeklyAttendance();
    _loadFinancialAnalytics();
    _loadEvaluationStats();
  }

  Future<void> _loadEvaluationStats() async {
    try {
      final stats = await EvaluationService.loadEvaluationStats();
      if (!mounted) return;
      setState(() {
        _evaluationStats = stats;
        _loadingEvaluationStats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _evaluationStatsFailed = true;
        _loadingEvaluationStats = false;
      });
    }
  }

  void _retryEvaluationStats() {
    setState(() {
      _loadingEvaluationStats = true;
      _evaluationStatsFailed = false;
    });
    _loadEvaluationStats();
  }

  Future<void> _loadFinancialAnalytics() async {
    try {
      final analytics = await FinancialAnalyticsService.loadAnalytics();
      if (!mounted) return;
      setState(() {
        _financialAnalytics = analytics;
        _loadingFinancialAnalytics = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _financialAnalyticsFailed = true;
        _loadingFinancialAnalytics = false;
      });
    }
  }

  Future<void> _loadWeeklyAttendance() async {
    if (widget.weeklyAttendanceRates.isNotEmpty) {
      setState(() {
        _weeklyRates = widget.weeklyAttendanceRates;
        _loadingAttendance = false;
      });
      return;
    }
    try {
      final rates = await AttendanceArchiveService.weeklyAttendanceRates();
      if (!mounted) return;
      setState(() {
        _weeklyRates = rates;
        _loadingAttendance = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weeklyRates = const {};
        _loadingAttendance = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('مرکز آمار و شاخص‌های عملکرد مدرسه'),
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loadingEvaluationStats)
                      const _PerformanceCardShell(
                        title: 'رضایت اولیا',
                        subtitle: 'در حال خواندن ارزیابی‌ها...',
                        icon: Icons.favorite_rounded,
                        accent: Color(0xFFD81B60),
                        child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                      )
                    else if (_evaluationStatsFailed)
                      _PerformanceCardShell(
                        title: 'رضایت اولیا',
                        subtitle: 'بارگذاری ارزیابی‌ها انجام نشد',
                        icon: Icons.favorite_rounded,
                        accent: const Color(0xFFD81B60),
                        child: SizedBox(
                          height: 120,
                          child: Center(
                            child: TextButton.icon(
                              onPressed: _retryEvaluationStats,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('تلاش دوباره'),
                            ),
                          ),
                        ),
                      )
                    else if (_evaluationStats != null && _evaluationStats!.responseCount > 0)
                      _ParentSatisfactionCard(
                        educationScore: _evaluationStats!.schoolEducationScore!,
                        teachersScore: _evaluationStats!.schoolStaffScore!,
                        nutritionScore: _evaluationStats!.schoolNutritionScore!,
                        environmentScore: _evaluationStats!.schoolEnvironmentScore!,
                      )
                    else
                      const _PerformanceCardShell(
                        title: 'رضایت اولیا',
                        subtitle: 'هنوز پاسخی ثبت نشده است',
                        icon: Icons.favorite_rounded,
                        accent: Color(0xFFD81B60),
                        child: _EmptyChartMessage(),
                      ),
                    const SizedBox(height: 12),
                    if (_loadingEvaluationStats)
                      const _PerformanceCardShell(
                        title: 'ارزیابی اولیا از مربیان',
                        subtitle: 'در حال خواندن ارزیابی‌ها...',
                        icon: Icons.stars_rounded,
                        accent: Color(0xFFFFA000),
                        child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                      )
                    else if (_evaluationStatsFailed)
                      _PerformanceCardShell(
                        title: 'ارزیابی اولیا از مربیان',
                        subtitle: 'بارگذاری ارزیابی‌ها انجام نشد',
                        icon: Icons.stars_rounded,
                        accent: const Color(0xFFFFA000),
                        child: SizedBox(
                          height: 120,
                          child: Center(
                            child: TextButton.icon(
                              onPressed: _retryEvaluationStats,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('تلاش دوباره'),
                            ),
                          ),
                        ),
                      )
                    else
                      _TeacherRatingsChartCard(
                        teacherRatings: _evaluationStats?.teacherRatings ?? const {},
                      ),
                    const SizedBox(height: 12),
                    if (_loadingFinancialAnalytics)
                      const _PerformanceCardShell(
                        title: 'گزارش مالی',
                        subtitle: 'در حال خواندن اطلاعات پرداختی...',
                        icon: Icons.account_balance_wallet_rounded,
                        accent: Color(0xFF00897B),
                        child: SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (_financialAnalyticsFailed)
                      _PerformanceCardShell(
                        title: 'گزارش مالی',
                        subtitle: 'اطلاعات مالی بارگذاری نشد',
                        icon: Icons.account_balance_wallet_rounded,
                        accent: const Color(0xFF00897B),
                        child: SizedBox(
                          height: 120,
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _loadingFinancialAnalytics = true;
                                  _financialAnalyticsFailed = false;
                                });
                                _loadFinancialAnalytics();
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('تلاش دوباره'),
                            ),
                          ),
                        ),
                      )
                    else ...[
                      _TuitionDonutChartCard(
                        classAmounts: _financialAnalytics?.classTuitionAmounts ?? const {},
                      ),
                      const SizedBox(height: 12),
                      _MonthlyIncomeBarChartCard(
                        monthlyIncomeMillions: _financialAnalytics?.monthlyIncomeMillions ?? const {},
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (_loadingAttendance)
                      const _PerformanceCardShell(
                        title: 'نرخ حضور هفتگی',
                        subtitle: 'در حال خواندن از آرشیو حضور و غیاب...',
                        icon: Icons.event_available_rounded,
                        accent: Color(0xFF1565C0),
                        child: SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else
                      _WeeklyAttendanceBarChartCard(weeklyAttendanceRates: _weeklyRates),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _TeacherRatingsChartCard extends StatelessWidget {
  final Map<String, double> teacherRatings;

  const _TeacherRatingsChartCard({required this.teacherRatings});

  @override
  Widget build(BuildContext context) {
    final ratings = teacherRatings.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _PerformanceCardShell(
      title: 'ارزیابی اولیا از مربیان',
      subtitle: 'امتیاز مربی اختصاصی فرزند بر اساس رأی اولیا',
      icon: Icons.stars_rounded,
      accent: const Color(0xFFFFA000),
      child: ratings.isEmpty
          ? const _EmptyChartMessage()
          : Column(
              children: [
                for (final rating in ratings)
                  _TeacherRatingRow(
                    teacherName: rating.key,
                    score: rating.value,
                  ),
              ],
            ),
    );
  }
}

class _TeacherRatingRow extends StatelessWidget {
  final String teacherName;
  final double score;

  const _TeacherRatingRow({required this.teacherName, required this.score});

  @override
  Widget build(BuildContext context) {
    final normalizedScore = score.clamp(0, 5).toDouble();
    final fullStars = normalizedScore.floor();
    final hasHalfStar = normalizedScore - fullStars >= 0.5;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  teacherName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var star = 1; star <= 5; star++)
                    Icon(
                      star <= fullStars
                          ? Icons.star_rounded
                          : star == fullStars + 1 && hasHalfStar
                              ? Icons.star_half_rounded
                              : Icons.star_outline_rounded,
                      color: const Color(0xFFFFB300),
                      size: 16,
                    ),
                ],
              ),
              const SizedBox(width: 5),
              Text(
                normalizedScore.toStringAsFixed(1),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: normalizedScore / 5,
              minHeight: 8,
              backgroundColor: const Color(0xFFFFA000).withValues(alpha: 0.12),
              color: const Color(0xFFFFA000),
            ),
          ),
        ],
      ),
    );
  }
}

class _TuitionDonutChartCard extends StatelessWidget {
  final Map<String, double> classAmounts;

  const _TuitionDonutChartCard({required this.classAmounts});

  static const List<Color> _palette = [
    Color(0xFF1565C0),
    Color(0xFF00897B),
    Color(0xFFEF6C00),
    Color(0xFF8E24AA),
    Color(0xFF3949AB),
    Color(0xFF7CB342),
    Color(0xFFD81B60),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = classAmounts.entries.where((entry) => entry.value > 0).toList();
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
    return _PerformanceCardShell(
      title: 'سهم شهریهٔ کلاس‌ها',
      subtitle: 'توزیع مبلغ شهریه به تفکیک کلاس',
      icon: Icons.donut_large_rounded,
      accent: const Color(0xFF1565C0),
      child: entries.isEmpty || total <= 0
          ? const _EmptyChartMessage()
          : Column(
              children: [
                SizedBox(
                  height: 190,
                  child: CustomPaint(
                    painter: _TuitionDonutPainter(
                      values: entries.map((entry) => entry.value).toList(),
                      colors: List.generate(entries.length, (index) => _palette[index % _palette.length]),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('جمع شهریه', style: TextStyle(color: Colors.black54, fontSize: 11)),
                          Text(_compactMoney(total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                          const Text('تومان', style: TextStyle(color: Colors.black45, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                for (var index = 0; index < entries.length; index++)
                  _TuitionLegendRow(
                    label: entries[index].key,
                    amount: entries[index].value,
                    share: entries[index].value / total,
                    color: _palette[index % _palette.length],
                  ),
              ],
            ),
    );
  }
}

class _TuitionDonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  const _TuitionDonutPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 25
      ..color = const Color(0xFFECEFF1);
    canvas.drawCircle(center, radius, trackPaint);
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = values[index] / total * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 25
        ..strokeCap = StrokeCap.butt
        ..color = colors[index];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _TuitionDonutPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}

class _TuitionLegendRow extends StatelessWidget {
  final String label;
  final double amount;
  final double share;
  final Color color;

  const _TuitionLegendRow({
    required this.label,
    required this.amount,
    required this.share,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
          Text('${(share * 100).toStringAsFixed(0)}٪', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('${_compactMoney(amount)} تومان', style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _MonthlyIncomeBarChartCard extends StatelessWidget {
  final Map<String, double> monthlyIncomeMillions;

  const _MonthlyIncomeBarChartCard({required this.monthlyIncomeMillions});

  @override
  Widget build(BuildContext context) {
    final entries = monthlyIncomeMillions.entries.toList();
    return _PerformanceCardShell(
      title: 'مقایسهٔ درآمد ماهانه',
      subtitle: 'مبالغ به میلیون تومان',
      icon: Icons.bar_chart_rounded,
      accent: const Color(0xFF00897B),
      child: entries.isEmpty
          ? const _EmptyChartMessage()
          : SizedBox(
              height: 220,
              width: double.infinity,
              child: CustomPaint(
                painter: _MonthlyIncomePainter(
                  labels: entries.map((entry) => entry.key).toList(),
                  values: entries.map((entry) => entry.value).toList(),
                ),
              ),
            ),
    );
  }
}

class _MonthlyIncomePainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;

  const _MonthlyIncomePainter({required this.labels, required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.isEmpty) return;
    const leftInset = 38.0;
    const topInset = 22.0;
    const bottomInset = 38.0;
    const rightInset = 8.0;
    final chartWidth = size.width - leftInset - rightInset;
    final chartHeight = size.height - topInset - bottomInset;
    final maxValue = values.fold<double>(
      0,
      (currentMax, value) => math.max(currentMax, value).toDouble(),
    );
    if (chartWidth <= 0 || chartHeight <= 0 || maxValue <= 0) return;

    final baseY = topInset + chartHeight;
    final axisPaint = Paint()
      ..color = const Color(0xFFCFD8DC)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(leftInset, topInset), Offset(leftInset, baseY), axisPaint);
    canvas.drawLine(Offset(leftInset, baseY), Offset(size.width - rightInset, baseY), axisPaint);

    final step = chartWidth / values.length;
    final barWidth = math.min(30.0, step * 0.58);
    for (var index = 0; index < values.length; index++) {
      final barHeight = chartHeight * (values[index] / maxValue);
      final centerX = leftInset + step * (index + 0.5);
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - barWidth / 2, baseY - barHeight, barWidth, barHeight),
        const Radius.circular(6),
      );
      final barPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF26A69A), Color(0xFF00897B)],
        ).createShader(barRect.outerRect);
      canvas.drawRRect(barRect, barPaint);

      _drawLabel(
        canvas,
        values[index].toStringAsFixed(values[index] % 1 == 0 ? 0 : 1),
        Offset(centerX, math.max(0, baseY - barHeight - 15).toDouble()),
        fontSize: 9,
        color: const Color(0xFF455A64),
      );
      _drawLabel(
        canvas,
        labels[index],
        Offset(centerX, baseY + 15),
        fontSize: 9,
        color: const Color(0xFF546E7A),
      );
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset center, {required double fontSize, required Color color}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color)),
      textDirection: TextDirection.rtl,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 64);
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MonthlyIncomePainter oldDelegate) =>
      oldDelegate.labels != labels || oldDelegate.values != values;
}

/// نمودار ستونی نرخ حضور ۵ روز هفته (شنبه تا چهارشنبه)
class _WeeklyAttendanceBarChartCard extends StatelessWidget {
  final Map<String, double> weeklyAttendanceRates;

  /// ترتیب ثابت روزهای کاری مدرسه
  static const List<String> _weekdayOrder = [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
  ];

  const _WeeklyAttendanceBarChartCard({required this.weeklyAttendanceRates});

  @override
  Widget build(BuildContext context) {
    // ترتیب ثابت روزها؛ اگر داده‌ای نبود، خالی می‌ماند
    final labels = <String>[];
    final values = <double>[];
    for (final day in _weekdayOrder) {
      if (weeklyAttendanceRates.containsKey(day)) {
        labels.add(day);
        values.add(weeklyAttendanceRates[day]!.clamp(0, 100));
      }
    }

    return _PerformanceCardShell(
      title: 'نرخ حضور هفتگی',
      subtitle: 'میانگین حضور بچه‌ها از شنبه تا چهارشنبه (درصد)',
      icon: Icons.event_available_rounded,
      accent: const Color(0xFF1565C0),
      child: labels.isEmpty
          ? const _EmptyChartMessage()
          : SizedBox(
              height: 220,
              width: double.infinity,
              child: CustomPaint(
                painter: _WeeklyAttendancePainter(
                  labels: labels,
                  values: values,
                ),
              ),
            ),
    );
  }
}

class _WeeklyAttendancePainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;

  const _WeeklyAttendancePainter({required this.labels, required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.isEmpty) return;
    const leftInset = 38.0;
    const topInset = 22.0;
    const bottomInset = 38.0;
    const rightInset = 8.0;
    final chartWidth = size.width - leftInset - rightInset;
    final chartHeight = size.height - topInset - bottomInset;
    // مقیاس ثابت ۰ تا ۱۰۰ برای درصد حضور
    const maxValue = 100.0;
    if (chartWidth <= 0 || chartHeight <= 0) return;

    final baseY = topInset + chartHeight;
    final axisPaint = Paint()
      ..color = const Color(0xFFCFD8DC)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(leftInset, topInset), Offset(leftInset, baseY), axisPaint);
    canvas.drawLine(Offset(leftInset, baseY), Offset(size.width - rightInset, baseY), axisPaint);

    // خطوط راهنمای افقی (۲۵٪، ۵۰٪، ۷۵٪، ۱۰۰٪)
    final guidePaint = Paint()
      ..color = const Color(0xFFECEFF1)
      ..strokeWidth = 1;
    for (final pct in [0.25, 0.5, 0.75, 1.0]) {
      final y = baseY - chartHeight * pct;
      canvas.drawLine(Offset(leftInset, y), Offset(size.width - rightInset, y), guidePaint);
      _drawLabel(
        canvas,
        '${(pct * 100).toInt()}٪',
        Offset(leftInset - 18, y),
        fontSize: 8,
        color: const Color(0xFF90A4AE),
      );
    }

    final step = chartWidth / values.length;
    final barWidth = math.min(36.0, step * 0.58);
    for (var index = 0; index < values.length; index++) {
      final barHeight = chartHeight * (values[index] / maxValue);
      final centerX = leftInset + step * (index + 0.5);
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - barWidth / 2, baseY - barHeight, barWidth, barHeight),
        const Radius.circular(6),
      );

      // رنگ بر اساس سطح حضور: سبز خوب، نارنجی متوسط، قرمز ضعیف
      final Color topColor;
      final Color bottomColor;
      if (values[index] >= 90) {
        topColor = const Color(0xFF66BB6A);
        bottomColor = const Color(0xFF2E7D32);
      } else if (values[index] >= 75) {
        topColor = const Color(0xFF42A5F5);
        bottomColor = const Color(0xFF1565C0);
      } else if (values[index] >= 60) {
        topColor = const Color(0xFFFFB74D);
        bottomColor = const Color(0xFFEF6C00);
      } else {
        topColor = const Color(0xFFEF9A9A);
        bottomColor = const Color(0xFFC62828);
      }

      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, bottomColor],
        ).createShader(barRect.outerRect);
      canvas.drawRRect(barRect, barPaint);

      _drawLabel(
        canvas,
        '${values[index].toStringAsFixed(values[index] % 1 == 0 ? 0 : 1)}٪',
        Offset(centerX, math.max(0, baseY - barHeight - 15).toDouble()),
        fontSize: 9,
        color: const Color(0xFF455A64),
      );
      _drawLabel(
        canvas,
        labels[index],
        Offset(centerX, baseY + 15),
        fontSize: 9,
        color: const Color(0xFF546E7A),
      );
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset center, {required double fontSize, required Color color}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color)),
      textDirection: TextDirection.rtl,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 64);
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _WeeklyAttendancePainter oldDelegate) =>
      oldDelegate.labels != labels || oldDelegate.values != values;
}

class _PerformanceCardShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;

  const _PerformanceCardShell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyChartMessage extends StatelessWidget {
  const _EmptyChartMessage();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 150,
        child: Center(child: Text('داده‌ای برای نمایش نمودار موجود نیست', style: TextStyle(color: Colors.black45))),
      );
}

String _compactMoney(double amount) {
  final rounded = amount.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < rounded.length; index++) {
    if (index > 0 && (rounded.length - index) % 3 == 0) buffer.write('٬');
    buffer.write(rounded[index]);
  }
  return buffer.toString();
}
