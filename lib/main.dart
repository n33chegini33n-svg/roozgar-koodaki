import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'auth/welcome_page.dart';
import 'parent/parent_shell.dart';
import 'teacher/teacher_shell.dart';
import 'pages/manager_attendance_archive_page.dart';
import 'pages/manager_user_management_page.dart';
import 'pages/manager_financial_page.dart';
import 'pages/manager_permissions_page.dart';
import 'pages/manager_requests_page.dart';
import 'pages/audit_log_page.dart';
import 'pages/admin_settings_page.dart';
import 'pages/manager_nutrition_page.dart';
import 'pages/educational_planning_page.dart';
import 'models/announcement_model.dart';
import 'models/points_model.dart';
import 'widgets/live_clock_banner.dart';
import 'widgets/safe_image.dart';
import 'models/audit_log_model.dart';
import 'utils/jalali.dart';
import 'models/nutrition_model.dart';
import 'models/attendance_edit_request_model.dart';
import 'models/attendance_archive_model.dart';
import 'teacher/teacher_sections.dart' show PageHost;
import 'pages/toolbox_page.dart';
import 'models/permissions.dart';
import 'services/backend.dart';
import 'models/user_directory.dart';
import 'auth/auth_types.dart';
import 'utils/export_helper.dart';
import 'models/school_classes.dart';
import 'pages/private_message_page.dart';
import 'pages/report_card_pages.dart';

import 'pages/registration_manager_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PermissionService.instance.load();
  await Backend.init();
  runApp(const RoozgarKoodakiApp());
}

// ==========================================
// ورود: شمارهٔ همراه ← کد ورود ← صفحهٔ اصلی نقش
// ==========================================
Widget buildWelcome() => WelcomePage(authenticate: performLogin);

String _roleKeyOf(AppRole r) {
  switch (r) {
    case AppRole.admin:
      return 'admin';
    case AppRole.manager:
      return 'manager';
    case AppRole.deputy:
      return 'deputy';
    case AppRole.teacher:
      return 'teacher';
    case AppRole.parent:
      return 'parent';
  }
}

Widget homeForRole(String roleKey) {
  if (roleKey == 'teacher') {
    return TeacherShell(
      chatBuilder: (_) => const ChatPage(),
      storyBuilder: (_) => ClassStoryPage(userRole: 'teacher'),
      behaviorBuilder: (_) => const TeacherBehaviorSystemPage(),
      toolkitBuilder: (_) => const TeacherToolkitPage(),
    );
  }
  if (roleKey == 'parent') {
    return ParentShell(
      chatBuilder: (_) => const ChatPage(),
      storyBuilder: (_) => ClassStoryPage(userRole: 'parent'),
      progressBuilder: (_) => const ParentChildProfilePage(),
    );
  }
  return Directionality(
    textDirection: TextDirection.rtl,
    child: MainDashboard(role: roleKey),
  );
}

Future<AuthResult> performLogin(String phone, String code, String? demoRole) async {
  String roleKey;
  if (Backend.ready) {
    // ورود واقعی: نقش و هویت از دیتابیس می‌آید
    final err = await Backend.signIn(phone, code);
    if (err != null) {
      await Backend.signOut();
      return AuthResult.error(err);
    }
    roleKey = _roleKeyOf(Session.role);
  } else {
    if (kReleaseMode) {
      return AuthResult.error('اتصال به سرور برقرار نیست و حالت نمایشی در نسخهٔ انتشار غیرفعال است.');
    }
    // حالت نمایشی: نقش از فهرست کاربران (بر اساس شماره) یا انتخاب کاربر
    var role = demoRole ?? 'student';
    UserModel? match;
    try {
      final wanted = Backend.latinDigits(phone);
      for (final u in await UserDirectory.load()) {
        if (u.phone.isNotEmpty && Backend.latinDigits(u.phone) == wanted) {
          match = u;
          break;
        }
      }
    } catch (_) {}
    if (match != null && match.role.isNotEmpty) role = match.role;
    switch (role) {
      case 'teacher':
        Session.signIn(AppRole.teacher);
        break;
      case 'deputy':
        Session.signIn(AppRole.deputy);
        break;
      case 'manager':
        Session.signIn(AppRole.manager);
        break;
      case 'admin':
        Session.signIn(AppRole.admin);
        break;
      default: // parent / student
        Session.signIn(AppRole.parent);
    }
    if (match != null) {
      if (match.name.isNotEmpty) Session.userName = match.name;
      if (role == 'teacher' && match.className.isNotEmpty) Session.className = match.className;
      if (role == 'parent' && match.linkedStudent.isNotEmpty) Session.childName = match.linkedStudent;
    }
    roleKey = role;
  }
  return AuthResult.ok(homeForRole(roleKey));
}

class RoozgarKoodakiApp extends StatelessWidget {
  const RoozgarKoodakiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'روزگار کودکی',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Tahoma',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0288D1),
          primary: const Color(0xFF0288D1),
          secondary: const Color(0xFFFFB300),
          surface: const Color(0xFFE1F5FE),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFE1F5FE),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0288D1),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: buildWelcome(),
    );
  }
}

// ==========================================
// 2. داشبورد اصلی (پشتیبانی از نقش‌های مختلف)
// ==========================================
class MainDashboard extends StatefulWidget {
  final String role;
  const MainDashboard({super.key, required this.role});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    List<Widget> pages = [];

