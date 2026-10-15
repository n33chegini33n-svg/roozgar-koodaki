import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../parent/parent_sections.dart';
import '../models/nutrition_model.dart';
import '../models/permissions.dart';
import '../utils/jalali.dart';

Color severityColor(String s) {
  if (s == 'شدید') return const Color(0xFFE5484D);
  if (s == 'متوسط') return const Color(0xFFF59E0B);
  return const Color(0xFF2E9E6B);
}

/// منوی هفتگی (فقط‌خواندنی)؛ امروز پررنگ می‌شود
class WeeklyMenuView extends StatefulWidget {
  const WeeklyMenuView({super.key});

  @override
  State<WeeklyMenuView> createState() => _WeeklyMenuViewState();
}

class _WeeklyMenuViewState extends State<WeeklyMenuView> {
  Map<String, Map<String, String>>? _menu;

  @override
  void initState() {
    super.initState();
    NutritionService.getMenu().then((m) {
      if (mounted) setState(() => _menu = m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final menu = _menu;
    if (menu == null) {
      return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
    }
    final today = JalaliDate.now().weekdayName;
    final hasAny = menu.values.any((d) => d.values.any((v) => v.trim().isNotEmpty));
    if (!hasAny) {
      return softCard(
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: Text('منوی این هفته هنوز ثبت نشده است.', style: TextStyle(color: AppColors.textGrey))),
        ),
      );
    }
    return Column(
      children: [
        for (final day in kMenuDays)
          softCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(day, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    if (day == today) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFE1F5FE), borderRadius: BorderRadius.circular(10)),
                        child: const Text('امروز', style: TextStyle(fontSize: 11, color: AppColors.navy)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                for (final meal in kMeals)
                  if ((menu[day]?[meal] ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('$meal: ${menu[day]![meal]}', style: const TextStyle(height: 1.5)),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}

/// کارت‌های حساسیت غذایی
class AllergyCards extends StatelessWidget {
  final List<AllergyRecord> items;
  final bool showStudentName;
  const AllergyCards({super.key, required this.items, this.showStudentName = true});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return softCard(
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: Text('حساسیت یا محدودیت غذایی ثبت نشده است.', style: TextStyle(color: AppColors.textGrey))),
        ),
      );
    }
    return Column(
      children: [
        for (final a in items)
          softCard(
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 44,
                  decoration: BoxDecoration(color: severityColor(a.severity), borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(showStudentName ? '${a.studentName} • ${a.allergen}' : a.allergen,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (a.notes.isNotEmpty)
                        Text(a.notes, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                Text(a.severity, style: TextStyle(fontWeight: FontWeight.bold, color: severityColor(a.severity))),
              ],
            ),
          ),
      ],
    );
  }
}

/// حساسیت‌هایی که این نقش مجاز به دیدنشان است (بر اساس دامنهٔ دسترسی)
class AllergySection extends StatefulWidget {
  final AppRole role;
  final String title;
  final bool showStudentName;
  const AllergySection({super.key, required this.role, required this.title, this.showStudentName = true});

  @override
  State<AllergySection> createState() => _AllergySectionState();
}

class _AllergySectionState extends State<AllergySection> {
  List<AllergyRecord>? _items;

  @override
  void initState() {
    super.initState();
    NutritionService.visibleTo(widget.role).then((l) {
      if (mounted) setState(() => _items = l);
    });
  }

  @override
  Widget build(BuildContext context) {
    // بدون دسترسی، حتی عنوان این بخش هم نشان داده نمی‌شود
    if (!PermissionService.instance.can(widget.role, Perm.viewHealthRecords)) return const SizedBox.shrink();
    final items = _items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 8),
        if (items == null)
          const Center(child: CircularProgressIndicator())
        else
          AllergyCards(items: items, showStudentName: widget.showStudentName),
      ],
    );
  }
}

/// صفحهٔ «منوی غذایی» برای ولی: منو + حساسیت فرزند خودش
class ParentNutritionPage extends StatelessWidget {
  const ParentNutritionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionScaffold(
      title: 'منوی غذایی',
      image: 'ill_menu.png',
      child: Column(
        children: [
          WeeklyMenuView(),
          AllergySection(role: AppRole.parent, title: 'حساسیت‌های ثبت‌شدهٔ فرزند شما', showStudentName: false),
        ],
      ),
    );
  }
}

/// صفحهٔ «منو و حساسیت‌ها» برای معلم: منو + حساسیت‌های کلاس خودش
class TeacherNutritionPage extends StatelessWidget {
  const TeacherNutritionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionScaffold(
      title: 'منو و حساسیت‌های کلاس',
      image: 'ill_nutrition_health.png',
      child: Column(
        children: [
          WeeklyMenuView(),
          AllergySection(role: AppRole.teacher, title: 'حساسیت‌های غذایی نوآموزان کلاس'),
        ],
      ),
    );
  }
}
