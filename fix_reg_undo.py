with open('lib/pages/registration_manager_page.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Filter out deleted records in _load
old_load = """      final rows = await Backend.client
          .from('registration_records')
          .select('*')
          .order('updated_at', ascending: false);"""

new_load = """      final allRows = await Backend.client
          .from('registration_records')
          .select('*')
          .order('updated_at', ascending: false);
      final rows = allRows.where((r) => r['is_deleted'] != true).toList();"""

if old_load in code:
    code = code.replace(old_load, new_load)
    print("Fixed: Filtered out deleted records from manager view")

# 2. Implement full Delete with Undo button on registration page
old_del_method = """  void _deleteRegistrationRecord(Map<String, dynamic> record) {"""

new_del_method = """  Future<void> _restoreRegistrationRecord(Map<String, dynamic> record) async {
    final recId = '${record['id']}';
    try {
      if (Backend.ready) {
        await Backend.client.from('registration_records').update({
          'is_deleted': false,
          'deleted_at': null,
        }).eq('id', recId);
      }
      await AuditLogService.log(
        actor: Session.userName,
        role: Session.role.label,
        action: 'بازیابی پرونده ثبت‌نام',
        details: 'پرونده نوآموز مجدداً از سطل زباله بازیابی شد ↩️',
      );
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پرونده با موفقیت بازگردانده شد ↩️'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {}
  }

  void _deleteRegistrationRecord(Map<String, dynamic> record) {
    final data = record['data'] is Map ? Map<String, dynamic>.from(record['data'] as Map) : <String, dynamic>{};
    final studentName = '${data['نام نوآموز'] ?? data['نام'] ?? record['student_name'] ?? 'نوآموز'} ${data['نام خانوادگی'] ?? ''}'.trim();
    final recId = '${record['id']}';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('⚠️ حذف پرونده ثبت‌نام'),
          content: Text('آیا از حذف پرونده نوآموز «$studentName» اطمینان دارید؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  if (Backend.ready) {
                    await Backend.client.from('registration_records').update({
                      'is_deleted': true,
                      'deleted_at': DateTime.now().toUtc().toIso8601String(),
                    }).eq('id', recId);
                  }
                  await AuditLogService.log(
                    actor: Session.userName,
                    role: Session.role.label,
                    action: 'حذف پرونده ثبت‌نام',
                    details: 'نوآموز: $studentName (به سطل زباله منتقل شد)',
                  );
                  setState(() {
                    _records.removeWhere((r) => '${r['id']}' == recId);
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 8),
                        backgroundColor: const Color(0xFF263238),
                        content: Text('پرونده «$studentName» حذف شد 🗑️'),
                        action: SnackBarAction(
                          label: 'بازگردانی ↩️',
                          textColor: Colors.amber,
                          onPressed: () => _restoreRegistrationRecord(record),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطا در حذف پرونده: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('حذف پرونده'),
            ),
          ],
        ),
      ),
    );
    return;
  }

  void _origDeleteReg(Map<String, dynamic> record) {"""

if old_del_method in code and "_restoreRegistrationRecord" not in code:
    code = code.replace(old_del_method, new_del_method, 1)
    print("Fixed: Added Undo button and real-time screen removal")

with open('lib/pages/registration_manager_page.dart', 'w', encoding='utf-8') as f:
    f.write(code)

print("Registration Page Undo system is ready!")
