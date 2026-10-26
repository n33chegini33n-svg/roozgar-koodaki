import 'package:flutter/material.dart';

import '../models/evaluation_feedback_model.dart';
import '../models/permissions.dart';
import '../models/school_classes.dart';
import '../models/user_directory.dart';
import '../services/backend.dart';
import '../services/backend_directory.dart';
import '../services/evaluation_service.dart';
import '../theme/app_colors.dart';

class EvaluationFeedbackPage extends StatefulWidget {
  const EvaluationFeedbackPage({super.key});

  @override
  State<EvaluationFeedbackPage> createState() => _EvaluationFeedbackPageState();
}

class _EvaluationFeedbackPageState extends State<EvaluationFeedbackPage> {
  static const _teacherQuestions = [
    'کیفیت آموزش مربی',
    'ارتباط مربی با کودک',
    'توجه و همراهی مربی',
    'کمک به پیشرفت کودک',
  ];
  static const _schoolQuestions = [
    'کیفیت برنامه‌های آموزشی',
    'عملکرد کلی مربیان',
    'کیفیت تغذیه',
    'محیط و امکانات مهد',
  ];

  final _noteController = TextEditingController();
  final _teacherScores = List<int>.filled(4, 0);
  final _schoolScores = List<int>.filled(4, 0);
  List<_ChildEvaluationTarget> _targets = [];
  int _selectedTarget = 0;
  String? _selectedTeacherId;
  bool _loading = true;
  bool _submitting = false;
  bool _monthLoading = false;
  bool _editingMonthlyFeedback = false;
  EvaluationFeedback? _monthlyFeedback;
  String? _loadError;

  _ChildEvaluationTarget? get _target =>
      _targets.isEmpty ? null : _targets[_selectedTarget.clamp(0, _targets.length - 1)];

