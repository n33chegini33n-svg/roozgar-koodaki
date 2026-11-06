import 'package:flutter/material.dart';

// مدل‌ها و سرویس‌ها
import '../models/permissions.dart';
import '../models/announcement_model.dart';
import '../models/attendance_edit_request_model.dart';
import '../services/backend.dart';
import '../services/manager_payment_service.dart';
import '../services/registration_admin_service.dart';
import '../services/purchase_service.dart';
import '../utils/export_helper.dart';
import '../widgets/live_clock_banner.dart';
import '../widgets/safe_image.dart';
import '../widgets/world3d_background.dart';
import '../widgets/pop_out_card.dart';
import '../teacher/teacher_sections.dart' show PageHost;

// صفحات دیگر مدیر
import 'manager_attendance_archive_page.dart';
import 'manager_user_management_page.dart';
import 'manager_financial_page.dart';
import 'manager/manager_performance_charts.dart';
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
import 'purchase_form_page.dart';
import '../widgets/classes_dashboard_card.dart';

// این سه کلاس هنوز داخل main.dart هستند.
// بعد از استخراج آن‌ها، این import را حذف و importهای جدید را جایگزین کنید.
import 'class_story_page.dart';
import 'chat_page.dart';
import 'teacher_toolkit_page.dart';

class ManagerOverviewPage extends StatefulWidget {
  final AppRole role;
  const ManagerOverviewPage({super.key, this.role = AppRole.manager});

  @override
  State<ManagerOverviewPage> createState() => ManagerOverviewPageState();
}

class ManagerOverviewPageState extends State<ManagerOverviewPage> {
  bool _can(Perm p) => PermissionService.instance.can(widget.role, p);

  int _pendingReceiptsCount = 0;
  int _pendingAttendanceCount = 0;
  int _pendingRegistrationsCount = 0;
  int _pendingDocumentsCount = 0;
  int _pendingPurchasesCount = 0;
  int _pendingBuyingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> reloadStats() => _loadStats();

  Future<void> _loadStats() async {
    try {
      final reqs = await EditRequestService.getAll();
      final pendingPayments = Backend.ready
          ? await ManagerPaymentService.pending()
          : <PendingPayment>[];
      final pendingRegistrations = await RegistrationAdminService.pendingCount();
      final pendingDocuments = await RegistrationAdminService.pendingAttachmentCount();
      final pendingPurchases = await PurchaseService.pendingCount();
      final buying = await PurchaseService.inProgressCount();
      if (!mounted) return;
      setState(() {
        _pendingReceiptsCount = pendingPayments.length;
        _pendingAttendanceCount = reqs.where((r) => r.state == 'pending').length;
        _pendingRegistrationsCount = pendingRegistrations;
        _pendingDocumentsCount = pendingDocuments;
        _pendingPurchasesCount = pendingPurchases;
        _pendingBuyingCount = buying;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تازه‌سازی کارتابل انجام نشد: $e')),
      );
    }
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
    return WorldBackground(
      child: SingleChildScrollView(
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
              const SizedBox(height: 14),
              ManagerPendingActionBanner(
                pendingReceipts: _pendingReceiptsCount,
                pendingAttendanceEdits: _pendingAttendanceCount,
                pendingRegistrations: _pendingRegistrationsCount,
                pendingDocuments: _pendingDocumentsCount,
                onOpenReceipts: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManagerFinancialPage()),
                ),
                onOpenRequests: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManagerRequestsPage()),
                ),
                onOpenRegistrations: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegistrationManagerPage()),
                ).then((_) => reloadStats()),
                onOpenDocuments: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegistrationManagerPage()),
                ).then((_) => reloadStats()),
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

              const SizedBox(height: 24),

              if (_can(Perm.manageUsers)) ...[
                const ClassesDashboardCard(),
                const SizedBox(height: 24),
              ],
              // Comprehensive Management Modules (User requests, Financial, Permissions, Nutrition, etc.)
              const Text(
                '🗂️ بخش‌های کلیدی مدیریت و نظارت:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
              ),
              const SizedBox(height: 12),
              PopOutGrid(
                children: [
                  _buildManagementCard(
                    'آمار و عملکرد مدرسه',
                    'نمودارهای رضایت اولیاء، امتیاز مربیان و وضعیت مالی',
                    Icons.insights_rounded,
                    Colors.teal,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SchoolPerformanceAnalyticsPage(),
                      ),
                    ),
                  ),
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
                  if (_can(Perm.approveRequests))
                  Stack(
                    children: [
                      _buildManagementCard(
                        'فرم درخواست کالا و خدمات',
                        'تأیید فرم‌ها و مدارک پیوست',
                        Icons.shopping_cart_rounded,
                        Colors.orange,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PurchaseManagerPage()),
                        ).then((_) => _loadStats()),
                      ),
                      if (_pendingPurchasesCount > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5484D),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_pendingPurchasesCount',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_can(Perm.approveRequests))
                  Stack(
                    children: [
                      _buildManagementCard(
                        'خریدها',
                        'فرم‌های ارجاع‌شده برای خرید و اسناد خرید',
                        Icons.shopping_bag_rounded,
                        Colors.green,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PurchaseBuyingPage(managerView: true)),
                        ).then((_) => _loadStats()),
                      ),
                      if (_pendingBuyingCount > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5484D),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_pendingBuyingCount',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                    ],
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
                      MaterialPageRoute(builder: (_) => AuditLogPage()),
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
    ));
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
    'آمار و عملکرد مدرسه': 'ill_admin_panel.png',
    'رسیدهای پرداخت': 'scene_payment.png',
    'جلسهٔ تصویری کارکنان': 'scene_messages.png',
    'پیام‌ها': 'scene_messages.png',
    'فرم درخواست کالا و خدمات': 'ill_requests.png',
    'خریدها': 'ill_requests.png',
  };

  Widget _buildManagementCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return PopOutCard(
      title: title,
      image: _cardImages[title] ?? 'ill_management.png',
      tint: color,
      onTap: onTap,
    );
  }
}
