import '../widgets/illustration_banner.dart';
import 'package:flutter/material.dart';
import '../models/educational_plan_model.dart';
import '../models/nutrition_model.dart';
import '../models/permissions.dart';
import '../utils/jalali.dart';

/// برنامه‌ریزی آموزشی: ثبت و مشاهدهٔ برنامه‌های آموزشی هر کلاس
class EducationalPlanningPage extends StatefulWidget {
  const EducationalPlanningPage({super.key});

  @override
  State<EducationalPlanningPage> createState() => _EducationalPlanningPageState();
}

class _EducationalPlanningPageState extends State<EducationalPlanningPage> {
  static const Color _navy = Color(0xFF01579B);
  bool _loading = true;
  List<EducationalPlan> _plans = [];
  List<String> _classes = [];

  bool get _canEdit => PermissionService.instance.can(Session.role, Perm.managePlanning);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plans = await EducationalPlanService.getAll();
    final students = await StudentDirectory.load();
    final classes = students.map((s) => s.className).toSet().toList()..sort();
    if (!mounted) return;
    setState(() {
      _plans = List.of(plans);
      _classes = classes.isEmpty ? [Session.className] : classes;
      _loading = false;
    });
  }

  Future<void> _showAddDialog() async {
    if (!_canEdit) return;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedClass = _classes.contains(Session.className) ? Session.className : _classes.first;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('افزودن برنامهٔ آموزشی'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedClass,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'کلاس', border: OutlineInputBorder(), isDense: true),
                    items: [for (final c in _classes) DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))],
                    onChanged: (v) => setD(() => selectedClass = v ?? selectedClass),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'عنوان برنامه', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'توضیحات', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
              FilledButton(
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('ثبت'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;

    try {
      await EducationalPlanService.add(
      EducationalPlan(
        id: 'PLN-${DateTime.now().millisecondsSinceEpoch}',
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        className: selectedClass,
        date: JalaliDate.now().formatted,
        createdBy: Session.userName,
      ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
      return;
    }
    await _load();
  }

  Future<void> _confirmDelete(EducationalPlan p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف برنامه؟'),
          content: Text(p.title),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await EducationalPlanService.remove(p.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Text('برنامه‌ریزی آموزشی'),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
        ),
        floatingActionButton: _canEdit && !_loading
            ? FloatingActionButton.extended(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('برنامهٔ جدید'),
              )
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 14, 14, 0),
                    child: IllustrationBanner(
                      image: 'ill_educational_planning.png',
                      title: 'برنامه‌ریزی آموزشی',
                      subtitle: 'برنامه‌های ثبت‌شده برای مربیان و والدین همان کلاس نمایش داده می‌شود.',
                      tint: Color(0xFFEDE7F6),
                    ),
                  ),
                  Expanded(
                    child: _plans.isEmpty
                        ? const Center(child: Text('هنوز برنامه‌ای ثبت نشده است.', style: TextStyle(color: Colors.grey)))
                        : _planList(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _planList() {
    return ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _plans.length,
                    itemBuilder: (_, i) {
                      final p = _plans[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE1F5FE),
                            child: Icon(Icons.menu_book_rounded, color: _navy),
                          ),
                          title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${p.className} • ${p.date}${p.description.isEmpty ? '' : '\n${p.description}'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          isThreeLine: p.description.isNotEmpty,
                          trailing: _canEdit
                              ? IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _confirmDelete(p))
                              : null,
                        ),
                      );
                    },
    );
  }
}
