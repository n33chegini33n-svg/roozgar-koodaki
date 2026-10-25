import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../parent/parent_sections.dart' show SectionScaffold, softCard;
import '../models/homework_model.dart';
import '../models/permissions.dart';

class TeacherHomeworkPage extends StatefulWidget {
  const TeacherHomeworkPage({super.key});

  @override
  State<TeacherHomeworkPage> createState() => _TeacherHomeworkPageState();
}

class _TeacherHomeworkPageState extends State<TeacherHomeworkPage> {
  bool _loading = true;
  List<Homework> _items = [];
  final Map<String, int> _doneCount = {};

  bool get _canManage =>
      PermissionService.instance.allows(Session.role, Perm.manageHomework, className: Session.className);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await HomeworkService.forClass(Session.className);
    final counts = <String, int>{};
    for (final h in items) {
      counts[h.id] = (await HomeworkService.doneBy(h.id)).length;
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _doneCount
        ..clear()
        ..addAll(counts);
      _loading = false;
    });
  }

  void _snack(String msg, [Color? color]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _addDialog() async {
    if (!_canManage) {
      _snack('شما اجازهٔ تعریف تکلیف ندارید', Colors.red);
      return;
    }
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final dueCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تعریف تکلیف جدید'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'عنوان تکلیف', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'توضیحات', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: dueCtrl, decoration: const InputDecoration(labelText: 'مهلت (مثلاً تا سه‌شنبه)', border: OutlineInputBorder())),
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
    );
    if (ok != true) return;
    await HomeworkService.add(
      Homework(
        id: 'HW-${DateTime.now().millisecondsSinceEpoch}',
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        due: dueCtrl.text.trim().isEmpty ? 'بدون مهلت' : dueCtrl.text.trim(),
        className: Session.className,
        createdBy: Session.userName,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _load();
    _snack('✅ تکلیف برای والدین نمایش داده می‌شود', Colors.green);
  }

  Future<void> _showDone(Homework h) async {
    final names = await HomeworkService.doneBy(h.id);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('انجام‌شده: ${h.title}'),
          content: Text(names.isEmpty ? 'هنوز کسی علامت نزده است.' : names.join('\n')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))],
        ),
      ),
    );
  }

  Future<void> _delete(Homework h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف تکلیف؟'),
          content: Text(h.title),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await HomeworkService.remove(h.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'تکالیف کلاس',
      image: 'ill_homework_upload.png',
      child: _loading
          ? const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          : Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('تکالیف فعال کلاس', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    if (_canManage)
                      ElevatedButton.icon(
                        onPressed: _addDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('تعریف تکلیف جدید'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_items.isEmpty)
                  softCard(
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: Text('هنوز تکلیفی تعریف نشده است.', style: TextStyle(color: AppColors.textGrey))),
                    ),
                  ),
                for (final item in _items)
                  softCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                              child: Text(item.due, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                            ),
                          ],
                        ),
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(item.description, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('انجام‌شده: ${_doneCount[item.id] ?? 0} نفر', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _showDone(item),
                                  icon: const Icon(Icons.visibility_rounded, size: 16),
                                  label: const Text('چه کسانی؟'),
                                ),
                                if (_canManage)
                                  IconButton(
                                    tooltip: 'حذف',
                                    onPressed: () => _delete(item),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

