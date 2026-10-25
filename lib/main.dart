import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'auth/welcome_page.dart';
import 'parent/parent_shell.dart';
import 'teacher/teacher_shell.dart';
import 'models/points_model.dart';
import 'utils/jalali.dart';
import 'models/permissions.dart';
import 'services/backend.dart';
import 'services/demo_auth_policy.dart';
import 'models/user_directory.dart';
import 'auth/auth_types.dart';
import 'pages/manager_overview_page.dart';
import 'pages/student_home_dashboard.dart';
import 'pages/teacher_behavior_system_page.dart';
import 'pages/class_story_page.dart';
import 'pages/chat_page.dart';
import 'pages/teacher_toolkit_page.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Backend.init();
  await PermissionService.instance.load(
    allowLocalOverrides: DemoAuthPolicy.isAllowed(
      isDebugBuild: kDebugMode,
      backendConfigured: Backend.configured,
      backendReady: Backend.ready,
    ),
  );
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
    case AppRole.student:
      return 'student';
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
  Session.reset();
  final demoAllowed = DemoAuthPolicy.isAllowed(
    isDebugBuild: kDebugMode,
    backendConfigured: Backend.configured,
    backendReady: Backend.ready,
  );
  if (!Backend.ready && !demoAllowed) {
    return AuthResult.error('ورود واقعی در دسترس نیست. اتصال سرور را بررسی کنید و دوباره تلاش کنید.');
  }

  String roleKey;
  if (Backend.ready) {
    // ورود واقعی: نقش و هویت از دیتابیس می‌آید
    final err = await Backend.signIn(phone, code);
    if (err != null) {
      await Backend.signOut();
      Session.reset();
      return AuthResult.error(err);
    }
    roleKey = _roleKeyOf(Session.role);
  } else {
    // حالت نمایشی: نقش از فهرست کاربران (بر اساس شماره) یا انتخاب کاربر
    String? role = DemoAuthPolicy.validRole(demoRole ?? 'student');
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
    if (match != null && match.role.isNotEmpty) {
      role = DemoAuthPolicy.validRole(match.role);
    }
    if (role == null) {
      return AuthResult.error('نقش انتخاب‌شده معتبر نیست.');
    }
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
      case 'student':
        Session.signIn(AppRole.student);
        break;
      default: // parent
        Session.signIn(AppRole.parent);
    }
    if (match != null) {
      if (match.name.isNotEmpty) Session.userName = match.name;
      if (role == 'student' && match.name.isNotEmpty) Session.childName = match.name;
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
              if (!context.mounted) return;
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
