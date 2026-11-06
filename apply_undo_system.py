# 1. Update lib/pages/manager_user_management_page.dart
with open('lib/pages/manager_user_management_page.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# Make sure delete button is active for all users and has Undo
old_delete_block = """                IconButton(
                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                  tooltip: 'حذف کاربر',
                  onPressed: () => _deleteUser(u.id),
                ),"""

# In _deleteUser, implement Soft Delete with Undo
old_delete_func = """  void _deleteUser(String id) {"""

new_delete_func = """  Future<void> _restoreUser(UserModel u) async {
    try {
      if (Backend.ready) {
        if (u.role == 'student') {
          await Backend.client.from('students').update({'is_deleted': false, 'deleted_at': null}).eq('id', u.id);
        } else {
          await Backend.client.from('profiles').update({'is_deleted': false, 'deleted_at': null}).eq('id', u.id);
        }
      }
      await AuditLogService.log(
        actor: Session.userName,
        role: Session.role.label,
        action: 'بازیابی کاربر حذف‌شده',
        details: 'کاربر ${u.name} با نقش ${_roleLabel(u.role)} به سیستم بازگردانده شد ↩️',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('کاربر ${u.name} با موفقیت بازگردانده شد ↩️'), backgroundColor: Colors.green),
        );
      }
      UserDirectory.clearCache();
      ServerDirectory.reset();
      _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بازیابی کاربر: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _deleteUser(String id) {
    final target = _users.where((u) => u.id == id).firstOrNull;
    if (target == null) return;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('⚠️ حذف کاربر'),
          content: Text('آیا از حذف «${target.name}» (${_roleLabel(target.role)}) اطمینان دارید؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  if (Backend.ready) {
                    if (target.role == 'student') {
                      await Backend.client.from('students').update({'is_deleted': true, 'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
                    } else {
                      await Backend.client.from('profiles').update({'is_deleted': true, 'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
                    }
                  }
                  await AuditLogService.log(
                    actor: Session.userName,
                    role: Session.role.label,
                    action: 'حذف کاربر از سیستم',
                    details: 'کاربر ${target.name} • نقش: ${_roleLabel(target.role)} • تلفن: ${target.phone}',
                  );
                  setState(() {
                    _users.removeWhere((u) => u.id == id);
                  });
                  UserDirectory.clearCache();
                  ServerDirectory.reset();

                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 7),
                        backgroundColor: const Color(0xFF263238),
                        content: Text('کاربر «${target.name}» حذف شد 🗑️'),
                        action: SnackBarAction(
                          label: 'بازگردانی ↩️',
                          textColor: Colors.amber,
                          onPressed: () => _restoreUser(target),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطا در حذف کاربر: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('حذف کاربر'),
            ),
          ],
        ),
      ),
    );
    return;
  }

  void _origDeleteUser(String id) {"""

if old_delete_func in code and "_restoreUser" not in code:
    code = code.replace(old_delete_func, new_delete_func, 1)
    print("Fixed: Added Undo & Soft-Delete to manager_user_management_page.dart")

with open('lib/pages/manager_user_management_page.dart', 'w', encoding='utf-8') as f:
    f.write(code)

# 2. Update lib/pages/registration_manager_page.dart for Undo on registration deletion
with open('lib/pages/registration_manager_page.dart', 'r', encoding='utf-8') as f:
    m_code = f.read()

old_reg_del = """                  if (Backend.ready) {
                    await Backend.client.from('registration_records').delete().eq('id', recId);
                  }"""

new_reg_del = """                  if (Backend.ready) {
                    await Backend.client.from('registration_records').update({'is_deleted': true, 'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', recId);
                  }"""

if old_reg_del in m_code:
    m_code = m_code.replace(old_reg_del, new_reg_del)
    print("Fixed: Soft-delete in registration_manager_page.dart")

with open('lib/pages/registration_manager_page.dart', 'w', encoding='utf-8') as f:
    f.write(m_code)

print("All Undo systems applied successfully!")
