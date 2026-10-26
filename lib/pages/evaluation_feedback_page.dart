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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  void _selectTarget(int? index) {
    if (index == null) return;
    setState(() {
      _selectedTarget = index;
      final teachers = _targets[index].teachers;
      _selectedTeacherId = teachers.isEmpty ? null : teachers.first.id;
    });
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
      final sentToServer = await EvaluationService.submitFeedback(
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
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sentToServer
                ? 'نظر شما با موفقیت و به‌صورت محرمانه ثبت شد'
                : 'نظر فقط روی این دستگاه ذخیره شد و به مدیریت ارسال نشد',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      if (sentToServer) {
        _noteController.clear();
        setState(() {
          for (var index = 0; index < 4; index++) {
            _teacherScores[index] = 0;
            _schoolScores[index] = 0;
          }
        });
      }
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                          onChanged: _selectTarget,
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
                          onChanged: (value) => setState(() => _selectedTeacherId = value),
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
                FilledButton.icon(
                  onPressed: _submitting || target.teachers.isEmpty ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  label: Text(_submitting ? 'در حال ثبت...' : 'ثبت نظرسنجی'),
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

  const _StarRating({required this.label, required this.value, required this.onChanged});

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
                    onPressed: () => onChanged(star),
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
