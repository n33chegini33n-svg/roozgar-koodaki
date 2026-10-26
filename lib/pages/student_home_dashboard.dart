import 'package:flutter/material.dart';

import '../models/permissions.dart'; // Session, AppRole
import '../models/points_model.dart'; // PointsService
import '../widgets/safe_image.dart';
import '../widgets/live_clock_banner.dart';
import '../teacher/teacher_sections.dart' show PageHost;
import 'toolbox_page.dart';
import 'video_meetings_page.dart';
import 'evaluation_feedback_page.dart';

// ClassStoryPage هنوز در main.dart است
import 'class_story_page.dart';

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
              LiveClockBanner(accent: Color(0xFFF59E0B), roleLabel: 'دانش‌آموز'),
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
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ToolboxPage())),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.video_call_rounded, size: 18),
                    label: const Text('کلاس تصویری'),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoMeetingsPage(role: AppRole.student))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EvaluationFeedbackPage()),
                  ),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF8E1), Color(0xFFFFE082)],
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFCA28), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withAlpha(45),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(Icons.star_rounded, color: Color(0xFFFFA000)),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'نظرسنجی و ستاره به مربی و مدرسه 🌟',
                                style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6D4C00)),
                              ),
                              SizedBox(height: 3),
                              Text('نظرت را دربارهٔ کلاس و مدرسه بگو', style: TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_left_rounded, color: Color(0xFF8D6E00)),
                      ],
                    ),
                  ),
                ),
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
