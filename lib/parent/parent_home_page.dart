import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../parent/parent_sections.dart';
import '../models/permissions.dart';
import '../models/attendance_archive_model.dart';
import '../models/announcement_model.dart';
import '../models/nutrition_model.dart';
import '../utils/jalali.dart';
import '../widgets/nutrition_views.dart';
import '../widgets/safe_image.dart';
import '../widgets/world3d_background.dart';
import '../widgets/pop_out_card.dart';
import '../pages/toolbox_page.dart';
import '../widgets/live_clock_banner.dart';
import '../widgets/plans_view.dart';
import '../pages/private_message_page.dart';
import '../pages/report_card_pages.dart';
import '../pages/registration_page.dart';
import '../pages/evaluation_feedback_page.dart';
import '../pages/video_meetings_page.dart';

class _Section {
  final String title;
  final String image;
  final Color tint;
  final void Function(BuildContext context) onTap;
  final Perm? perm; // اگر مقدار داشته باشد، فقط با مجوز نمایش داده می‌شود
  const _Section(this.title, this.image, this.tint, this.onTap, [this.perm]);
}

/// صفحهٔ اصلی ولی
class ParentHomePage extends StatefulWidget {
  /// برای رفتن به زبانه‌های پایین (۱ پیام‌ها، ۲ داستان کلاس، ۳ پیشرفت)
  final void Function(int tabIndex) onOpenTab;

  const ParentHomePage({super.key, required this.onOpenTab});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  String _today = '—';
  String _announcements = '—';
  String _menu = '—';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = JalaliDate.now();
    var today = 'ثبت نشده';
    if (PermissionService.instance.can(AppRole.parent, Perm.viewAttendance)) {
      final recs = await AttendanceArchiveService.recordsFor(Session.className, now.formatted);
      final mine = recs.where((r) => r.studentName == Session.childName).toList();
      if (mine.isNotEmpty) {
        final s = mine.first.status;
        today = s.contains('غایب') ? 'غایب' : (s.contains('تأخیر') ? 'تأخیر' : 'حاضر');
      }
    } else {
      today = '—';
    }
    final anns = await AnnouncementService.visibleTo(AppRole.parent, className: Session.className);
    final menu = await NutritionService.getMenu();
    final day = menu[now.weekdayName] ?? const {};
    final hasMenu = day.values.any((v) => v.trim().isNotEmpty);
    if (!mounted) return;
    setState(() {
      _today = today;
      _announcements = '${faDigits(anns.length)} مورد';
      _menu = hasMenu ? 'ثبت شده' : 'ثبت نشده';
    });
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final allSections = <_Section>[
      _Section('حضور و غیاب', 'scene_attendance.png', const Color(0xFFE3F2FD), (c) => _push(c, const AttendancePage()), Perm.viewAttendance),
      _Section('پیام‌ها', 'scene_messages.png', const Color(0xFFFFF3CD), (c) => widget.onOpenTab(1)),
      _Section('تکالیف', 'ill_homework_upload.png', const Color(0xFFE6F7EF), (c) => _push(c, const HomeworkPage()), Perm.viewHomework),
      _Section('برنامهٔ هفتگی', 'ill_calendar.png', const Color(0xFFEDE7F6), (c) => _push(c, const SchedulePage())),
      _Section('کارنامه', 'scene_report.png', const Color(0xFFFFE8E0), (c) => _push(c, const ParentReportCardPage()), Perm.viewReportCard),
      _Section('پیشرفت و امتیاز', 'char_13.png', const Color(0xFFFFF8E1), (c) => widget.onOpenTab(3)),
      _Section('گالری و داستان کلاس', 'scene_gallery.png', const Color(0xFFE0F7FA), (c) => widget.onOpenTab(2)),
      _Section('منوی غذایی', 'ill_menu.png', const Color(0xFFE8F5E9), (c) => _push(c, const ParentNutritionPage())),
      _Section('برنامه‌های آموزشی', 'ill_educational_planning.png', const Color(0xFFEDE7F6), (c) => _push(c, const PlansPage(role: AppRole.parent)), Perm.viewPlans),
      _Section('اطلاعیه‌ها', 'ill_announcement.png', const Color(0xFFFCE4EC), (c) => _push(c, const AnnouncementsPage())),
      _Section('پیام خصوصی به مربی', 'scene_messages.png', const Color(0xFFE3F2FD), (c) => _push(c, PrivateChatPage(studentName: Session.childName)), Perm.sendPrivateMessage),
      _Section('جعبه ابزار', 'ill_toolbox.png', const Color(0xFFEDE7F6), (c) => _push(c, const ToolboxPage())),
      _Section('جلسهٔ تصویری', 'scene_messages.png', const Color(0xFFE3F2FD), (c) => _push(c, const VideoMeetingsPage(role: AppRole.parent))),
      _Section('پرداخت و اشتراک', 'scene_payment.png', const Color(0xFFFFF8E1), (c) => _push(c, const PaymentPage()), Perm.viewFinancial),
      _Section('پرونده ثبت‌نام نوآموز', 'ill_students.png', const Color(0xFFE1F5FE), (c) => _push(c, const RegistrationPage())),
      _Section('نظرسنجی و ارزیابی کیفیت', 'ill_audit_log.png', const Color(0xFFFFF3E0), (c) => _push(c, const EvaluationFeedbackPage())),
    ];
    final perms = PermissionService.instance;
    final sections = allSections.where((x) => x.perm == null || perms.can(AppRole.parent, x.perm!)).toList();

    return WorldBackground(
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final wide = w >= 800;

          return RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LiveClockBanner(),
                      // برخلاف صفحهٔ معلم: اول کارت فرزند، بعد آمار
                      if (wide)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 3, child: _childCard()),
                              const SizedBox(width: 14),
                              Expanded(flex: 2, child: _stats(true)),
                            ],
                          ),
                        )
                      else ...[
                        _childCard(),
                        const SizedBox(height: 14),
                        _stats(false),
                      ],
                      const SizedBox(height: 20),
                      const Text('بخش‌ها',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      const SizedBox(height: 10),
                      PopOutGrid(
                        children: [
                          for (final s in sections)
                            PopOutCard(
                              title: s.title,
                              image: s.image,
                              tint: Color.lerp(s.tint, AppColors.navy, 0.35)!,
                              onTap: () => s.onTap(context),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _stats(bool stretch) {
    final today = JalaliDate.now();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'خلاصهٔ امروز',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              Text(
                '${today.weekdayName} ${faDigits(today.day)} ${today.monthName}',
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _miniStat(Icons.check_circle_rounded, 'امروز', _today, const Color(0xFF2E9E6B)),
                const SizedBox(width: 8),
                _miniStat(Icons.restaurant_rounded, 'منوی امروز', _menu, const Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                _miniStat(Icons.campaign_rounded, 'اطلاعیه', _announcements, const Color(0xFF1473C9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _childCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF244E76), Color(0xFF1473C9)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x33244E76), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: Color(0xFFF1C451), shape: BoxShape.circle),
            child: ChildAvatar(name: Session.childName, size: 70),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Session.childName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(Session.className, style: const TextStyle(color: Color(0xFFD8E9F9))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF1C451), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Icon(Icons.wb_sunny_rounded, color: Color(0xFF244E76)),
                Text(faDigits(JalaliDate.now().day), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF244E76), fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, String value, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 21),
            const SizedBox(height: 4),
            Text(value, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 12)),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }
}