    if (widget.role == 'student') {
      pages = [
        const StudentHomeDashboard(),
        ClassStoryPage(userRole: widget.role),
      ];
      
    } else if (widget.role == 'parent') {
      pages = [
        const ParentChildProfilePage(),
        ClassStoryPage(userRole: widget.role),
        const ChatPage(),
      ];
      
    } else if (widget.role == 'teacher') {
      pages = [
        const TeacherBehaviorSystemPage(),
        ClassStoryPage(userRole: widget.role),
        const TeacherToolkitPage(),
        const ChatPage(),
      ];
      
    } else {
      pages = [
        ManagerOverviewPage(
          role: widget.role == 'deputy'
              ? AppRole.deputy
              : (widget.role == 'admin' ? AppRole.admin : AppRole.manager),
        ),
        ClassStoryPage(userRole: widget.role == 'deputy' ? 'deputy' : 'manager'),
        const ChatPage(),
      ];
      
    }

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
      appBar: AppBar(
        leading: _currentIndex == 0
            ? null
            : BackButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 0;
                  });
                },
              ),
        title: Text(
          widget.role == 'student' ? 'سلام آرتین عزیز! 👋' : (widget.role == 'manager' ? 'پنل مدیریت روزگار کودکی 🏫' : (widget.role == 'deputy' ? 'پنل معاونت 🧑‍💼' : (widget.role == 'admin' ? 'پنل ادمین سیستم 🛡️' : 'روزگار کودکی'))),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new_rounded),
            tooltip: 'خروج',
            onPressed: () async {
              await Backend.signOut();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => buildWelcome()),
              );
            },
          )
        ],
      ),
      body: pages[_currentIndex],
      
      ),
    );
  }
}

// ==========================================
// 3. داشبورد اختصاصی دانش‌آموز
// ==========================================
class StudentHomeDashboard extends StatefulWidget {
  const StudentHomeDashboard({super.key});

  @override
  State<StudentHomeDashboard> createState() => _StudentHomeDashboardState();
}

class _StudentHomeDashboardState extends State<StudentHomeDashboard> {
  int studentPoints = 0;

  @override
  void initState() {
    super.initState();
    PointsService.total(Session.childName).then((v) {
      if (mounted) setState(() => studentPoints = v);
    });
  }

  final List<Map<String, dynamic>> myPortfolios = [];

