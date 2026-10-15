import '../widgets/illustration_banner.dart';
import 'package:flutter/material.dart';
import '../models/permissions.dart';

/// صفحهٔ تنظیم سطح دسترسی نقش‌ها (فقط مدیر)
class ManagerPermissionsPage extends StatelessWidget {
  const ManagerPermissionsPage({super.key});

  static const Color _navy = Color(0xFF01579B);

  Widget _scopeDropdown(PermissionService service, AppRole role, Perm perm, List<Scope> options) {
    final current = service.scopeOf(role, perm);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: role.label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Scope>(
          value: options.contains(current) ? current : Scope.none,
          isDense: true,
          isExpanded: true,
          items: [
            for (final s in options)
              DropdownMenuItem(value: s, child: Text(s.labelFor(role), style: const TextStyle(fontSize: 13))),
          ],
          onChanged: (v) {
            if (v != null) service.setScope(role, perm, v);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = PermissionService.instance;
    const groups = ['آموزشی', 'نظارت', 'مدیریتی'];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Text('سطح دسترسی‌ها'),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'بازگشت به پیش‌فرض',
              icon: const Icon(Icons.restore_rounded),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: AlertDialog(
                      title: const Text('بازگشت به پیش‌فرض؟'),
                      content: const Text('همهٔ تغییرات دسترسی معاون و مربی به حالت اولیه برمی‌گردد.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('بازگردانی')),
                      ],
                    ),
                  ),
                );
                if (ok == true) await service.resetToDefaults();
              },
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: service,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                const IllustrationBanner(
                  image: 'ill_management.png',
                  title: 'سطح دسترسی‌ها',
                  subtitle: 'تعیین کنید هر نقش چه کارهایی را و روی چه دامنه‌ای انجام دهد.',
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F5FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_rounded, color: _navy),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'مدیر همیشه دسترسی کامل دارد. ولی فقط به اطلاعات فرزند خودش دسترسی دارد و قابل تغییر نیست. '
                          'برای هر مورد، «دامنه» را تعیین کنید: ندارد، کلاس خودش، یا همه. '
                          'هر تغییر در «گزارش تغییرات» ثبت می‌شود.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final g in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                    child: Text(g, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navy)),
                  ),
                  for (final entry in kPermInfo.entries.where((e) => e.value.group == g))
                    Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(entry.value.icon, color: _navy),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(entry.value.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(entry.value.description, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                for (int i = 0; i < kConfigurableRoles.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 10),
                                  Expanded(
                                    child: _scopeDropdown(service, kConfigurableRoles[i], entry.key, entry.value.scopes),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
