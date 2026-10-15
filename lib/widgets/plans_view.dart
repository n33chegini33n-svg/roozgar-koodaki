import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../parent/parent_sections.dart';
import '../models/educational_plan_model.dart';
import '../models/permissions.dart';
import '../models/school_classes.dart';

/// فهرست برنامه‌های آموزشی که این نقش مجاز به دیدنشان است (بر اساس دامنهٔ دسترسی)
class PlansFeed extends StatefulWidget {
  final AppRole role;
  const PlansFeed({super.key, required this.role});

  @override
  State<PlansFeed> createState() => _PlansFeedState();
}

class _PlansFeedState extends State<PlansFeed> {
  bool _loading = true;
  List<EducationalPlan> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final scope = PermissionService.instance.scopeOf(widget.role, Perm.viewPlans);
    final all = await EducationalPlanService.getAll();
    final visible = scope == Scope.all
        ? all
        : (scope == Scope.own ? all.where((p) => sameClass(p.className, Session.className)).toList() : <EducationalPlan>[]);
    if (!mounted) return;
    setState(() {
      _items = visible.take(50).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
    }
    if (!PermissionService.instance.can(widget.role, Perm.viewPlans)) {
      return softCard(
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: Text('دسترسی به این بخش برای شما فعال نیست.', style: TextStyle(color: AppColors.textGrey))),
        ),
      );
    }
    if (_items.isEmpty) {
      return softCard(
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: Text('هنوز برنامهٔ آموزشی ثبت نشده است.', style: TextStyle(color: AppColors.textGrey))),
        ),
      );
    }
    return Column(
      children: [
        for (final p in _items)
          softCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE1F5FE),
                  child: Icon(Icons.menu_book_rounded, color: AppColors.navy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy)),
                      if (p.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(p.description, style: const TextStyle(color: AppColors.textGrey, height: 1.5)),
                      ],
                      const SizedBox(height: 6),
                      Text('${p.className} • ${p.date}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// صفحهٔ برنامه‌های آموزشی (برای معلم و ولی)
class PlansPage extends StatelessWidget {
  final AppRole role;
  const PlansPage({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'برنامه‌های آموزشی',
      image: 'ill_educational_planning.png',
      child: PlansFeed(role: role),
    );
  }
}
