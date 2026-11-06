import 'package:flutter/material.dart';
import '../models/permissions.dart';
import '../models/user_directory.dart';
import '../services/backend.dart';
import '../services/backend_directory.dart';
import '../utils/jalali.dart';

class _ArchivedItem {
  final bool isStudent;
  final String id;
  final String name;
  final String detail;
  final String deletedAt;

  const _ArchivedItem({
    required this.isStudent,
    required this.id,
    required this.name,
    required this.detail,
    required this.deletedAt,
  });
}

/// بایگانی: کاربران و نوآموزان حذف‌شده، با امکان بازیابی
class ManagerArchivePage extends StatefulWidget {
  const ManagerArchivePage({super.key});

  @override
  State<ManagerArchivePage> createState() => _ManagerArchivePageState();
}

class _ManagerArchivePageState extends State<ManagerArchivePage> {
  static const Color _navy = Color(0xFF01579B);
  bool _loading = true;
  String? _error;
  List<_ArchivedItem> _items = [];

  bool get _allowed => PermissionService.instance.can(Session.role, Perm.manageUsers);

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _date(dynamic v) {
    if (v is! String) return '—';
    final d = DateTime.tryParse(v);
    if (d == null) return '—';
    return faDigits(JalaliDate.fromDateTime(d.toLocal()).formatted);
  }

  Future<void> _load() async {
    if (!Backend.ready || !_allowed) {
      setState(() {
        _loading = false;
        _error = 'دسترسی به بایگانی فعال نیست.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final students = await Backend.client
          .from('students')
          .select('id, full_name, deleted_at, classes(name)')
          .eq('is_deleted', true)
          .order('deleted_at', ascending: false);
      final profiles = await Backend.client
          .from('profiles')
          .select('id, full_name, role, phone, deleted_at')
          .eq('is_deleted', true)
          .order('deleted_at', ascending: false);

      final items = <_ArchivedItem>[];
      for (final r in students) {
        final row = Map<String, dynamic>.from(r);
        final cls = row['classes'];
        items.add(_ArchivedItem(
          isStudent: true,
          id: '${row['id']}',
          name: '${row['full_name'] ?? ''}',
          detail: 'نوآموز • ${cls is Map ? '${cls['name'] ?? ''}' : ''}',
          deletedAt: _date(row['deleted_at']),
        ));
      }
      for (final r in profiles) {
        final row = Map<String, dynamic>.from(r);
        items.add(_ArchivedItem(
          isStudent: false,
          id: '${row['id']}',
          name: '${row['full_name'] ?? ''}',
          detail: '${row['role'] ?? ''} • ${row['phone'] ?? ''}',
          deletedAt: _date(row['deleted_at']),
        ));
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _restore(_ArchivedItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('بازیابی'),
          content: Text(item.isStudent
              ? 'نوآموز «${item.name}» دوباره در فهرست‌ها دیده می‌شود. حساب ورود قبلی او بازیابی نمی‌شود؛ در صورت نیاز حساب جدید بسازید.'
              : 'حساب «${item.name}» دوباره فعال می‌شود.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('بازیابی')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      if (item.isStudent) {
        final rows = await Backend.client
            .from('students')
            .update({'is_deleted': false, 'deleted_at': null})
            .eq('id', item.id)
            .select('id');
        if (rows.isEmpty) throw StateError('رکورد پیدا نشد یا اجازهٔ بازیابی ندارید.');
        // حساب ورود بایگانی‌شدهٔ قبلی جدا شود تا ساخت حساب جدید ممکن باشد
        await Backend.client
            .from('profiles')
            .update({'student_id': null})
            .eq('is_deleted', true)
            .eq('student_id', item.id);
      } else {
        final rows = await Backend.client
            .from('profiles')
            .update({'is_deleted': false, 'deleted_at': null, 'active': true})
            .eq('id', item.id)
            .select('id');
        if (rows.isEmpty) throw StateError('حساب پیدا نشد یا اجازهٔ بازیابی ندارید.');
      }
      UserDirectory.clearCache();
      ServerDirectory.reset();
      _snack('✅ بازیابی انجام شد', Colors.green);
      await _load();
    } catch (e) {
      _snack('بازیابی انجام نشد: ${'$e'.replaceFirst('Bad state: ', '')}', Colors.red);
    }
  }

  Future<void> _hardDelete(_ArchivedItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف کامل'),
          content: Text(
            '«${item.name}» برای همیشه حذف می‌شود و هیچ راهی برای برگرداندن آن نیست. '
            'آیا مطمئن هستید؟',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف کامل'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      await Backend.client.rpc('hard_delete_archived', params: {
        'p_kind': item.isStudent ? 'student' : 'profile',
        'p_id': item.id,
      });
      UserDirectory.clearCache();
      ServerDirectory.reset();
      _snack('✅ برای همیشه حذف شد', Colors.green);
      await _load();
    } catch (e) {
      _snack('حذف کامل انجام نشد: ${'$e'.replaceFirst('Bad state: ', '')}', Colors.red);
    }
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)));
    }
    if (_items.isEmpty) {
      return const Center(child: Text('بایگانی خالی است.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final item = _items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              child: Icon(item.isStudent ? Icons.child_care_rounded : Icons.person_rounded, color: Colors.grey),
            ),
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${item.detail}\nحذف شده: ${item.deletedAt}'),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () => _restore(item),
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('بازیابی'),
                ),
                IconButton(
                  tooltip: 'حذف کامل',
                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                  onPressed: () => _hardDelete(item),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Text('بایگانی'),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        body: _body(),
      ),
    );
  }
}
