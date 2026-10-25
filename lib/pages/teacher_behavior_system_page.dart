import 'package:flutter/material.dart';

import '../models/permissions.dart'; // Session
import '../models/points_model.dart'; // PointsService
import '../models/nutrition_model.dart'; // StudentDirectory
import '../models/school_classes.dart'; // sameClass

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
