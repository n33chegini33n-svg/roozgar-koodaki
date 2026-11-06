import 'package:flutter/material.dart';
import '../services/accounts_service.dart';
import '../services/backend.dart';

/// کادر انتخاب نوآموز با جستجو (نام، کد ملی، شمارهٔ ولی، مقطع)
Future<List<RegistrationStudent>?> showStudentPicker(
  BuildContext context, {
  bool multi = true,
  List<RegistrationStudent> initial = const [],
}) {
  return showDialog<List<RegistrationStudent>>(
    context: context,
    builder: (_) => StudentPickerDialog(multi: multi, initial: initial),
  );
}

class StudentPickerDialog extends StatefulWidget {
  final bool multi;
  final List<RegistrationStudent> initial;

  const StudentPickerDialog({super.key, this.multi = true, this.initial = const []});

  @override
  State<StudentPickerDialog> createState() => _StudentPickerDialogState();
}

class _StudentPickerDialogState extends State<StudentPickerDialog> {
  late final Future<List<RegistrationStudent>> _future = AccountsService.registeredStudents();
  final TextEditingController _search = TextEditingController();
  final Map<String, RegistrationStudent> _selected = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    for (final s in widget.initial) {
      _selected[s.studentId] = s;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(RegistrationStudent s) {
    setState(() {
      if (_selected.containsKey(s.studentId)) {
        _selected.remove(s.studentId);
      } else {
        if (!widget.multi) _selected.clear();
        _selected[s.studentId] = s;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'انتخاب نوآموز',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = Backend.latinDigits(v.trim().toLowerCase())),
                  decoration: InputDecoration(
                    hintText: 'جستجو با نام، کد ملی یا شمارهٔ ولی',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    isDense: true,
                  ),
                ),
                if (_selected.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in _selected.values)
                          InputChip(label: Text(s.name), onDeleted: () => _toggle(s)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: FutureBuilder<List<RegistrationStudent>>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(child: Text('خواندن فهرست انجام نشد: ${snap.error}'));
                      }
                      final all = snap.data ?? const <RegistrationStudent>[];
                      if (all.isEmpty) {
                        return const Center(child: Text('هنوز پروندهٔ ثبت‌نام ارسال‌شده‌ای نیست.'));
                      }
                      final list = all.where((s) => _query.isEmpty || s.searchText.contains(_query)).toList();
                      if (list.isEmpty) {
                        return const Center(child: Text('نوآموزی با این مشخصات پیدا نشد.'));
                      }
                      return ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = list[i];
                          final picked = _selected.containsKey(s.studentId);
                          final info = [
                            s.grade,
                            if (s.nationalCode.isNotEmpty) 'کد ملی: ${s.nationalCode}',
                            s.statusLabel,
                          ].where((e) => e.isNotEmpty).join(' • ');
                          return ListTile(
                            onTap: () => _toggle(s),
                            leading: Icon(
                              picked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: picked ? Colors.green : Colors.grey,
                            ),
                            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(info),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
                    const Spacer(),
                    FilledButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.pop(context, _selected.values.toList()),
                      child: Text('تأیید (${_selected.length})'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
