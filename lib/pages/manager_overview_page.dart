import 'package:flutter/material.dart';

// مدل‌ها و سرویس‌ها
import '../models/permissions.dart';
import '../models/announcement_model.dart';
import '../models/nutrition_model.dart'; // شامل StudentDirectory
import '../models/attendance_archive_model.dart';
import '../models/attendance_edit_request_model.dart';
import '../utils/jalali.dart';
import '../utils/export_helper.dart';
import '../widgets/live_clock_banner.dart';
import '../widgets/safe_image.dart';
import '../teacher/teacher_sections.dart' show PageHost;

// صفحات دیگر مدیر
import 'manager_attendance_archive_page.dart';
import 'manager_user_management_page.dart';
import 'manager_financial_page.dart';
import 'manager_payment_receipts_page.dart';
import 'manager_permissions_page.dart';
import 'manager_requests_page.dart';
import 'manager_nutrition_page.dart';
import 'educational_planning_page.dart';
import 'admin_settings_page.dart';
import 'audit_log_page.dart';
import 'toolbox_page.dart';
import 'private_message_page.dart';
import 'report_card_pages.dart';
import 'video_meetings_page.dart';
import 'registration_manager_page.dart';

// این سه کلاس هنوز داخل main.dart هستند.
// بعد از استخراج آن‌ها، این import را حذف و importهای جدید را جایگزین کنید.
import 'class_story_page.dart';
import 'chat_page.dart';
import 'teacher_toolkit_page.dart';

class ManagerOverviewPage extends StatefulWidget {
  final AppRole role;
  const ManagerOverviewPage({super.key, this.role = AppRole.manager});

  @override
  State<ManagerOverviewPage> createState() => _ManagerOverviewPageState();
}

class _ManagerOverviewPageState extends State<ManagerOverviewPage> {
  bool _can(Perm p) => PermissionService.instance.can(widget.role, p);

