import 'package:flutter/material.dart';
import '../models/school_classes.dart';
import '../services/backend.dart';
import '../services/backend_directory.dart';

const Color _navy = Color(0xFF01579B);

/// کادر ساخت کمپین مالی: انتخاب کلاس‌ها به تفکیک مهدکودک و دبستان
/// این مرحله فقط انتخاب و پیش‌نمایش است؛ ذخیرهٔ کمپین در مرحلهٔ بعد اضافه می‌شود.
Future<void> showCampaignDialog(BuildContext context) async {
  try {
    await ServerDirectory.ensureLoaded(force: true);
  } catch (_) {}
  if (!context.mounted) return;
  await showDialog<void>(context: context, builder: (_) => const CampaignDialog());
}

bool _isKinder(String n) => n.contains('پیش') || n.contains('مهد');
bool _isSchool(String n) => !_isKinder(n); // هر کلاسی که مهدکودک نیست، اینجا می‌آید

class CampaignDialog extends StatefulWidget {
  const CampaignDialog({super.key});

  @override
  State<CampaignDialog> createState() => _CampaignDialogState();
}

class _CampaignDialogState extends State<CampaignDialog> {
  final _title = TextEditingController();
  final _reason = TextEditingController();
  final _amount = TextEditingController();
  final _deadline = TextEditingController();

  final Set<String> _selected = {};
  // پیوند ولی و نوآموز؛ هر فرزند یک ردیف است
  List<Map<String, dynamic>> _links = [];
  bool _loadingLinks = true;

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    try {
      final rows = await Backend.client.from('parent_students').select('parent_id, student_id');
      if (!mounted) return;
      setState(() {
        _links = rows.map((e) => Map<String, dynamic>.from(e)).toList();
        _loadingLinks = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingLinks = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _reason, _amount, _deadline]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _kinderClasses =>
      [for (final c in ServerDirectory.classList) if (_isKinder(c.key)) c.key];

  List<String> get _schoolClasses =>
      [for (final c in ServerDirectory.classList) if (_isSchool(c.key)) c.key];

  List<ServerStudent> get _matchedStudents => [
        for (final s in ServerDirectory.students)
          if (_selected.contains(normalizeClassName(s.className))) s,
      ];

  int get _parentLinks {
    final ids = _matchedStudents.map((s) => s.id).toSet();
    return _links.where((l) => ids.contains('${l['student_id']}')).length;
  }

  void _toggleAll(List<String> group, bool value) {
    setState(() {
      if (value) {
        _selected.addAll(group);
      } else {
        _selected.removeAll(group);
      }
    });
  }

  bool _saving = false;

  Future<void> _next() async {
    final title = _title.text.trim();
    final reason = _reason.text.trim();
    final amount = int.tryParse(_amount.text.trim().replaceAll(RegExp(r'[,،٬\s]'), '')) ?? 0;
    final messenger = ScaffoldMessenger.of(context);
    if (title.isEmpty || reason.length < 5) {
      messenger.showSnackBar(const SnackBar(
        content: Text('عنوان و دلیل کمپین را کامل بنویس'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    if (amount <= 0) {
      messenger.showSnackBar(const SnackBar(
        content: Text('مبلغ را درست وارد کن'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    if (_selected.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('حداقل یک کلاس را تیک بزن'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final classIds = <String>[
      for (final c in _selected)
        if (ServerDirectory.classId(c) != null) ServerDirectory.classId(c)!,
    ];
    final deadline = _deadline.text.trim();
    setState(() => _saving = true);
    try {
      final res = await Backend.client.rpc('create_campaign', params: {
        'p_title': title,
        'p_reason': reason,
        'p_amount': amount,
        'p_due': deadline.isEmpty ? null : deadline,
        'p_class_ids': classIds,
      });
      messenger.showSnackBar(SnackBar(
        content: Text('کمپین ساخته شد • $res بند مالی'),
        backgroundColor: Colors.green,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(
        content: Text('ساخت کمپین انجام نشد: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _group(String title, List<String> classes) {
    final allOn = classes.isNotEmpty && classes.every(_selected.contains);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD5E3F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 15)),
              ),
              if (classes.isNotEmpty)
                TextButton(
                  onPressed: () => _toggleAll(classes, !allOn),
                  child: Text(allOn ? 'لغو همه' : 'انتخاب همه'),
                ),
            ],
          ),
          if (classes.isEmpty)
            const Text('کلاسی در این بخش ثبت نشده است', style: TextStyle(color: Colors.black54))
          else
            for (final c in classes)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(classLabel(c)),
                value: _selected.contains(c),
                onChanged: (v) => setState(() => v == true ? _selected.add(c) : _selected.remove(c)),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Container(
          width: 620,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ساخت کمپین مالی',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _title,
                        decoration: const InputDecoration(
                            labelText: 'عنوان کمپین', border: OutlineInputBorder(), isDense: true),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _reason,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            labelText: 'دلیل (الزامی)', border: OutlineInputBorder(), isDense: true),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _amount,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'مبلغ برای هر فرزند (تومان)', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _deadline,
                              decoration: const InputDecoration(
                                  labelText: 'مهلت پرداخت (شمسی)', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                        ],
                      ),
                      _group('مهدکودک و پیش‌دبستانی', _kinderClasses),
                      _group('دبستان و سایر کلاس‌ها', _schoolClasses),
                      const Divider(height: 22),
                      _loadingLinks
                          ? const LinearProgressIndicator(minHeight: 2)
                          : Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFE1F5FE), borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                'نوآموز: ${_matchedStudents.length}  •  بند مالی برای ولی‌ها (به ازای هر فرزند): $_parentLinks',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: _navy),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _saving ? null : _next, child: Text(_saving ? 'در حال ساخت...' : 'ساخت کمپین')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
