import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sup;
import '../models/user_directory.dart';
import '../services/backend.dart';

/// انتقال حساب: حساب قبلی غیرفعال می‌شود و حساب جدید با شماره و کد جدید ساخته می‌شود.
/// فرزندان، کلاس‌ها و اتصال نوآموز به حساب جدید منتقل می‌شوند.
Future<bool> showTransferAccountDialog(BuildContext context, UserModel user) async {
  if (!Backend.ready || user.profileId == null) return false;

  final phone = TextEditingController();
  final code = TextEditingController(text: (100000 + math.Random.secure().nextInt(900000)).toString());
  var busy = false;
  String? error;

  final done = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        Future<void> submit() async {
          final cleanPhone = phone.text.trim();
          final pass = code.text.trim();
          if (cleanPhone.isEmpty) {
            setD(() => error = 'شمارهٔ همراه جدید را وارد کنید');
            return;
          }
          if (pass.length != 6) {
            setD(() => error = 'کد ورود باید ۶ رقم باشد');
            return;
          }
          setD(() {
            busy = true;
            error = null;
          });
          try {
            final res = await Backend.client.functions.invoke('transfer-account', body: {
              'old_profile_id': user.profileId,
              'phone': cleanPhone,
              'password': pass,
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
              error = d is Map && d['error'] != null ? '${d['error']}' : 'انتقال ناموفق بود';
            });
          } catch (_) {
            setD(() {
              busy = false;
              error = 'ارتباط با سرور برقرار نشد';
            });
          }
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('انتقال حساب: ${user.name}'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حساب فعلی (${user.phone}) غیرفعال می‌شود. فرزندان، کلاس‌ها و نوآموز متصل، به حساب جدید منتقل می‌شوند.',
                      style: const TextStyle(fontSize: 12, height: 1.6),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(labelText: 'شمارهٔ همراه جدید', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: 'کد ورود جدید (۶ رقم)',
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
                    : const Text('انتقال'),
              ),
            ],
          ),
        );
      },
    ),
  );

  if (done == true && context.mounted) {
    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('انتقال انجام شد'),
          content: SelectableText('شمارهٔ جدید: ${phone.text.trim()}\nکد ورود جدید: ${code.text.trim()}\n\nاین دو را به کاربر بدهید.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('بسیار خوب'))],
        ),
      ),
    );
  }
  return done == true;
}
