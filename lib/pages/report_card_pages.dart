import 'package:flutter/material.dart';
import '../models/audit_log_model.dart';
import '../models/permissions.dart';
import '../models/report_card_model.dart';
import '../models/school_classes.dart';
import '../models/user_directory.dart';
import '../parent/parent_sections.dart' show SectionScaffold, kPageBg, softCard;
import '../theme/app_colors.dart';
import '../utils/jalali.dart';
import '../widgets/safe_image.dart';

Color _levelColor(String level) {
  switch (level) {
    case 'خیلی خوب':
      return const Color(0xFF2E9E6B);
    case 'خوب':
      return const Color(0xFF1473C9);
    case 'قابل قبول':
      return const Color(0xFFF59E0B);
  }
  return const Color(0xFFE5484D);
}

/// فهرست نوآموزان برای ثبت یا دیدن کارنامه (معلم، معاون، مدیر)
class ReportCardHubPage extends StatefulWidget {
  const ReportCardHubPage({super.key});

  @override
  State<ReportCardHubPage> createState() => _ReportCardHubPageState();
}

class _ReportCardHubPageState extends State<ReportCardHubPage> {
  bool _loading = true;
  List<UserModel> _students = [];
  final Set<String> _done = {};
  final String _term = currentTerm();

  PermissionService get _perms => PermissionService.instance;
  bool get _canManage => _perms.can(Session.role, Perm.manageReportCard);
  bool get _canView => _perms.can(Session.role, Perm.viewReportCard) || _canManage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var students = await UserDirectory.byRole('student');
    // دامنهٔ «خودش» یعنی فقط کلاس خودش
    final scope = _perms.scopeOf(Session.role, _canManage ? Perm.manageReportCard : Perm.viewReportCard);
    if (scope == Scope.own) {
      students = students.where((s) => sameClass(s.className, Session.className)).toList();
    }
    final done = <String>{};
    for (final s in students) {
      if (await ReportCardService.get(s.name, _term) != null) done.add(s.name);
    }
    if (!mounted) return;
    setState(() {
      _students = students;
      _done
        ..clear()
        ..addAll(done);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'کارنامه',
      image: 'scene_report.png',
      child: _loading
          ? const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())
          : !_canView
              ? softCard(child: const Center(child: Text('دسترسی به این بخش برای شما فعال نیست.')))
              : Column(
                  children: [
                    softCard(
                      child: Row(
                        children: [
                          const Icon(Icons.event_note_rounded, color: AppColors.navy),
                          const SizedBox(width: 10),
                          Expanded(child: Text(faDigits(_term), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy))),
                          Text('${faDigits(_done.length)} از ${faDigits(_students.length)} ثبت شده',
                              style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                        ],
                      ),
                    ),
                    for (final s in _students)
                      softCard(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: ListTile(
                          leading: ChildAvatar(name: s.name, size: 44),
                          title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                          subtitle: Text(classLabel(s.className)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (_done.contains(s.name) ? const Color(0xFF2E9E6B) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _done.contains(s.name) ? 'ثبت شده' : 'ثبت نشده',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _done.contains(s.name) ? const Color(0xFF2E9E6B) : const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReportCardEditPage(studentName: s.name, className: s.className, readOnly: !_canManage),
                              ),
                            );
                            _load();
                          },
                        ),
                      ),
                  ],
                ),
    );
  }
}

/// ثبت یا مشاهدهٔ کارنامهٔ یک نوآموز در نیم‌سال جاری
class ReportCardEditPage extends StatefulWidget {
  final String studentName;
  final String className;
  final bool readOnly;
  const ReportCardEditPage({super.key, required this.studentName, required this.className, this.readOnly = false});

  @override
  State<ReportCardEditPage> createState() => _ReportCardEditPageState();
}

class _ReportCardEditPageState extends State<ReportCardEditPage> {
  final String _term = currentTerm();
  late final List<String> _subjects = subjectsForClass(widget.className);
  final Map<String, String> _levels = {};
  final TextEditingController _note = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await ReportCardService.get(widget.studentName, _term);
    if (!mounted) return;
    setState(() {
      if (c != null) {
        _levels.addAll(c.levels);
        _note.text = c.note;
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (widget.readOnly) return;
    if (_levels.length < _subjects.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برای همهٔ درس‌ها یک سطح انتخاب کنید')),
      );
      return;
    }
    await ReportCardService.save(ReportCard(
      studentName: widget.studentName,
      className: normalizeClassName(widget.className),
      term: _term,
      levels: Map<String, String>.from(_levels),
      note: _note.text.trim(),
      updatedBy: Session.userName,
      updatedAt: JalaliDate.now().formatted,
    ));
    await AuditLogService.log(
      actor: Session.userName,
      role: Session.role.label,
      action: 'ثبت کارنامه',
      details: '${widget.studentName} • $_term',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کارنامه ثبت شد')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
        title: Text('کارنامهٔ ${widget.studentName}'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(faDigits(_term), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 8),
                for (final s in _subjects)
                  softCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final l in kReportLevels)
                              ChoiceChip(
                                label: Text(l, style: const TextStyle(fontSize: 12)),
                                selected: _levels[s] == l,
                                selectedColor: _levelColor(l).withValues(alpha: 0.25),
                                onSelected: widget.readOnly ? null : (_) => setState(() => _levels[s] = l),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                softCard(
                  child: TextField(
                    controller: _note,
                    enabled: !widget.readOnly,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'توضیح مربی برای خانواده', border: OutlineInputBorder()),
                  ),
                ),
                if (!widget.readOnly)
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('ثبت کارنامه'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// کارنامهٔ فرزند برای ولی
class ParentReportCardPage extends StatefulWidget {
  const ParentReportCardPage({super.key});

  @override
  State<ParentReportCardPage> createState() => _ParentReportCardPageState();
}

class _ParentReportCardPageState extends State<ParentReportCardPage> {
  bool _loading = true;
  List<ReportCard> _cards = [];

  bool get _allowed => PermissionService.instance.can(Session.role, Perm.viewReportCard);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = _allowed ? await ReportCardService.forStudent(Session.childName) : <ReportCard>[];
    if (!mounted) return;
    setState(() {
      _cards = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'کارنامهٔ ${Session.childName}',
      image: 'scene_report.png',
      child: _loading
          ? const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())
          : !_allowed
              ? softCard(child: const Center(child: Text('دسترسی به این بخش برای شما فعال نیست.')))
              : _cards.isEmpty
                  ? softCard(
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: Text('هنوز کارنامه‌ای ثبت نشده است.', style: TextStyle(color: AppColors.textGrey))),
                      ),
                    )
                  : Column(
                      children: [
                        for (final c in _cards)
                          softCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(faDigits(c.term), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy)),
                                const SizedBox(height: 10),
                                for (final e in c.levels.entries)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(e.key)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _levelColor(e.value).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Text(e.value,
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _levelColor(e.value))),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (c.note.isNotEmpty) ...[
                                  const Divider(),
                                  Text(c.note, style: const TextStyle(height: 1.6)),
                                ],
                                const SizedBox(height: 6),
                                Text('ثبت‌کننده: ${c.updatedBy} • ${faDigits(c.updatedAt)}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                              ],
                            ),
                          ),
                      ],
                    ),
    );
  }
}
