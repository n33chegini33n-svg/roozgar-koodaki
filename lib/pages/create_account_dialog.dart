import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sup;
import '../models/permissions.dart';
import '../services/backend.dart';
import '../services/backend_directory.dart';

const List<String> _grades = [
  'مهدکودک 👶',
  'پیش‌دبستانی 🎨',
  'اول دبستان ✏️',
  'دوم دبستان 📖',
  'سوم دبستان 📘',
  'چهارم دبستان 📐',
  'پنجم دبستان 🔬',
  'ششم دبستان 🎓',
];

String _norm(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// نام نوآموز از روی پرونده ثبت‌نام
String _regName(Map<String, dynamic> r) {
  final d = r['data'];
  if (d is! Map) return '';
  return _norm('${d['نام نوآموز'] ?? ''} ${d['نام خانوادگی'] ?? ''}');
}

/// فرم ساخت حساب کاربر (فقط ادمین و مدیر). اگر حساب ساخته شد true برمی‌گرداند.
Future<bool> showCreateAccountDialog(BuildContext context) async {
  if (!Backend.ready) return false;
  try {
    await ServerDirectory.ensureLoaded(force: true);
  } catch (_) {}

  // پرونده‌های تأییدشده‌ای که هنوز به نوآموزی وصل نشده‌اند
  List<Map<String, dynamic>> regs = [];
  try {
    final rows = await Backend.client
        .from('registration_records')
        .select('id, data')
        .eq('status', 'approved')
        .eq('is_deleted', false)
        .isFilter('student_id', null);
    regs = [for (final r in rows) Map<String, dynamic>.from(r)];
  } catch (_) {}

  if (!context.mounted) return false;

  final isAdmin = Session.role == AppRole.admin;

  final name = TextEditingController();
  final phone = TextEditingController();
  final code = TextEditingController(text: (100000 + math.Random.secure().nextInt(900000)).toString());
  var role = 'parent';
  var grade = _grades[1];
  String? studentClassId;
  String? selectedRegId;
  final classIds = <String>{};
  final childIds = <String>{};
  var busy = false;
  String? error;

  final created = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        final isStudent = role == 'student';
        final isStaff = role == 'teacher' || role == 'deputy';

        Future<void> pickClasses() async {
          final tmp = Set<String>.of(classIds);
          final ok = await showDialog<bool>(
            context: ctx,
            builder: (c) => StatefulBuilder(
              builder: (c, setP) => Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                  title: const Text('انتخاب کلاس‌ها'),
                  content: SizedBox(
                    width: 380,
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final cl in ServerDirectory.classList)
                          CheckboxListTile(
                            dense: true,
                            value: tmp.contains(cl.value),
                            title: Text(cl.key),
                            onChanged: (v) => setP(() {
                              if (v == true) {
                                tmp.add(cl.value);
                              } else {
                                tmp.remove(cl.value);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('تأیید')),
                  ],
                ),
              ),
            ),
          );
          if (ok == true) {
            setD(() {
              classIds
                ..clear()
                ..addAll(tmp);
            });
          }
        }

        Future<void> submit() async {
          final chosen = regs.where((r) => '${r['id']}' == selectedRegId).toList();
          final fullName = role == 'student' ? (chosen.isEmpty ? '' : _regName(chosen.first)) : _norm(name.text);
          final cleanPhone = phone.text.trim();
          final pass = code.text.trim();

          if (fullName.isEmpty) {
            setD(() => error = role == 'student' ? 'پروندهٔ ثبت‌نام تأییدشده را انتخاب کنید' : 'نام و نام خانوادگی را وارد کنید');
            return;
          }
          if (cleanPhone.isEmpty) {
            setD(() => error = 'شمارهٔ همراه را وارد کنید');
            return;
          }
          if (pass.length != 6) {
            setD(() => error = 'کد ورود باید ۶ رقم باشد');
            return;
          }
          if (role == 'teacher' && classIds.isEmpty) {
            setD(() => error = 'حداقل یک کلاس برای مربی انتخاب کنید');
            return;
          }
          if (isStudent) {
            if (studentClassId == null) {
              setD(() => error = 'کلاس نوآموز را انتخاب کنید');
              return;
            }
          }

          setD(() {
            busy = true;
            error = null;
          });

          try {
            String? studentId;
            if (isStudent) {
              final reg = chosen.first;
              // ۱. ساخت ردیف نوآموز
              final sid = await Backend.client.rpc('create_student_record', params: {
                'p_name': fullName,
                'p_class_id': studentClassId,
              }) as String;
              studentId = sid;
              // ۲. اتصال پروندهٔ تأییدشده به نوآموز
              await Backend.client.rpc('link_registration_to_student', params: {
                'p_registration': '${reg['id']}',
                'p_student': sid,
              });
            }

            // ۳. ساخت حساب ورود
            final res = await Backend.client.functions.invoke('create-user', body: {
              'full_name': fullName,
              'phone': cleanPhone,
              'password': pass,
              'role': role,
              'grade': isStudent ? grade : null,
              if (isStaff) 'class_ids': classIds.toList(),
              if (role == 'parent') 'student_ids': childIds.toList(),
              if (isStudent) 'student_id': studentId,
            });

            final data = res.data;
            if (data is Map && data['error'] != null) {
              setD(() {
                busy = false;
                error = '${data['error']}';
              });
              return;
            }
            if (ctx.mounted) Navigator.pop(ctx, true);
          } on sup.PostgrestException catch (e) {
            setD(() {
              busy = false;
              error = e.message;
            });
          } on sup.FunctionException catch (e) {
            final d = e.details;
            setD(() {
              busy = false;
              error = d is Map && d['error'] != null
                  ? '${d['error']}'
                  : 'ساخت حساب ناموفق بود (تابع سرور فعال است؟)';
            });
          } catch (_) {
            setD(() {
              busy = false;
              error = 'ارتباط با سرور برقرار نشد';
            });
          }
        }

        final students = ServerDirectory.students;
        final roles = <String, String>{
          if (isAdmin) 'manager': 'مدیر',
          'deputy': 'معاون / ناظم',
          'teacher': 'مربی / معلم',
          'parent': 'ولی',
          'student': 'دانش‌آموز (حساب مستقل) 🎒',
          'kitchen': 'آشپز',
        };
        final currentRole = roles.containsKey(role) ? role : 'parent';

        final selectedClassNames = ServerDirectory.classList
            .where((c) => classIds.contains(c.value))
            .map((c) => c.key)
            .join('، ');

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('ساخت حساب جدید'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: currentRole,
                      decoration: const InputDecoration(labelText: 'نقش کاربر', border: OutlineInputBorder(), isDense: true),
                      items: [for (final e in roles.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                      onChanged: (v) => setD(() {
                        role = v ?? role;
                        error = null;
                      }),
                    ),
                    const SizedBox(height: 10),
                    if (role == 'student')
                      DropdownButtonFormField<String>(
                        value: selectedRegId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'پروندهٔ ثبت‌نام تأییدشده', border: OutlineInputBorder(), isDense: true),
                        items: [
                          for (final r in regs)
                            DropdownMenuItem(value: '${r['id']}', child: Text(_regName(r), overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setD(() => selectedRegId = v),
                      )
                    else
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(labelText: 'نام و نام خانوادگی', border: OutlineInputBorder(), isDense: true),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(labelText: 'شمارهٔ همراه (نام کاربری)', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: 'کد ورود (۶ رقم)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        counterText: '',
                        suffixIcon: IconButton(
                          tooltip: 'کد تصادفی',
                          icon: const Icon(Icons.casino_rounded),
                          onPressed: () => setD(() => code.text = (100000 + math.Random.secure().nextInt(900000)).toString()),
                        ),
                      ),
                    ),

                    // ---- دانش‌آموز: کلاس و مقطع (در پایان) ----
                    if (isStudent) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: studentClassId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'کلاس نوآموز', border: OutlineInputBorder(), isDense: true),
                        items: [
                          for (final c in ServerDirectory.classList)
                            DropdownMenuItem(value: c.value, child: Text(c.key, overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setD(() => studentClassId = v),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: grade,
                        decoration: const InputDecoration(labelText: 'مقطع تحصیلی', border: OutlineInputBorder(), isDense: true),
                        items: [for (final g in _grades) DropdownMenuItem(value: g, child: Text(g))],
                        onChanged: (v) => setD(() => grade = v ?? grade),
                      ),
                    ],

                    // ---- مربی و معاون: چند کلاس ----
                    if (isStaff) ...[
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: busy ? null : pickClasses,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'کلاس‌ها (چند انتخابی)',
                            border: OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: Icon(Icons.arrow_drop_down_rounded),
                          ),
                          child: Text(
                            selectedClassNames.isEmpty ? 'انتخاب نشده' : selectedClassNames,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],

                    // ---- ولی: فرزندان (اختیاری) ----
                    if (role == 'parent') ...[
                      const SizedBox(height: 10),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text('فرزند(ان) این ولی (اختیاری):', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: students.isEmpty
                            ? const Padding(padding: EdgeInsets.all(8), child: Text('هنوز نوآموزی ثبت نشده است.'))
                            : ListView(
                                shrinkWrap: true,
                                children: [
                                  for (final s in students)
                                    CheckboxListTile(
                                      dense: true,
                                      value: childIds.contains(s.id),
                                      title: Text('${s.name} • ${s.className}', style: const TextStyle(fontSize: 13)),
                                      onChanged: (v) => setD(() {
                                        if (v == true) {
                                          childIds.add(s.id);
                                        } else {
                                          childIds.remove(s.id);
                                        }
                                      }),
                                    ),
                                ],
                              ),
                      ),
                    ],

                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: busy ? null : () => Navigator.pop(ctx, false), child: const Text('انصراف')),
              FilledButton(
                onPressed: busy ? null : submit,
                child: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('ساخت حساب'),
              ),
            ],
          ),
        );
      },
    ),
  );

  if (created == true && context.mounted) {
    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حساب ساخته شد'),
          content: SelectableText('شمارهٔ همراه: ${phone.text.trim()}\nکد ورود: ${code.text.trim()}\n\nاین دو را به کاربر بدهید.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('بسیار خوب'))],
        ),
      ),
    );
  }
  return created == true;
}
