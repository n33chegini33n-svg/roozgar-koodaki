import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/homework_model.dart';
import '../models/permissions.dart';
import 'parent_sections.dart' show SectionScaffold, softCard;

class HomeworkPage extends StatefulWidget {
  const HomeworkPage({super.key});

  @override
  State<HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<HomeworkPage> {
  bool _loading = true;
  List<Homework> _items = [];
  Set<String> _done = {};

  bool get _allowed => PermissionService.instance.can(AppRole.parent, Perm.viewHomework);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_allowed) {
      setState(() => _loading = false);
      return;
    }
    final items = await HomeworkService.forClass(Session.className);
    final done = await HomeworkService.doneIds(Session.childName);
    if (!mounted) return;
    setState(() {
      _items = items;
      _done = done;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'تکالیف',
      image: 'ill_homework_upload.png',
      child: _loading
          ? const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          : !_allowed
              ? softCard(
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: Text('دسترسی به این بخش برای شما فعال نیست.', style: TextStyle(color: AppColors.textGrey))),
                  ),
                )
              : _items.isEmpty
                  ? softCard(
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: Text('هنوز تکلیفی تعریف نشده است.', style: TextStyle(color: AppColors.textGrey))),
                      ),
                    )
                  : Column(
                      children: [
                        for (final h in _items)
                          softCard(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: CheckboxListTile(
                              value: _done.contains(h.id),
                              onChanged: (v) async {
                                final value = v ?? false;
                                await HomeworkService.setDone(Session.childName, h.id, value);
                                if (!mounted) return;
                                setState(() => value ? _done.add(h.id) : _done.remove(h.id));
                              },
                              activeColor: AppColors.navy,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                h.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navy,
                                  decoration: _done.contains(h.id) ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              subtitle: Text('${h.due}${h.description.isEmpty ? '' : '\n${h.description}'}'),
                              isThreeLine: h.description.isNotEmpty,
                            ),
                          ),
                        const Text('وضعیت انجام‌شدن برای مربی نیز نمایش داده می‌شود.',
                            style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                      ],
                    ),
    );
  }
}

