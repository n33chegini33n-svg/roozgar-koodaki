import 'package:flutter/material.dart';
import '../services/accounts_service.dart';

/// مدیریت کلاس‌ها: ساخت، ویرایش، فعال/غیرفعال
class ManagerClassesPage extends StatefulWidget {
  const ManagerClassesPage({super.key});

  @override
  State<ManagerClassesPage> createState() => _ManagerClassesPageState();
}

class _ManagerClassesPageState extends State<ManagerClassesPage> {
  static const Color _navy = Color(0xFF01579B);
  bool _loading = true;
  String? _error;
  List<SchoolClass> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AccountsService.allClasses();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _snack(String msg, [Color? color]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _toggle(SchoolClass c, bool value) async {
    try {
      await AccountsService.saveClass(id: c.id, name: c.name, grade: c.grade, active: value);
      await _load();
    } catch (e) {
      _snack('ذخیره انجام نشد: $e', Colors.red);
    }
  }

  Future<void> _edit([SchoolClass? c]) async {
    final nameCtrl = TextEditingController(text: c?.name ?? '');
    String? grade = kClassGrades.contains(c?.grade) ? c?.grade : null;
    bool active = c?.active ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(c == null ? 'کلاس جدید' : 'ویرایش کلاس'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'نام کلاس',
                      hintText: 'مثلاً: پیش‌دبستانی آفتاب',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: grade,
                    decoration: const InputDecoration(labelText: 'مقطع', border: OutlineInputBorder()),
                    items: [for (final g in kClassGrades) DropdownMenuItem(value: g, child: Text(g))],
                    onChanged: (v) => setD(() => grade = v),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('فعال'),
                    subtitle: const Text('کلاس غیرفعال در فرم‌ها دیده نمی‌شود و اطلاعاتش حفظ می‌شود.'),
                    value: active,
                    onChanged: (v) => setD(() => active = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ذخیره')),
            ],
          ),
        ),
      ),
    );

    final name = nameCtrl.text.trim();
    if (ok != true) return;
    if (name.isEmpty) {
      _snack('نام کلاس را وارد کنید', Colors.orange.shade800);
      return;
    }
    try {
      await AccountsService.saveClass(id: c?.id, name: name, grade: grade ?? '', active: active);
      _snack('✅ کلاس ذخیره شد', Colors.green);
      await _load();
    } catch (e) {
      _snack('ذخیره انجام نشد: $e', Colors.red);
    }
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('خواندن کلاس‌ها انجام نشد:\n$_error', textAlign: TextAlign.center),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('هنوز کلاسی ثبت نشده است.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final c = _items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: c.active ? const Color(0xFFE1F5FE) : Colors.grey.shade200,
              child: Icon(Icons.school_rounded, color: c.active ? _navy : Colors.grey),
            ),
            title: Text(
              c.name,
              style: TextStyle(fontWeight: FontWeight.bold, color: c.active ? Colors.black87 : Colors.grey),
            ),
            subtitle: Text(c.grade.isEmpty ? 'مقطع ثبت نشده' : c.grade),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(value: c.active, onChanged: (v) => _toggle(c, v)),
                IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => _edit(c)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Text('کلاس‌ها'),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          backgroundColor: const Color(0xFF0288D1),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('کلاس جدید'),
        ),
        body: _body(),
      ),
    );
  }
}