  // آمار واقعی (به‌جای اعداد ثابت)
  String _statStudents = '—';
  String _statTeachers = '—';
  String _statAttendance = '—';
  String _statPending = '—';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final students = await StudentDirectory.load();
    final teachers = await StudentDirectory.countByRole('teacher');
    final today = JalaliDate.now().formatted;
    final all = await AttendanceArchiveService.getRecords();
    final todays = all.where((r) => r.date == today).toList();
    final reqs = await EditRequestService.getAll();
    if (!mounted) return;
    final attended = todays.where((r) => !r.status.contains('غایب')).length;
    setState(() {
      _statStudents = '${faDigits(students.length)} نفر';
      _statTeachers = teachers == null ? '—' : '${faDigits(teachers)} نفر';
      _statAttendance = todays.isEmpty ? 'ثبت نشده' : '${faDigits((attended * 100 / todays.length).round())}٪';
      _statPending = '${faDigits(reqs.where((r) => r.state == 'pending').length)} مورد';
    });
  }

  void _openBroadcastDialog() {
    if (!PermissionService.instance.can(widget.role, Perm.sendBroadcast)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شما اجازهٔ ارسال بخشنامه را ندارید'), backgroundColor: Colors.red),
      );
      return;
    }
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController bodyCtrl = TextEditingController();
    String audience = Audience.all;
    bool sending = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.announcement_rounded, color: Color(0xFF0288D1), size: 28),
                SizedBox(width: 8),
                Expanded(child: Text('ارسال بخشنامه و اطلاعیه سراسری')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: audience,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'مخاطب', border: OutlineInputBorder(), isDense: true),
                    items: [
                      for (final a in const [Audience.all, Audience.parents, Audience.staff])
                        DropdownMenuItem(value: a, child: Text(Audience.label(a))),
                    ],
                    onChanged: (v) => setD(() => audience = v ?? audience),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'عنوان اطلاعیه (مثلاً: تعطیلی یا اردو)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'متن پیام...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: sending ? null : () => Navigator.pop(ctx),
                child: const Text('انصراف'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0288D1),
                  foregroundColor: Colors.white,
                ),
                onPressed: sending
                    ? null
                    : () async {
                        final title = titleCtrl.text.trim();
                        final body = bodyCtrl.text.trim();
                        if (title.isEmpty || body.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: const Text('عنوان و متن را کامل کنید'), backgroundColor: Colors.orange.shade800),
                          );
                          return;
                        }
                        setD(() => sending = true);
                        await AnnouncementService.send(title: title, body: body, audience: audience);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('📢 بخشنامه برای «${Audience.label(audience)}» ارسال شد'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                child: Text(sending ? 'در حال ارسال...' : 'ارسال فوری'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 750),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LiveClockBanner(),
              // Manager Header Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0288D1), Color(0xFF01579B)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withAlpha(80),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.admin_panel_settings_rounded, size: 36, color: Color(0xFF0288D1)),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مدیریت کل مهد و دبستان روزگار کودکی',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'پنل نظارت جامع، امور مالی، کاربران و بایگانی هوشمند',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    if (_can(Perm.sendBroadcast))
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB300),
                        foregroundColor: Colors.black87,
                      ),
                      onPressed: _openBroadcastDialog,
                      icon: const Icon(Icons.campaign_rounded),
                      label: const Text('بخشنامه'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Export Buttons Bar for Manager
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_can(Perm.exportReports))
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                    onPressed: () {
                      ExportHelper.exportToExcel(
                        context: context,
                        title: 'گزارش آماری مدیریت مهدکودک',
                        headers: ['شاخص آماری', 'مقدار / وضعیت'],
                        rows: [
                          ['کل نوآموزان ثبت‌نام شده', '۱۴۵ نفر'],
                          ['مربیان فعال', '۱۲ نفر'],
                          ['حضور متوسط امروز', '۹۸٪'],
                          ['رضایت اولیاء', '۴.۹ / ۵'],
                          ['وضعیت سیستم', 'فعال و پایدار'],
                        ],
                        fileName: 'manager_statistics_${DateTime.now().millisecondsSinceEpoch}',
                      );
                    },
                    icon: const Icon(Icons.table_chart_rounded, size: 18),
                    label: const Text('خروجی اکسل آمار 📊'),
                  ),
                  const SizedBox(width: 8),
                  if (_can(Perm.exportReports))
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                    onPressed: () {
                      ExportHelper.exportToPdf(
                        context: context,
                        title: 'گزارش رسمی مدیریت کل مهد و دبستان روزگار کودکی',
                        headers: ['شاخص آماری', 'مقدار / وضعیت'],
                        rows: [
                          ['کل نوآموزان ثبت‌نام شده', '۱۴۵ نفر'],
                          ['مربیان فعال', '۱۲ نفر'],
                          ['حضور متوسط امروز', '۹۸٪'],
                          ['رضایت اولیاء', '۴.۹ / ۵'],
                          ['وضعیت سیستم', 'فعال و پایدار'],
                        ],
                        fileName: 'manager_statistics_${DateTime.now().millisecondsSinceEpoch}',
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('خروجی PDF آمار 📄'),
                  ),
                  /*print*/
                  if (_can(Perm.exportReports)) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade700, foregroundColor: Colors.white),
                    onPressed: () {
                      ExportHelper.printTable(
                        context: context,
                        title: 'گزارش رسمی مدیریت کل مهد و دبستان روزگار کودکی',
                        headers: ['شاخص آماری', 'مقدار / وضعیت'],
                        rows: [
                          ['کل نوآموزان ثبت‌نام شده', '۱۴۵ نفر'],
                          ['مربیان فعال', '۱۲ نفر'],
                          ['حضور متوسط امروز', '۹۸٪'],
                          ['رضایت اولیاء', '۴.۹ / ۵'],
                          ['وضعیت سیستم', 'فعال و پایدار'],
                        ],
                        fileName: 'manager_statistics_${DateTime.now().millisecondsSinceEpoch}',
                      );
                    },
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('چاپ'),
                  ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Dedicated Manager Attendance Archive Card (Read-Only)
              if (_can(Perm.viewAttendance))
              Card(
                elevation: 4,
                color: const Color(0xFFE1F5FE),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ManagerAttendanceArchivePage(role: widget.role)),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 64,
                          child: SafeAssetImage('ill_archive.png', fit: BoxFit.contain),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'بایگانی جامع حضور و غیاب',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF0288D1), size: 18),
                      ],
                    ),
                  ),
                ),
              ),

              if (_can(Perm.viewAuditLog)) ...[
                const SizedBox(height: 12),
                Card(
                  elevation: 3,
                  color: const Color(0xFFE0F2F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: SizedBox(
                      height: 52,
                      width: 60,
                      child: SafeAssetImage('ill_audit_log.png', fit: BoxFit.contain),
                    ),
                    title: const Text('گزارش تغییرات', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('چه کسی، چه زمانی، چه چیزی را تغییر داد', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuditLogPage()),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '📈 آمار کلی و عملکرد مدرسه در یک نگاه:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
                    ),
                  ),
                  IconButton(
                    tooltip: 'به‌روزرسانی آمار',
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF01579B)),
                    onPressed: _loadStats,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                children: [
                  _buildStatCard('کل نوآموزان', _statStudents, Icons.child_care_rounded, Colors.orange),
                  _buildStatCard('مربیان ثبت‌شده', _statTeachers, Icons.badge_rounded, Colors.purple),
                  _buildStatCard('حضور امروز', _statAttendance, Icons.how_to_reg_rounded, Colors.green),
                  _buildStatCard('اصلاح در انتظار', _statPending, Icons.rule_folder_rounded, Colors.amber),
                ],
              ),
              const SizedBox(height: 24),

              // Comprehensive Management Modules (User requests, Financial, Permissions, Nutrition, etc.)
              const Text(
                '🗂️ بخش‌های کلیدی مدیریت و نظارت:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
              ),
              const SizedBox(height: 12),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 230,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 196,
                ),
                children: [
                  if (_can(Perm.manageUsers))
                  _buildManagementCard(
                    'پرونده ثبت‌نام نوآموز',
                    'مشاهده و چاپ پرونده‌های ثبت‌نام',
                    Icons.assignment_ind_rounded,
                    Colors.lightBlue,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationManagerPage())),
                  ),
                  if (_can(Perm.manageUsers))
                  _buildManagementCard(
                    'مدیریت کاربران',
                    'ثبت‌نام، پرونده سلامت و تخصیص کلاس',
                    Icons.people_alt_rounded,
                    Colors.blue,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManagerUserManagementPage()),
                    ),
                  ),
                  if (_can(Perm.viewFinancial))
                  _buildManagementCard(
                    'امور مالی و شهریه',
                    'پرداخت‌ها، فیش‌ها و لیست بدهکاران',
                    Icons.account_balance_wallet_rounded,
                    Colors.green,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManagerFinancialPage()),
                    ),
                  ),
                  if (_can(Perm.viewFinancial))
                  _buildManagementCard(
                    'رسیدهای پرداخت',
                    'تأیید یا رد رسیدهای ارسالی والدین',
                    Icons.receipt_long_rounded,
                    Colors.teal,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManagerPaymentReceiptsPage()),
                    ),
                  ),
                  if (_can(Perm.manageNutrition))
                  _buildManagementCard(
                    'تغذیه و سلامت',
                    'منوی غذایی هفتگی و حساسیت‌های پزشکی',
                    Icons.restaurant_menu_rounded,
                    Colors.deepOrange,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManagerNutritionPage()),
                    ),
                  ),
                  if (_can(Perm.managePlanning))
                  _buildManagementCard(
                    'برنامه‌ریزی آموزشی',
                    'مدیریت و نظارت بر برنامه هفتگی و روزانه کلاس‌ها',
                    Icons.menu_book_rounded,
                    Colors.purple,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EducationalPlanningPage()),
                    ),
                  ),
                  if (_can(Perm.manageAppSettings))
                  _buildManagementCard(
                    'تنظیمات برنامه و اشتراک',
                    'اطلاعات مجموعه، طرح اشتراک و آمار سیستم',
                    Icons.settings_suggest_rounded,
                    Colors.blueGrey,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminSettingsPage()),
                    ),
                  ),
                  if (_can(Perm.managePermissions))
                  _buildManagementCard(
                    'تنظیمات دسترسی‌ها',
                    'تعیین سطوح دسترسی معلمان و معاونین',
                    Icons.security_rounded,
                    Colors.indigo,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManagerPermissionsPage()),
                    ),
                  ),
                  _buildManagementCard(
                    'جعبه ابزار',
                    'مبدل‌ها، دفترچه، ماشین‌حساب و ابزارهای کلاس',
                    Icons.handyman_rounded,
                    Colors.deepPurple,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ToolboxPage(classTools: (_) => const TeacherToolkitPage())),
                    ),
                  ),
                  _buildManagementCard(
                    'جلسهٔ تصویری کارکنان',
                    'ساخت و مشاهدهٔ پیوند جلسه برای کادر مدرسه',
                    Icons.video_call_rounded,
                    Colors.teal,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => VideoMeetingsPage(role: widget.role)),
                    ),
                  ),
                  _buildManagementCard(
                    'داستان مدرسه',
                    'عکس و لحظه‌های کلاس‌ها',
                    Icons.auto_stories_rounded,
                    Colors.pink,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PageHost(
                          title: 'داستان مدرسه',
                          child: ClassStoryPage(userRole: widget.role == AppRole.deputy ? 'deputy' : 'manager'),
                        ),
                      ),
                    ),
                  ),
                  _buildManagementCard(
                    'پیام‌ها',
                    'گفتگو با مربیان و اولیا',
                    Icons.mark_chat_unread_rounded,
                    Colors.cyan,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PageHost(title: 'پیام‌ها', child: ChatPage())),
                    ),
                  ),
                  if (_can(Perm.approveAttendanceEdit) || _can(Perm.approveRequests))
                  _buildManagementCard(
                    'درخواست‌ها و تاییدیه',
                    'اصلاح حضور و غیاب، مرخصی و ثبت‌نام‌ها',
                    Icons.rule_folder_rounded,
                    Colors.amber.shade800,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManagerRequestsPage()),
                    ),
                  ),
                  if (_can(Perm.reviewPrivateMessages))
                  _buildManagementCard(
                    'بازبینی پیام‌های خصوصی',
                    'فقط با ثبت دلیل؛ در گزارش تغییرات ثبت می‌شود',
                    Icons.policy_rounded,
                    Colors.brown,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PrivateMessagesHub()),
                    ),
                  ),
                  if (_can(Perm.viewReportCard))
                  _buildManagementCard(
                    'کارنامه‌ها',
                    'ارزشیابی توصیفی نوآموزان همهٔ کلاس‌ها',
                    Icons.workspace_premium_rounded,
                    Colors.deepPurple,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportCardHubPage()),
                    ),
                  ),
                  if (_can(Perm.viewAuditLog))
                  _buildManagementCard(
                    'گزارش تغییرات',
                    'چه کسی، چه زمانی، چه چیزی را تغییر داد',
                    Icons.history_rounded,
                    Colors.teal,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuditLogPage()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                '🏫 وضعیت کلاس‌ها و مربیان:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
              ),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 3,
                child: ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    const ListTile(
                      leading: CircleAvatar(backgroundColor: Color(0xFFE1F5FE), child: Icon(Icons.school_rounded, color: Color(0xFF0288D1))),
                      title: Text('کلاس پیش‌دبستانی آفتاب ☀️', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('مربی: خانم رضایی • تعداد نوآموزان: ۲۵ نفر'),
                      trailing: Text('فعال ✅', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                    const Divider(),
                    const ListTile(
                      leading: CircleAvatar(backgroundColor: Color(0xFFFFF9C4), child: Icon(Icons.school_rounded, color: Color(0xFFF57F17))),
                      title: Text('کلاس اول دبستان ستاره 🌟', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('مربی: آقای محمدی • تعداد نوآموزان: ۳۰ نفر'),
                      trailing: Text('فعال ✅', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.school_rounded, color: Colors.green)),
                      title: const Text('کلاس دوم دبستان مهتاب 🌙', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('مربی: خانم احمدی • تعداد نوآموزان: ۲۸ نفر'),
                      trailing: const Text('فعال ✅', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  static const Map<String, String> _cardImages = {
    'پرونده ثبت‌نام نوآموز': 'ill_students.png',
    'جعبه ابزار': 'ill_toolbox.png',
    'داستان مدرسه': 'ill_fun.png',
    'مدیریت کاربران': 'ill_user_management.png',
    'امور مالی و شهریه': 'scene_payment.png',
    'تغذیه و سلامت': 'ill_nutrition_health.png',
    'برنامه‌ریزی آموزشی': 'ill_educational_planning.png',
    'تنظیمات برنامه و اشتراک': 'ill_admin.png',
    'تنظیمات دسترسی‌ها': 'ill_management.png',
    'درخواست‌ها و تاییدیه': 'ill_requests.png',
    'گزارش تغییرات': 'ill_audit_log.png',
    'بازبینی پیام‌های خصوصی': 'scene_messages.png',
    'کارنامه‌ها': 'scene_report.png',
  };

  Widget _buildManagementCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    final image = _cardImages[title];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
            children: [
              Expanded(
                child: image != null
                    ? SafeAssetImage(image, fit: BoxFit.contain)
                    : Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 34),
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF01579B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