  void _openUploadAssignmentModal() {
    final TextEditingController titleCtrl = TextEditingController();
    bool hasVoiceAttached = false;
    bool hasImageAttached = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('📸 ارسال تکلیف یا نقاشی جدید (با ویس/عکس)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF01579B))),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    hintText: 'عنوان کاردستی یا نقاشی (مثلاً: نقاشی دایناسور 🦖)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: hasImageAttached ? Colors.green : const Color(0xFF0288D1),
                      ),
                      onPressed: () {
                        setModalState(() {
                          hasImageAttached = true;
                        });
                      },
                      icon: Icon(hasImageAttached ? Icons.check_circle_rounded : Icons.camera_alt_rounded),
                      label: Text(hasImageAttached ? 'تصویر انتخاب شد ✅' : 'انتخاب عکس'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: hasVoiceAttached ? Colors.purple : Colors.purple.shade700,
                      ),
                      onPressed: () {
                        setModalState(() {
                          hasVoiceAttached = true;
                        });
                      },
                      icon: Icon(hasVoiceAttached ? Icons.check_circle_rounded : Icons.mic_rounded),
                      label: Text(hasVoiceAttached ? 'ویس ضبط شد 🎙️' : 'ضبط ویس توضیحات'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0288D1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      if (titleCtrl.text.trim().isNotEmpty) {
                        setState(() {
                          myPortfolios.insert(0, {
                            'title': titleCtrl.text,
                            'color': Colors.pink,
                            'icon': hasVoiceAttached ? Icons.mic_rounded : Icons.star_rounded,
                            'status': 'در انتظار بررسی ⏳',
                            'feedback': 'تکلیف جدید شما دریافت شد.'
                          });
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🎉 تکلیف شما به همراه پیوست‌ها برای مربی ارسال شد!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('ارسال برای مربی', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPortfolioDetailDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(item['title'], style: const TextStyle(color: Color(0xFF01579B), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('وضعیت بررسی: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(item['status'], style: TextStyle(color: item['status'].contains('تایید') ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💬 بازخورد مربی:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
                    const SizedBox(height: 4),
                    Text(item['feedback'], style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('بستن'),
            )
          ],
        ),
      ),
    );
  }

  void _openReportCardDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.military_tech_rounded, color: Color(0xFFFFB300), size: 30),
              SizedBox(width: 8),
              Text('📜 کارنامه توصیفی ماهانه آرتین'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: const [
                Text('ارزشیابی عملکرد ماه مهر و آبان:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                SizedBox(height: 12),
                _ReportSkillRow(skill: 'کار گروهی و هم‌یاری', status: 'عالی و پیشتاز 🌟'),
                _ReportSkillRow(skill: 'انضباط و نظم کلاسی', status: 'خیلی خوب 👍'),
                _ReportSkillRow(skill: 'خلاقیت و هنر', status: 'بسیار خلاق و نوآور 🎨'),
                _ReportSkillRow(skill: 'علاقه به یادگیری و قصه‌خوانی', status: 'عالی و پرانرژی 🚀'),
                _ReportSkillRow(skill: 'مهارت‌های اجتماعی و دوستی', status: 'بسیار مهربان ❤'),
                SizedBox(height: 16),
                Card(
                  color: Color(0xFFFFF9C4),
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('نظر مربی:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
                        SizedBox(height: 4),
                        Text('آرتین عزیز بسیار باهوش، پرتلاش و فعال در کلاس است. حضورش انرژی مثبتی به محیط می‌بخشد.', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('بستن کارنامه'),
            )
          ],
        ),
      ),
    );
  }

  void _openCalendarDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.event_note_rounded, color: Color(0xFF0288D1), size: 30),
              SizedBox(width: 8),
              Text('📅 تقویم رویدادها و برنامه‌های مدرسه'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: const [
                ListTile(
                  leading: Icon(Icons.star_rounded, color: Colors.amber),
                  title: Text('اردوی علمی پارک علم و فناوری 🚀'),
                  subtitle: Text('سه‌شنبه، ساعت ۹ صبح'),
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.palette_rounded, color: Colors.purple),
                  title: Text('جشنواره نقاشی و کاردستی فصلی 🎨'),
                  subtitle: Text('پنج‌‌شنبه هفته آینده'),
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.people_rounded, color: Colors.green),
                  title: Text('جلسه دیدار اولیاء و مربیان 👨‍👩‍👦'),
                  subtitle: Text('یکشنبه ساعت ۱۶:۰۰'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))
          ],
        ),
      ),
    );
  }

  void _openClassQuestsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.shield_rounded, color: Color(0xFFFFB300), size: 30),
              SizedBox(width: 8),
              Text('🛡️ ماموریت تیمی و چالش‌های کلاس'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: const [
                Center(child: SizedBox(height: 120, child: SafeAssetImage('ill_mission.png', fit: BoxFit.contain))),
                SizedBox(height: 8),
                Text('با همکاری بچه‌های کلاس، به امتیاز تیمی دست پیدا کنید!', style: TextStyle(fontSize: 12, color: Colors.black54)),
                SizedBox(height: 12),
                ListTile(
                  leading: Icon(Icons.eco_rounded, color: Colors.green),
                  title: Text('ماموریت هفته پاکیزگی کلاس 🌱'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 6),
                      LinearProgressIndicator(value: 0.8, color: Colors.green, backgroundColor: Colors.grey),
                      SizedBox(height: 4),
                      Text('۸۰٪ تکمیل شده (۱۲۵ از ۱۵۰ ستاره)', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.menu_book_rounded, color: Color(0xFF0288D1)),
                  title: Text('ماموریت کتاب‌خوانی گروهی 📚'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 6),
                      LinearProgressIndicator(value: 0.5, color: Color(0xFF0288D1), backgroundColor: Colors.grey),
                      SizedBox(height: 4),
                      Text('۵۰٪ تکمیل شده (۱۰ از ۲۰ کتاب)', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('بستن'),
            )
          ],
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
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LiveClockBanner(accent: Color(0xFFF59E0B), roleLabel: 'دانش‌آموز'),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.auto_stories_rounded, size: 18),
                    label: const Text('داستان کلاس'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PageHost(title: 'داستان کلاس', child: ClassStoryPage(userRole: 'student'))),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.handyman_rounded, size: 18),
                    label: const Text('جعبه ابزار'),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ToolboxPage())),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFEE58), Color(0xFFFFCA28)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withAlpha(80),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('☀️', style: TextStyle(fontSize: 55)),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'آرتین شجاعی',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFE65100),
                            ),
                          ),
                          Text(
                            'لقب: خورشید پرانرژی کلاس',
                            style: TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0288D1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text('$studentPoints', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          const Text('خورشید', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _openUploadAssignmentModal,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB300),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_rounded, color: Colors.black87),
                            SizedBox(width: 8),
                            Text('ارسال تکلیف 📸', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _openReportCardDialog,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade400,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.military_tech_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 4),
                            Text('کارنامه 📜', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      onTap: _openCalendarDialog,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade600,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_available_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 4),
                            Text('تقویم 📅', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      onTap: _openClassQuestsDialog,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade800,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 4),
                            Text('ماموریت 🛡️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Text(
                '🎨 پوشه کار و تکالیف من (روی هر تکلیف بزنید تا بازخورد مربی را ببینید):',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
              ),
              const SizedBox(height: 12),
              if (myPortfolios.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('هنوز اثری ثبت نشده است.', style: TextStyle(color: Colors.black54)),
                ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.0,
                ),
                itemCount: myPortfolios.length,
                itemBuilder: (context, index) {
                  final item = myPortfolios[index];
                  Color cardColor = (item['color'] as Color).withAlpha(40);
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _openPortfolioDetailDialog(item),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 6, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item['icon'], size: 36, color: const Color(0xFF01579B)),
                          const SizedBox(height: 8),
                          Text(
                            item['title'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF01579B)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item['status'],
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: item['status'].contains('تایید') ? Colors.green : Colors.orange.shade800),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportSkillRow extends StatelessWidget {
  final String skill;
  final String status;
  const _ReportSkillRow({required this.skill, required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(skill, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(status, style: const TextStyle(color: Color(0xFF0288D1), fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

// ==========================================
// 4. سیستم امتیازدهی و رفتارها (مربی)
// ==========================================
class TeacherBehaviorSystemPage extends StatefulWidget {
  const TeacherBehaviorSystemPage({super.key});

  @override
  State<TeacherBehaviorSystemPage> createState() =>
      _TeacherBehaviorSystemPageState();
}

class _TeacherBehaviorSystemPageState
    extends State<TeacherBehaviorSystemPage> {
  List<Map<String, dynamic>> students = [
    {
      'id': '1',
      'name': 'آرتین شجاعی',
      'avatar': '☀️',
      'avatarTitle': 'خورشید پرانرژی',
      'points': 24,
    },
    {
      'id': '2',
      'name': 'سارا محمدی',
      'avatar': '🐰',
      'avatarTitle': 'خرگوش باهوش',
      'points': 18,
    },
    {
      'id': '3',
      'name': 'علی احمدی',
      'avatar': '🦊',
      'avatarTitle': 'روباه دانا',
      'points': 21,
    },
    {
      'id': '4',
      'name': 'مریم کریمی',
      'avatar': '🦔',
      'avatarTitle': 'جوجه‌تیغی مهربان',
      'points': 30,
    },
    {
      'id': '5',
      'name': 'کارن رضایی',
      'avatar': '🦁',
      'avatarTitle': 'شیر شجاع',
      'points': 15,
    },
  ];

  final List<Map<String, dynamic>> positiveSkills = [
    {'title': 'تلاش عالی', 'points': 1, 'icon': Icons.psychology_rounded, 'color': Colors.orange},
    {'title': 'کار گروهی', 'points': 1, 'icon': Icons.groups_rounded, 'color': Colors.blue},
    {'title': 'خلاقیت و هنر', 'points': 1, 'icon': Icons.palette_rounded, 'color': Colors.purple},
    {'title': 'انجام تکلیف', 'points': 1, 'icon': Icons.assignment_turned_in_rounded, 'color': Colors.green},
    {'title': 'احترام و مهربانی', 'points': 1, 'icon': Icons.volunteer_activism_rounded, 'color': Colors.pink},
    {'title': 'نظم و مرتب بودن', 'points': 1, 'icon': Icons.clean_hands_rounded, 'color': Colors.teal},
  ];

  final List<Map<String, dynamic>> needsWorkSkills = [
    {'title': 'بی‌دقتی در کلاس', 'points': -1, 'icon': Icons.warning_amber_rounded, 'color': Colors.amber.shade900},
    {'title': 'عدم انجام تکلیف', 'points': -1, 'icon': Icons.cancel_presentation_rounded, 'color': Colors.red},
    {'title': 'شلوغی در زنگ آرامش', 'points': -1, 'icon': Icons.volume_off_rounded, 'color': Colors.deepOrange},
  ];

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  static const Map<String, List<String>> _avatarByName = {
    'آرتین شجاعی': ['☀️', 'خورشید پرانرژی'],
    'سارا محمدی': ['🐰', 'خرگوش باهوش'],
    'علی احمدی': ['🦊', 'روباه دانا'],
    'مریم کریمی': ['🦔', 'جوجه‌تیغی مهربان'],
    'کارن رضایی': ['🦁', 'شیر شجاع'],
    'نیلا صادقی': ['🐼', 'پاندای آرام'],
    'هلیا موسوی': ['🦋', 'پروانهٔ رنگارنگ'],
    'پارسا کاظمی': ['🐯', 'ببر کوشا'],
  };

  Future<void> _loadPoints() async {
    // فهرست از «مدیریت کاربران» (همان فهرست حضور و غیاب)
    final directory = await StudentDirectory.load();
    final inClass = directory.where((d) => sameClass(d.className, Session.className)).toList();
    if (inClass.isNotEmpty) {
      students = [
        for (int i = 0; i < inClass.length; i++)
          {
            'id': '${i + 1}',
            'name': inClass[i].name,
            'avatar': (_avatarByName[inClass[i].name] ?? const ['🙂', 'ستارهٔ کلاس'])[0],
            'avatarTitle': (_avatarByName[inClass[i].name] ?? const ['🙂', 'ستارهٔ کلاس'])[1],
            'points': 0,
          },
      ];
    }
    for (final st in students) {
      st['points'] = await PointsService.total(st['name'] as String);
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _givePoints(int studentIndex, int pointsToAdd, String skillName) async {
    final ok = await PointsService.add(students[studentIndex]['name'] as String, pointsToAdd, skillName);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شما اجازهٔ ثبت امتیاز ندارید'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() {
      students[studentIndex]['points'] += pointsToAdd;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(pointsToAdd > 0 ? '☀️ ثبت درخشش:' : '⚠️ بازخورد اصلاحی:'),
            const SizedBox(width: 8),
            Text(
              '$skillName برای ${students[studentIndex]['name']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: pointsToAdd > 0 ? Colors.green.shade700 : Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openBehaviorModal(int studentIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: DefaultTabController(
          length: 2,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      students[studentIndex]['avatar'],
                      style: const TextStyle(fontSize: 40),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          students[studentIndex]['name'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'امتیاز فعلی: ${students[studentIndex]['points']} خورشید ☀️',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.face_retouching_natural_rounded),
                      tooltip: 'تغییر آواتار',
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openAvatarSelector(studentIndex);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.red),
                      tooltip: 'بستن',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const TabBar(
                  labelColor: Color(0xFF0288D1),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Color(0xFF0288D1),
                  tabs: [
                    Tab(text: '🌟 درخشش و نقاط مثبت'),
                    Tab(text: '🌱 نیازمند تلاش'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    children: [
                      GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 140,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.95,
                        ),
                        itemCount: positiveSkills.length,
                        itemBuilder: (context, idx) {
                          final skill = positiveSkills[idx];
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pop(ctx);
                              _givePoints(
                                studentIndex,
                                skill['points'],
                                skill['title'],
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: (skill['color'] as Color).withAlpha(25),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: (skill['color'] as Color).withAlpha(80),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    skill['icon'],
                                    color: skill['color'],
                                    size: 32,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    skill['title'],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '+${skill['points']}',
                                    style: TextStyle(
                                      color: skill['color'],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 140,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.95,
                        ),
                        itemCount: needsWorkSkills.length,
                        itemBuilder: (context, idx) {
                          final skill = needsWorkSkills[idx];
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pop(ctx);
                              _givePoints(
                                studentIndex,
                                skill['points'],
                                skill['title'],
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: (skill['color'] as Color).withAlpha(25),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: (skill['color'] as Color).withAlpha(80),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    skill['icon'],
                                    color: skill['color'],
                                    size: 32,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    skill['title'],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${skill['points']}',
                                    style: TextStyle(
                                      color: skill['color'],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300, foregroundColor: Colors.black87),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('انصراف و بستن'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAvatarSelector(int studentIndex) {
    final List<Map<String, String>> availableAvatars = [
      {'emoji': '☀️', 'title': 'خورشید درخشان'},
      {'emoji': '🐰', 'title': 'خرگوش پرانرژی'},
      {'emoji': '🦊', 'title': 'روباه دانا'},
      {'emoji': '🦔', 'title': 'جوجه‌تیغی مهربان'},
      {'emoji': '🦁', 'title': 'شیر شجاع'},
      {'emoji': '🐻', 'title': 'خرس مهربان'},
      {'emoji': '🦋', 'title': 'پروانه زیبا'},
      {'emoji': '🦄', 'title': 'اسب تک‌شاخ'},
      {'emoji': '🚀', 'title': 'فضانورد کوچک'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('انتخاب آواتار جدید برای ${students[studentIndex]['name']}'),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: availableAvatars.length,
              itemBuilder: (context, idx) {
                final av = availableAvatars[idx];
                return InkWell(
                  onTap: () {
                    setState(() {
                      students[studentIndex]['avatar'] = av['emoji'];
                      students[studentIndex]['avatarTitle'] = av['title'];
                    });
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.lightBlue.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(av['emoji']!, style: const TextStyle(fontSize: 32)),
                        const SizedBox(height: 4),
                        Text(
                          av['title']!,
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))
          ],
        ),
      ),
    );
  }

  Future<void> _givePointsToWholeClass() async {
    for (final st in students) {
      final ok = await PointsService.add(st['name'] as String, 1, 'درخشش گروهی');
      if (!ok) break;
      st['points'] += 1;
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🌟 یک خورشید درخشان به تمام دانش‌آموزان کلاس اضافه شد!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'کلاس پیش‌دبستانی آفتاب',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF01579B),
                    ),
                  ),
                  Text(
                    'روی هر کودک کلیک کنید تا امتیاز یا آواتار او را ثبت کنید',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _givePointsToWholeClass,
                icon: const Icon(Icons.stars_rounded),
                label: const Text('امتیاز به کل کلاس'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 190,
              ),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final st = students[index];
                return Card(
                  elevation: 4,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _openBehaviorModal(index),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF9C4),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFFD54F),
                                width: 2,
                              ),
                            ),
                            child: Text(
                              st['avatar'],
                              style: const TextStyle(fontSize: 36),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            st['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            st['avatarTitle'],
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0288D1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '${st['points']} ☀️',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. داستان کلاس (Class Story)
// ==========================================
class ClassStoryPage extends StatefulWidget {
  final String userRole;
  const ClassStoryPage({super.key, required this.userRole});

  @override
  State<ClassStoryPage> createState() => _ClassStoryPageState();
}

class _ClassStoryPageState extends State<ClassStoryPage> {
  final List<Map<String, dynamic>> posts = [
    {
      'id': '1',
      'author': Session.role == AppRole.teacher ? Session.userName : 'مربی کلاس ${Session.className}',
      'time': '۱ ساعت پیش',
      'content': 'امروز نوآموزان گلمون در زنگ سفال‌گری کارهای بسیار خلاقانه‌ای درست کردند! همه عالی بودند. 🎨✨',
      'likes': 12,
      'isLiked': false,
      'comments': ['خدا قوت به مربی مهربان', 'آرتین خیلی از این زنگ تعریف می‌کرد!'],
      'imageColor': 0xFFB3E5FC,
      'type': 'کلاس آفتاب'
    },
    {
      'id': '2',
      'author': 'مدیریت روزگار کودکی',
      'time': 'دیروز',
      'content': 'اولیاء محترم، اردوی علمی/تفریحی هفته آینده روز سه‌شنبه برگزار می‌شود. لطفا رضایت‌‌نامه‌ها را تا یکشنبه تحویل دهید.',
      'likes': 28,
      'isLiked': true,
      'comments': ['ممنون از برنامه‌ریزی عالیتون'],
      'imageColor': 0xFFFFF9C4,
      'type': 'اطلاعیه عمومی'
    },
  ];

  final TextEditingController _postTextController = TextEditingController();

  void _addNewPost() {
    if (_postTextController.text.trim().isEmpty) return;

    setState(() {
      posts.insert(0, {
        'id': DateTime.now().toString(),
        'author': widget.userRole == 'teacher' ? Session.userName : 'مدیریت روزگار کودکی',
        'time': 'همین الان',
        'content': _postTextController.text,
        'likes': 0,
        'isLiked': false,
        'comments': [],
        'imageColor': 0xFFE1BEE7,
        'type': widget.userRole == 'teacher' ? 'کلاس آفتاب' : 'اطلاعیه عمومی'
      });
      _postTextController.clear();
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 پست جدید با موفقیت در داستان کلاس منتشر شد!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _openCreatePostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '📸 انتشار داستان جدید در کلاس/مدرسه',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _postTextController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'توضیحات فعالیت امروز، عکس یا اطلاعیه خود را بنویسید...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('افزودن عکس به‌زودی فعال می‌شود')),
                    ),
                    icon: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF0288D1)),
                    label: const Text('افزودن عکس'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('پیام صوتی به‌زودی فعال می‌شود')),
                    ),
                    icon: const Icon(Icons.mic_rounded, color: Colors.purple),
                    label: const Text('صوت/پیام صوتی'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0288D1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _addNewPost,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('انتشار در داستان کلاس', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: (widget.userRole == 'teacher' || widget.userRole == 'manager')
          ? FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFFB300),
        foregroundColor: Colors.black87,
        onPressed: _openCreatePostModal,
        icon: const Icon(Icons.add_photo_alternate_rounded),
        label: const Text('پست جدید', style: TextStyle(fontWeight: FontWeight.bold)),
      )
          : null,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF0288D1),
                            child: Icon(Icons.school_rounded, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(post['author'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Row(
                                children: [
                                  Text(post['time'], style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.lightBlue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(post['type'], style: const TextStyle(fontSize: 10, color: Color(0xFF0288D1))),
                                  )
                                ],
                              ),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(post['content'], style: const TextStyle(fontSize: 15, height: 1.4)),
                      const SizedBox(height: 12),
                      Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Color(post['imageColor']),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_library_rounded, size: 50, color: Color(0xFF0288D1)),
                            SizedBox(height: 6),
                            Text('تصویر/ویدیو فعالیت نوآموزان', style: TextStyle(color: Colors.black54, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              post['isLiked'] ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: post['isLiked'] ? Colors.red : Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                post['isLiked'] = !post['isLiked'];
                                post['likes'] += post['isLiked'] ? 1 : -1;
                              });
                            },
                          ),
                          Text('${post['likes']} پسندیدند'),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _openCommentsDialog(post),
                            icon: const Icon(Icons.mode_comment_outlined),
                            label: Text('${post['comments'].length} دیدگاه'),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openCommentsDialog(Map<String, dynamic> post) {
    final TextEditingController commentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('💬 دیدگاه‌های اولیاء و مربیان'),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: post['comments'].isEmpty
                        ? const Center(child: Text('هنوز دیدگاهی ثبت نشده است'))
                        : ListView.builder(
                      shrinkWrap: true,
                      itemCount: post['comments'].length,
                      itemBuilder: (c, i) => ListTile(
                        leading: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                        title: Text(post['comments'][i], style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentCtrl,
                          decoration: const InputDecoration(
                            hintText: 'ارسال نظر...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: Color(0xFF0288D1)),
                        onPressed: () {
                          if (commentCtrl.text.trim().isNotEmpty) {
                            setState(() {
                              post['comments'].add(commentCtrl.text);
                            });
                            setDialogState(() {});
                            commentCtrl.clear();
                          }
                        },
                      )
                    ],
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 6. جعبه ابزار معلم و حضور و غیاب هوشمند
// ==========================================
class TeacherToolkitPage extends StatefulWidget {
  const TeacherToolkitPage({super.key});

  @override
  State<TeacherToolkitPage> createState() => _TeacherToolkitPageState();
}

class _TeacherToolkitPageState extends State<TeacherToolkitPage> {
  final List<String> studentList = [
    'آرتین شجاعی',
    'سارا محمدی',
    'علی احمدی',
    'مریم کریمی',
    'کارن رضایی'
  ];

  void _openRandomPicker() {
    String selectedStudent = '';
    bool isSpinning = false;
    Timer? spinTimer; // برای لغو تایمر هنگام بسته‌شدن دیالوگ

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.casino_rounded, color: Color(0xFF0288D1)),
                    SizedBox(width: 8),
                    Text('انتخاب‌گر تصادفی دانش‌آموز'),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      selectedStudent.isEmpty ? 'روی دکمه قرعه‌کشی کلیک کنید' : selectedStudent,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF01579B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB300),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: isSpinning
                      ? null
                      : () {
                    setDialogState(() {
                      isSpinning = true;
                    });
                    int spins = 0;
                    spinTimer?.cancel();
                    spinTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
                      if (!ctx.mounted) {
                        t.cancel();
                        return;
                      }
                      spins++;
                      setDialogState(() {
                        selectedStudent = studentList[Random().nextInt(studentList.length)];
                      });
                      if (spins > 15) {
                        t.cancel();
                        setDialogState(() {
                          isSpinning = false;
                        });
                      }
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('چرخاندن گردونه شانس 🎯', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))
            ],
          ),
        ),
      ),
    ).then((_) => spinTimer?.cancel());
  }

  void _openTimerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const Directionality(
        textDirection: TextDirection.rtl,
        child: ClassTimerDialog(),
      ),
    );
  }

  void _openGroupMaker() {
    List<List<String>> groups = [];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('👥 گروه‌‌بندی تصادفی دانش‌آموزان'),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white),
                    onPressed: () {
                      List<String> shuffled = List.from(studentList)..shuffle();
                      groups = [
                        [shuffled[0], shuffled[1]],
                        [shuffled[2], shuffled[3], if (shuffled.length > 4) shuffled[4]],
                      ];
                      setDialogState(() {});
                    },
                    icon: const Icon(Icons.groups_rounded),
                    label: const Text('ساخت گروه‌های ۲ و ۳ نفره'),
                  ),
                  const SizedBox(height: 16),
                  if (groups.isNotEmpty)
                    Column(
                      children: groups.asMap().entries.map((e) {
                        return Card(
                          color: Colors.amber.shade50,
                          child: ListTile(
                            title: Text('گروه ${e.key + 1}:', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(e.value.join(' - ')),
                          ),
                        );
                      }).toList(),
                    )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🧰 ابزارهای کلاس:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
              ),
              const SizedBox(height: 16),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 130,
                ),
                children: [
                  _buildToolCard('قرعه‌کشی شانس', 'انتخاب تصادفی دانش‌آموز', Icons.casino_rounded, Colors.purple, _openRandomPicker),
                  _buildToolCard('تایمر کلاسی', 'زمان‌بندی فعالیت‌ها', Icons.timer_rounded, Colors.orange, _openTimerDialog),
                  _buildToolCard('گروه‌بندی بچه‌ها', 'ساخت گروه تصادفی', Icons.groups_rounded, Colors.teal, _openGroupMaker),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ویجت تایمر کلاسی
// ==========================================
class ClassTimerDialog extends StatefulWidget {
  const ClassTimerDialog({super.key});

  @override
  State<ClassTimerDialog> createState() => _ClassTimerDialogState();
}

class _ClassTimerDialogState extends State<ClassTimerDialog> {
  int _seconds = 60;
  Timer? _timer;
  bool _isRunning = false;

  void _startTimer() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds > 0) {
        setState(() {
          _seconds--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _isRunning = false;
        });
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _setTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _seconds = seconds;
      _isRunning = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.timer_rounded, color: Color(0xFF0288D1)),
              SizedBox(width: 8),
              Text('⏱️ تایمر و معکوس‌شمار کلاسی'),
            ],
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE1F5FE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 55,
                fontWeight: FontWeight.bold,
                color: Color(0xFF01579B),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRunning ? Colors.grey : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isRunning ? null : _startTimer,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('شروع'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _pauseTimer,
                icon: const Icon(Icons.pause_rounded),
                label: const Text('توقف'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton(onPressed: () => _setTimer(60), child: const Text('۱ دقیقه')),
              OutlinedButton(onPressed: () => _setTimer(300), child: const Text('۵ دقیقه')),
              OutlinedButton(onPressed: () => _setTimer(600), child: const Text('۱۰ دقیقه')),
            ],
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن'))
      ],
    );
  }
}

// ==========================================
// 8. پروفایل و گزارش‌های تحلیلی اولیاء
// ==========================================
class ParentChildProfilePage extends StatefulWidget {
  const ParentChildProfilePage({super.key});

  @override
  State<ParentChildProfilePage> createState() => _ParentChildProfilePageState();
}

class _ParentChildProfilePageState extends State<ParentChildProfilePage> {
  int _points = 0;
  List<MapEntry<String, int>> _weekly = [];
  List<PointEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await PointsService.total(Session.childName);
    final w = await PointsService.lastDays(Session.childName);
    final e = await PointsService.eventsFor(Session.childName, limit: 6);
    if (!mounted) return;
    setState(() {
      _points = p;
      _weekly = w;
      _events = e;
    });
  }

  String _when(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final j = JalaliDate.fromDateTime(d);
    return '${j.weekdayName} ${j.formatted} - ${faDigits(d.hour.toString().padLeft(2, '0'))}:${faDigits(d.minute.toString().padLeft(2, '0'))}';
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> weeklyData = [
      for (final e in _weekly) {'day': e.key, 'score': e.value},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                color: const Color(0xFFFFF9C4),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 35,
                        backgroundColor: Color(0xFFFFE082),
                        child: Text('☀️', style: TextStyle(fontSize: 40)),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Session.childName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('کلاس: ${Session.className}'),
                          const Text('آواتار: خورشید پرانرژی ☀️', style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFF0288D1), borderRadius: BorderRadius.circular(20)),
                        child: Column(
                          children: [
                            Text(faDigits(_points), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            const Text('خورشید', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('📊 گزارش پیشرفت و تحلیل هفتگی رفتار:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF01579B))),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('روند امتیازهای این هفته', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(
                            _weekly.every((e) => e.value >= 0) ? 'روند مثبت 🌟' : 'نیازمند توجه',
                            style: TextStyle(
                              color: _weekly.every((e) => e.value >= 0) ? Colors.green : Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: weeklyData.map((item) {
                          double heightFactor = ((item['score'] as int).clamp(0, 12)) * 12.0 + 4;
                          return Column(
                            children: [
                              Text('${(item['score'] as int) > 0 ? '+' : ''}${item['score']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0288D1))),
                              const SizedBox(height: 6),
                              Container(
                                width: 30,
                                height: heightFactor,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0288D1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(item['day'], style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('🌟 آخرین درخشش‌ها در کلاس:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF01579B))),
              const SizedBox(height: 10),
              if (_events.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('هنوز امتیازی ثبت نشده است.', style: TextStyle(color: Colors.black54)),
                ),
              for (final e in _events)
                _buildPointItem(
                  e.skill,
                  '${e.delta > 0 ? '+' : ''}${faDigits(e.delta)}',
                  _when(e.ts),
                  e.delta > 0 ? Icons.star_rounded : Icons.info_outline_rounded,
                  e.delta > 0 ? Colors.green : Colors.orange,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPointItem(String title, String points, String time, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withAlpha(40), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(time),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Color(0xFFFFF176), shape: BoxShape.circle),
          child: Text(points, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF57F17))),
        ),
      ),
    );
  }
}

// ==========================================
// 9. پیام‌رسان واقعی و تعاملی
// ==========================================
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool _managerUnlocked = false;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool get _isManagerRole =>
      Session.role == AppRole.manager || Session.role == AppRole.deputy || Session.role == AppRole.admin;

  @override
  void dispose() {
    _reasonController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> _messages = [
    {
      'sender': Session.role == AppRole.teacher ? Session.userName : 'مربی کلاس ${Session.className}',
      'text': 'سلام وقتتون بخیر، آرتین امروز در زنگ کاردستی بسیار عالی و خلاقانه عمل کرد. 🎨',
      'time': '۱۰:۱۵',
      'isMe': false,
      'type': 'text',
    },
    {
      'sender': 'شما (والدین)',
      'text': 'سلام، خیلی ممنون از زحمات شما و انرژی مثبتی که به بچه‌ها می‌دید.',
      'time': '۱۰:۲۰',
      'isMe': true,
      'type': 'text',
    },
  ];

  void _sendMessage({String type = 'text', String content = ''}) {
    String textToSend = content.isEmpty ? _messageController.text.trim() : content;
    if (textToSend.isEmpty) return;

    setState(() {
      _messages.add({
        'sender': Session.role == AppRole.teacher ? Session.userName : 'شما (والدین)',
        'text': textToSend,
        'time': 'همین الان',
        'isMe': true,
        'type': type,
      });
      if (type == 'text') {
        _messageController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isManagerRole && !_managerUnlocked) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('گفتگوی خصوصی معلم و ولی'),
          backgroundColor: const Color(0xFF01579B),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_person_rounded, size: 64, color: Color(0xFF01579B)),
                    const SizedBox(height: 16),
                    const Text(
                      'حریم خصوصی گفتگوها',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'گفتگوی مربی و ولی کاملاً محرمانه است. طبق قوانین مجموعه، ورود مدیریت به گفتگوهای خصوصی مستلزم ثبت «علت نظارت» و ثبت در گزارش تغییرات (Audit Log) می‌باشد.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _reasonController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'دلیل ورود و علت نظارت (الزامی)',
                        hintText: 'مثلاً: بررسی شکایت ولی درباره فعالیت کلاسی',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF01579B),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.verified_user_rounded, color: Colors.white),
                        label: const Text('ثبت دلیل و بازکردن گفتگو', style: TextStyle(color: Colors.white, fontSize: 15)),
                        onPressed: () async {
                          final reason = _reasonController.text.trim();
                          if (reason.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('لطفاً دلیل ورود را ثبت کنید'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          await AuditLogService.log(
                            actor: Session.userName,
                            role: Session.role.label,
                            action: 'دسترسی به پیام‌های خصوصی معلم و ولی',
                            details: 'علت نظارت: $reason',
                          );

                          if (!context.mounted) return;
                          setState(() {
                            _managerUnlocked = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('دسترسی صادر شد و در گزارش تغییرات سیستم ثبت گردید'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF0288D1),
                      child: Icon(Icons.person_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Session.role == AppRole.teacher ? Session.userName : 'مربی کلاس ${Session.className}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text('🟢 آنلاین - گفتگو امن اولیاء و مربی', style: TextStyle(fontSize: 11, color: Colors.green)),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    bool isMe = msg['isMe'];
                    String type = msg['type'] ?? 'text';

                    return Align(
                      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFFE1F5FE) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(msg['sender'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isMe ? const Color(0xFF01579B) : Colors.orange.shade800)),
                            const SizedBox(height: 6),
                            if (type == 'text')
                              Text(msg['text'], style: const TextStyle(fontSize: 14, height: 1.3))
                            else if (type == 'voice')
                              Row(
                                children: [
                                  const Icon(Icons.play_circle_filled_rounded, color: Color(0xFF0288D1), size: 32),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(msg['text'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        const Text('0:15 ثانیه - ویس صوتی', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else if (type == 'image')
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 140,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.lightBlue.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.image_rounded, size: 45, color: Color(0xFF0288D1)),
                                          SizedBox(height: 4),
                                          Text('تصویر ارسال‌شده از گالری', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(msg['text'], style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Text(msg['time'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.mic_rounded, color: Color(0xFF0288D1)),
                      tooltip: 'ارسال ویس صوتی',
                      onPressed: () => _sendMessage(type: 'voice', content: '🎙️ پیام صوتی جدید'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.image_rounded, color: Color(0xFF0288D1)),
                      tooltip: 'ارسال تصویر',
                      onPressed: () => _sendMessage(type: 'image', content: '📷 عکس تکالیف آرتین'),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'پیام خود را به مربی بنویسید...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        onSubmitted: (_) => _sendMessage(type: 'text'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: const Color(0xFF0288D1),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        onPressed: () => _sendMessage(type: 'text'),
                      ),
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
}

// ==========================================
// 10. داشبورد مدیریت و گزارش‌های جامع
// ==========================================
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
                        const SizedBox(
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
                    leading: const SizedBox(
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