import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sup;
import '../models/permissions.dart';
import '../services/backend.dart';
import '../services/backend_directory.dart';

/// فرم ساخت حساب کاربر (فقط ادمین و مدیر؛ ساخت واقعی با تابع سمت سرور create-user انجام می‌شود)
/// اگر حساب ساخته شد true برمی‌گرداند.
Future<bool> showCreateAccountDialog(BuildContext context) async {
  if (!Backend.ready) return false;
  try {
    await ServerDirectory.ensureLoaded(force: true);
  } catch (_) {}
  if (!context.mounted) return false;

  final isAdmin = Session.role == AppRole.admin;
  final roles = <String, String>{
    if (isAdmin) 'manager': 'مدیر',
    'deputy': 'معاون / ناظم',
    'teacher': 'مربی / معلم',
    'parent': 'ولی',
  };

  final name = TextEditingController();
  final phone = TextEditingController();
  final code = TextEditingController(text: (100000 + math.Random.secure().nextInt(900000)).toString());
  var role = 'parent';
  String? classId;
  final selected = <String>{};
  var busy = false;
  String? error;

  final created = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        Future<void> submit() async {
          setD(() {
            busy = true;
            error = null;
          });
          try {
            final res = await Backend.client.functions.invoke('create-user', body: {
              'full_name': name.text.trim(),
              'phone': phone.text.trim(),
              'password': code.text.trim(),
              'role': role,
              if (role == 'teacher') 'class_id': classId,
              if (role == 'parent') 'student_ids': selected.toList(),
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
          } on sup.FunctionException catch (e) {
            final d = e.details;
            setD(() {
              busy = false;
              error = d is Map && d['error'] != null ? '${d['error']}' : 'ساخت حساب ناموفق بود (تابع سرور فعال است؟)';
            });
          } catch (e) {
            setD(() {
              busy = false;
              error = 'ارتباط با سرور برقرار نشد';
            });
          }
        }

        final students = ServerDirectory.students;
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
                    TextField(controller: name, decoration: const InputDecoration(labelText: 'نام و نام خانوادگی', border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(labelText: 'شمارهٔ همراه (نام کاربری)', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(labelText: 'نقش', border: OutlineInputBorder(), isDense: true),
                      items: [for (final e in roles.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                      onChanged: (v) => setD(() => role = v ?? role),
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
                    if (role == 'teacher') ...[
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: classId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'کلاس مربی', border: OutlineInputBorder(), isDense: true),
                        items: [for (final c in ServerDirectory.classList) DropdownMenuItem(value: c.value, child: Text(c.key, overflow: TextOverflow.ellipsis))],
                        onChanged: (v) => setD(() => classId = v),
                      ),
                    ],
                    if (role == 'parent') ...[
                      const SizedBox(height: 10),
                      const Align(alignment: Alignment.centerRight, child: Text('فرزند(ان) این ولی:', style: TextStyle(fontWeight: FontWeight.bold))),
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
                                      value: selected.contains(s.id),
                                      title: Text('${s.name} • ${s.className}', style: const TextStyle(fontSize: 13)),
                                      onChanged: (v) => setD(() => v == true ? selected.add(s.id) : selected.remove(s.id)),
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
                child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('ساخت حساب'),
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