  UserModel? get _teacher {
    final target = _target;
    if (target == null) return null;
    if (target.teachers.isEmpty) return null;
    return target.teachers.firstWhere(
      (teacher) => teacher.id == _selectedTeacherId,
      orElse: () => target.teachers.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadTargets() async {
    try {
      final teachers = await UserDirectory.byRole('teacher');
      final targets = <_ChildEvaluationTarget>[];
      if (Backend.ready) {
        await ServerDirectory.ensureLoaded();
        final linkedIds = Session.childStudentIds.toSet();
        final children = ServerDirectory.students.where((student) => linkedIds.contains(student.id));
        for (final child in children) {
          targets.add(
            _ChildEvaluationTarget(
              id: child.id,
              name: child.name,
              className: child.className,
              teachers: teachers.where((teacher) => sameClass(teacher.className, child.className)).toList(),
            ),
          );
        }
      } else if (Session.childName.isNotEmpty && Session.className.isNotEmpty) {
        final matchingStudent = ServerDirectory.students.where(
          (student) => student.name == Session.childName && sameClass(student.className, Session.className),
        );
        targets.add(
          _ChildEvaluationTarget(
            id: matchingStudent.isEmpty ? '' : matchingStudent.first.id,
            name: Session.childName,
            className: Session.className,
            teachers: teachers.where((teacher) => sameClass(teacher.className, Session.className)).toList(),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _targets = targets;
        _selectedTeacherId = targets.isNotEmpty && targets.first.teachers.isNotEmpty
            ? targets.first.teachers.first.id
            : null;
        _loading = false;
      });
      await _loadMonthlyFeedback();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _selectTarget(int? index) async {
    if (index == null) return;
    setState(() {
      _selectedTarget = index;
      _monthlyFeedback = null;
      _editingMonthlyFeedback = false;
      final teachers = _targets[index].teachers;
      _selectedTeacherId = teachers.isEmpty ? null : teachers.first.id;
      for (var item = 0; item < 4; item++) {
        _teacherScores[item] = 0;
        _schoolScores[item] = 0;
      }
      _noteController.clear();
    });
    await _loadMonthlyFeedback();
  }

  Future<void> _loadMonthlyFeedback() async {
    final target = _target;
    if (target == null || target.id.isEmpty) return;
    setState(() => _monthLoading = true);
    try {
      final feedback = await EvaluationService.getCurrentMonthFeedback(studentId: target.id);
      if (!mounted) return;
      setState(() {
        _monthlyFeedback = feedback;
        _editingMonthlyFeedback = false;
        if (feedback != null) {
          _selectedTeacherId = feedback.teacherId;
          _teacherScores[0] = feedback.teacherTeachingScore;
          _teacherScores[1] = feedback.teacherCommunicationScore;
          _teacherScores[2] = feedback.teacherCareScore;
          _teacherScores[3] = feedback.teacherProgressScore;
          _schoolScores[0] = feedback.schoolEducationScore;
          _schoolScores[1] = feedback.schoolStaffScore;
          _schoolScores[2] = feedback.schoolNutritionScore;
          _schoolScores[3] = feedback.schoolEnvironmentScore;
          _noteController.text = feedback.privateNote;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = '$e');
    } finally {
      if (mounted) setState(() => _monthLoading = false);
    }
  }

  Future<void> _submit() async {
    final target = _target;
    final teacher = _teacher;
    if (target == null || teacher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فرزند یا مربی اختصاصی برای این حساب پیدا نشد')),
      );
      return;
    }
    if (_teacherScores.contains(0) || _schoolScores.contains(0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً به همهٔ شاخص‌ها امتیاز بدهید')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final sentToServer = await EvaluationService.submitOrUpdateFeedback(
        EvaluationFeedback(
          studentId: target.id,
          studentName: target.name,
          className: target.className,
          teacherId: teacher.id,
          teacherName: teacher.name,
          teacherTeachingScore: _teacherScores[0],
          teacherCommunicationScore: _teacherScores[1],
          teacherCareScore: _teacherScores[2],
          teacherProgressScore: _teacherScores[3],
          schoolEducationScore: _schoolScores[0],
          schoolStaffScore: _schoolScores[1],
          schoolNutritionScore: _schoolScores[2],
          schoolEnvironmentScore: _schoolScores[3],
          privateNote: _noteController.text.trim(),
          createdAt: DateTime.now(),
        ),
        isEditing: _monthlyFeedback != null,
      );
      final savedFeedback = await EvaluationService.getCurrentMonthFeedback(studentId: target.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sentToServer
                ? (_monthlyFeedback == null
                    ? 'نظرسنجی این ماه با موفقیت ثبت شد. تنها ۱ بار فرصت ویرایش دارید.'
                    : 'ویرایش نهایی نظرسنجی ثبت شد.')
                : 'نظرسنجی فقط روی این دستگاه ذخیره شد و به مدیریت ارسال نشد',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      setState(() {
        _monthlyFeedback = savedFeedback;
        _editingMonthlyFeedback = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ثبت نظر انجام نشد: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نظرسنجی و ارزیابی کیفیت'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Center(child: Text('بارگذاری اطلاعات انجام نشد: $_loadError'))
                : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    final target = _target;
    final canEdit = !_monthLoading && (_monthlyFeedback == null || _editingMonthlyFeedback);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_monthLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
              if (_monthlyFeedback != null)
                _FormCard(
                  child: Row(
                    children: [
                      Icon(
                        _monthlyFeedback!.isLocked ? Icons.lock_rounded : Icons.info_outline_rounded,
                        color: _monthlyFeedback!.isLocked ? Colors.red : Colors.deepOrange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _monthlyFeedback!.isLocked
                              ? 'فرصت ویرایش این نظرسنجی استفاده شده است؛ فرم برای این ماه قفل نهایی است.'
                              : 'نظرسنجی این ماه ثبت شده است؛ تنها ۱ بار فرصت ویرایش نهایی دارید.',
                        ),
                      ),
                      if (!_monthlyFeedback!.isLocked && !_editingMonthlyFeedback)
                        TextButton(
                          onPressed: _monthLoading
                              ? null
                              : () => setState(() => _editingMonthlyFeedback = true),
                          child: const Text('ویرایش نهایی'),
                        ),
                    ],
                  ),
                ),
              if (_monthlyFeedback != null) const SizedBox(height: 12),
              if (_targets.isEmpty || target == null)
                const _FormCard(
                  child: Text('برای این حساب، فرزند مرتبطی پیدا نشد.'),
                )
              else ...[
                _FormCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ارزیابی برای فرزند', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_targets.length > 1)
                        DropdownButtonFormField<int>(
                          initialValue: _selectedTarget,
                          decoration: const InputDecoration(labelText: 'انتخاب فرزند'),
                          items: [
                            for (var index = 0; index < _targets.length; index++)
                              DropdownMenuItem(value: index, child: Text(_targets[index].name)),
                          ],
                          onChanged: _monthlyFeedback == null && !_monthLoading ? _selectTarget : null,
                        )
                      else
                        Text('${target.name} • ${target.className}'),
                      const SizedBox(height: 8),
                      if (target.teachers.isEmpty)
                        const Text('مربی این کلاس در سامانه مشخص نشده است.', style: TextStyle(color: Colors.red))
                      else if (target.teachers.length == 1)
                        Text('مربی اختصاصی: ${target.teachers.first.name}')
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _teacher?.id,
                          decoration: const InputDecoration(labelText: 'مربی اختصاصی فرزند'),
                          items: [
                            for (final teacher in target.teachers)
                              DropdownMenuItem(value: teacher.id, child: Text(teacher.name)),
                          ],
                          onChanged: _monthlyFeedback == null && !_monthLoading
                              ? (value) => setState(() => _selectedTeacherId = value)
                              : null,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _FormCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ارزیابی مربی اختصاصی', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      for (var index = 0; index < _teacherQuestions.length; index++)
                        _StarRating(
                          label: _teacherQuestions[index],
                          value: _teacherScores[index],
                          enabled: canEdit,
                          onChanged: (value) => setState(() => _teacherScores[index] = value),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _FormCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ارزیابی کیفیت مهد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      for (var index = 0; index < _schoolQuestions.length; index++)
                        _StarRating(
                          label: _schoolQuestions[index],
                          value: _schoolScores[index],
                          enabled: canEdit,
                          onChanged: (value) => setState(() => _schoolScores[index] = value),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _FormCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('پیشنهاد محرمانه به مدیر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text(
                        'متن این بخش در نمودارها و آمار عمومی نمایش داده نمی‌شود.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _noteController,
                        enabled: canEdit,
                        maxLines: 5,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          hintText: 'پیشنهاد یا نکتهٔ خود را بنویسید...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_monthlyFeedback == null || _editingMonthlyFeedback)
                  FilledButton.icon(
                    onPressed: _submitting || _monthLoading || target.teachers.isEmpty ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(_editingMonthlyFeedback ? Icons.lock_outline_rounded : Icons.send_rounded),
                    label: Text(_submitting
                        ? 'در حال ثبت...'
                        : _editingMonthlyFeedback
                            ? 'ثبت ویرایش نهایی'
                            : 'ثبت نظرسنجی'),
                  )
                else
                  FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.lock_rounded),
                    label: const Text('قفل نهایی این ماه'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildEvaluationTarget {
  final String id;
  final String name;
  final String className;
  final List<UserModel> teachers;

  const _ChildEvaluationTarget({
    required this.id,
    required this.name,
    required this.className,
    required this.teachers,
  });
}

class _StarRating extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  const _StarRating({required this.label, required this.value, required this.onChanged, this.enabled = true});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              children: [
                for (var star = 1; star <= 5; star++)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '$star از ۵',
                    onPressed: enabled ? () => onChanged(star) : null,
                    icon: Icon(
                      star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFFFB300),
                      size: 28,
                    ),
                  ),
                if (value > 0) Text('$value از ۵', style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ],
        ),
      );
}

class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );
}
