import '../widgets/illustration_banner.dart';
import 'package:flutter/material.dart';
import '../models/nutrition_model.dart';
import '../models/permissions.dart';
import '../widgets/nutrition_views.dart';

/// مدیریت تغذیه و سلامت: منوی هفتگی + حساسیت‌های غذایی
class ManagerNutritionPage extends StatefulWidget {
  const ManagerNutritionPage({super.key});

  @override
  State<ManagerNutritionPage> createState() => _ManagerNutritionPageState();
}

class _ManagerNutritionPageState extends State<ManagerNutritionPage> {
  static const Color _navy = Color(0xFF01579B);

  bool _loading = true;
  bool _saving = false;
  // کنترلر هر وعده: کلید = «روز|وعده»
  final Map<String, TextEditingController> _ctrls = {};
  List<AllergyRecord> _allergies = [];

  bool get _canEdit => PermissionService.instance.can(Session.role, Perm.manageNutrition);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final menu = await NutritionService.getMenu();
    final allergies = await NutritionService.visibleTo(Session.role);
    if (!mounted) return;
    setState(() {
      for (final d in kMenuDays) {
        for (final m in kMeals) {
          _ctrls['$d|$m'] = TextEditingController(text: menu[d]?[m] ?? '');
        }
      }
      _allergies = List.of(allergies);
      _loading = false;
    });
  }

  void _snack(String msg, [Color? color]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _saveMenu() async {
    if (!_canEdit || _saving) return;
    setState(() => _saving = true);
    final menu = {
      for (final d in kMenuDays) d: {for (final m in kMeals) m: _ctrls['$d|$m']!.text.trim()},
    };
    await NutritionService.saveMenu(menu);
    if (!mounted) return;
    setState(() => _saving = false);
    _snack('✅ منوی هفتگی ذخیره شد و برای والدین و مربیان نمایش داده می‌شود', Colors.green);
  }

  Future<void> _addAllergyDialog() async {
    final students = await StudentDirectory.load();
    if (!mounted || students.isEmpty) return;
    StudentInfo selected = students.first;
    String severity = 'متوسط';
    final allergenCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('ثبت حساسیت غذایی'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<StudentInfo>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'نوآموز', border: OutlineInputBorder(), isDense: true),
                    items: [for (final s in students) DropdownMenuItem(value: s, child: Text('${s.name} • ${s.className}', overflow: TextOverflow.ellipsis))],
                    onChanged: (v) => setD(() => selected = v ?? selected),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: allergenCtrl,
                    decoration: const InputDecoration(labelText: 'مادهٔ حساسیت‌زا (مثلاً بادام‌زمینی)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in kSeverities)
                        ChoiceChip(
                          label: Text(s),
                          selected: severity == s,
                          selectedColor: severityColor(s).withValues(alpha: 0.25),
                          onSelected: (_) => setD(() => severity = s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
              FilledButton(
                onPressed: () {
                  if (allergenCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('ثبت'),
              ),
            ],
          ),
        ),
      ),
    );

    final allergen = allergenCtrl.text.trim();
    final notes = notesCtrl.text.trim();
    if (ok != true) return;

    try {
      await NutritionService.addAllergy(
      AllergyRecord(
        id: 'ALG-${DateTime.now().millisecondsSinceEpoch}',
        studentId: selected.id,
        studentName: selected.name,
        className: selected.className,
        allergen: allergen,
        severity: severity,
        notes: notes,
      ),
      );
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''), Colors.red);
      return;
    }
    final fresh = await NutritionService.visibleTo(Session.role);
    if (!mounted) return;
    setState(() => _allergies = List.of(fresh));
    _snack('✅ حساسیت ثبت شد', Colors.green);
  }

  Future<void> _confirmDelete(AllergyRecord a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف حساسیت؟'),
          content: Text('${a.studentName} • ${a.allergen}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await NutritionService.removeAllergy(a.id);
    final fresh = await NutritionService.visibleTo(Session.role);
    if (!mounted) return;
    setState(() => _allergies = List.of(fresh));
  }

  Widget _menuTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const IllustrationBanner(
          image: 'ill_menu.png',
          title: 'منوی هفتگی',
          subtitle: 'منو برای والدین و مربیان نمایش داده می‌شود.',
          tint: Color(0xFFE8F5E9),
        ),
        for (final d in kMenuDays)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d, style: const TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 15)),
                  const SizedBox(height: 8),
                  for (final m in kMeals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: _ctrls['$d|$m'],
                        enabled: _canEdit,
                        decoration: InputDecoration(labelText: m, border: const OutlineInputBorder(), isDense: true),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (_canEdit)
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _saving ? null : _saveMenu,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'در حال ذخیره...' : 'ذخیرهٔ منوی هفتگی'),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _allergyTab() {
    const banner = Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: IllustrationBanner(
        image: 'ill_food_allergy.png',
        title: 'حساسیت‌های غذایی',
        subtitle: 'مربی کلاس هنگام حضور و غیاب، هشدار این کودکان را می‌بیند.',
        tint: Color(0xFFFFEBEE),
      ),
    );
    if (_allergies.isEmpty) {
      return const Column(
        children: [
          banner,
          Expanded(child: Center(child: Text('هنوز حساسیتی ثبت نشده است.', style: TextStyle(color: Colors.grey)))),
        ],
      );
    }
    return Column(
      children: [
        banner,
        Expanded(child: _allergyList()),
      ],
    );
  }

  Widget _allergyList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _allergies.length,
      itemBuilder: (_, i) {
        final a = _allergies[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: severityColor(a.severity).withValues(alpha: 0.15),
              child: Icon(Icons.warning_amber_rounded, color: severityColor(a.severity)),
            ),
            title: Text('${a.studentName} • ${a.allergen}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${a.className} • شدت: ${a.severity}${a.notes.isEmpty ? '' : '\n${a.notes}'}', style: const TextStyle(fontSize: 12)),
            isThreeLine: a.notes.isNotEmpty,
            trailing: _canEdit
                ? IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _confirmDelete(a))
                : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF3F8FF),
          appBar: AppBar(
            title: const Text('تغذیه و سلامت'),
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            bottom: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [Tab(text: 'منوی هفتگی'), Tab(text: 'حساسیت‌های غذایی')],
            ),
          ),
          floatingActionButton: (_canEdit && !_loading)
              ? Builder(
                  builder: (ctx) => FloatingActionButton.extended(
                    onPressed: _addAllergyDialog,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('ثبت حساسیت'),
                  ),
                )
              : null,
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(children: [_menuTab(), _allergyTab()]),
        ),
      ),
    );
  }
}
