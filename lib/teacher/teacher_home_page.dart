import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../parent/parent_sections.dart';
import 'teacher_sections.dart';
import '../models/permissions.dart';
import '../models/attendance_archive_model.dart';
import '../models/attendance_edit_request_model.dart';
import '../models/announcement_model.dart';
import '../models/nutrition_model.dart';
import '../utils/jalali.dart';
import '../widgets/announcements_feed.dart';
import '../widgets/nutrition_views.dart';
import '../widgets/safe_image.dart';
import '../pages/toolbox_page.dart';
import '../widgets/live_clock_banner.dart';
import '../widgets/plans_view.dart';
import '../models/school_classes.dart';
import '../pages/private_message_page.dart';
import '../pages/report_card_pages.dart';

class _TSection {
  final String title;
  final String image;
  final Color tint;
  final void Function(BuildContext context) onTap;
  final Perm? perm; // اگر مقدار داشته باشد، فقط با مجوز نمایش داده می‌شود
  const _TSection(this.title, this.image, this.tint, this.onTap, [this.perm]);
}

/// صفحهٔ اصلی معلم
class TeacherHomePage extends StatefulWidget {
  final void Function(int tabIndex) onOpenTab;
  final WidgetBuilder toolkitBuilder;

  const TeacherHomePage({super.key, required this.onOpenTab, required this.toolkitBuilder});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  String _present = '—';
  String _pending = '—';
  String _announcements = '—';
  String _classSize = '—';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recs = await AttendanceArchiveService.recordsFor(Session.className, JalaliDate.now().formatted);
    final reqs = await EditRequestService.getAll();
    final anns = await AnnouncementService.visibleTo(AppRole.teacher, className: Session.className);
    final students = await StudentDirectory.load();
    if (!mounted) return;
    final inClass = students.where((s) => sameClass(s.className, Session.className)).length;
    final total = inClass > 0 ? inClass : recs.length;
    setState(() {
      _present = recs.isEmpty
          ? 'ثبت نشده'
          : '${faDigits(recs.where((r) => r.status.contains('حاضر')).length)} از ${faDigits(total)}';
      _pending = '${faDigits(reqs.where((r) => r.requestedBy == Session.userName && r.state == 'pending').length)} مورد';
      _announcements = '${faDigits(anns.length)} مورد';
      _classSize = faDigits(total);
    });
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final allSections = <_TSection>[
      _TSection('حضور و غیاب', 'scene_attendance.png', const Color(0xFFE3F2FD), (c) => _push(c, const TeacherAttendancePage()), Perm.recordAttendance),
      _TSection('تکالیف', 'ill_homework_upload.png', const Color(0xFFE6F7EF), (c) => _push(c, const TeacherHomeworkPage()), Perm.manageHomework),
      _TSection('اطلاعیه برای اولیا', 'ill_announcement.png', const Color(0xFFFCE4EC), (c) => _push(c, const TeacherAnnouncePage()), Perm.sendParentAnnouncement),
      _TSection('پیام‌ها', 'scene_messages.png', const Color(0xFFFFF3CD), (c) => widget.onOpenTab(1)),
      _TSection('گالری و داستان کلاس', 'scene_gallery.png', const Color(0xFFE0F7FA), (c) => widget.onOpenTab(2)),
      _TSection('امتیاز و رفتار', 'char_13.png', const Color(0xFFFFF8E1), (c) => widget.onOpenTab(3), Perm.assignPoints),
      _TSection('پیام خصوصی به اولیا', 'scene_messages.png', const Color(0xFFE3F2FD), (c) => _push(c, const PrivateMessagesHub()), Perm.sendPrivateMessage),
      _TSection('کارنامه', 'scene_report.png', const Color(0xFFFFE8E0), (c) => _push(c, const ReportCardHubPage()), Perm.manageReportCard),
      _TSection('گزارش کلاس', 'scene_report.png', const Color(0xFFFFE8E0), (c) => _push(c, const ClassReportPage())),
      _TSection('جعبه ابزار', 'ill_toolbox.png', const Color(0xFFEDE7F6),
          (c) => _push(c, ToolboxPage(classTools: widget.toolkitBuilder))),
      _TSection('بخشنامه‌ها', 'ill_circular_rules.png', const Color(0xFFFFF3CD), (c) => _push(c, const BulletinPage(role: AppRole.teacher))),
      _TSection('منو و حساسیت‌ها', 'ill_nutrition_health.png', const Color(0xFFE8F5E9), (c) => _push(c, const TeacherNutritionPage())),
      _TSection('برنامه‌های آموزشی', 'ill_educational_planning.png', const Color(0xFFEDE7F6), (c) => _push(c, const PlansPage(role: AppRole.teacher)), Perm.viewPlans),
    ];
    final perms = PermissionService.instance;
    final sections = allSections.where((s) => s.perm == null || perms.can(AppRole.teacher, s.perm!)).toList();

    return Container(
      color: kPageBg,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final wide = w >= 800;
          final cols = w >= 1000 ? 4 : (w >= 700 ? 3 : 2);

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
                      const LiveClockBanner(accent: Color(0xFF2BB38E)),
                      // برخلاف صفحهٔ اولیا: اول آمار، بعد کارت معلم (در حالت عریض جای دو بخش عوض است)
                      if (wide)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 2, child: _stats(true)),
                              const SizedBox(width: 14),
                              Expanded(flex: 3, child: _teacherCard()),
                            ],
                          ),
                        )
                      else ...[
                        _stats(false),
                        const SizedBox(height: 14),
                        _teacherCard(),
                      ],
                      const SizedBox(height: 20),
                      const Text('کارهای کلاس',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.92,
                        children: [for (final s in sections) _sectionCard(context, s)],
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
    return Row(
      crossAxisAlignment: stretch ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
      children: [
        _miniStat(Icons.groups_rounded, 'حاضران امروز', _present, const Color(0xFF2E9E6B)),
        const SizedBox(width: 8),
        _miniStat(Icons.edit_note_rounded, 'اصلاح در انتظار', _pending, const Color(0xFFF59E0B)),
        const SizedBox(width: 8),
        _miniStat(Icons.campaign_rounded, 'اطلاعیه‌ها', _announcements, const Color(0xFF1473C9)),
      ],
    );
  }

  Widget _teacherCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF244E76), Color(0xFF2BB38E)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x33244E76), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(color: Color(0xFFFFF3CD), shape: BoxShape.circle),
            child: ClipOval(
              child: SafeAssetImage(
                'char_20.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                fallback: const Icon(Icons.person_rounded, color: AppColors.navy, size: 40),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_teacherName(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('مربی ${Session.className}', style: const TextStyle(color: Color(0xFFE3F7F0))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF1C451), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Icon(Icons.groups_rounded, color: Color(0xFF244E76)),
                Text(_classSize, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF244E76), fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _teacherName() {
    final name = Session.userName.replaceAll(RegExp(r'\s*\(.*\)\s*$'), '').trim();
    return name.isEmpty ? 'مربی' : name;
  }

  Widget _miniStat(IconData icon, String label, String value, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: c),
            const SizedBox(height: 4),
            Text(value, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 13)),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(BuildContext context, _TSection s) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => s.onTap(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: s.tint, borderRadius: BorderRadius.circular(16)),
                child: SafeAssetImage(s.image, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Text(
                s.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
