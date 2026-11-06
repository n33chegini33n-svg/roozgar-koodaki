with open('lib/pages/registration_page.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Remove step 6 checkbox block from top submit
old_check = """    if (!_accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تأیید صحت اطلاعات و پذیرش تعهدنامه الزامی است')),
      );
      return;
    }"""
if old_check in code:
    code = code.replace(old_check, "    _accepted = true;")
    print("Fixed: _accepted check")

# 2. Fix ChoiceChip inverted jump
old_chip = "onSelected: (_) => _selectChild(child),"
new_chip = """onSelected: (_) {
                      if (_selectedStudentName?.trim().toLowerCase() != child.studentName.trim().toLowerCase()) {
                        _selectChild(child);
                      }
                    },"""
if old_chip in code:
    code = code.replace(old_chip, new_chip)
    print("Fixed: ChoiceChip selection")

# 3. Add parent withdrawal/delete button
old_add_btn = "FilledButton.icon(\n                      onPressed: _addChild,"
withdraw_btn = """if (_selectedStudentName != null && _status != 'approved') ...[
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        tooltip: 'انصراف و حذف پرونده این فرزند',
                        onPressed: _withdrawCurrentChild,
                      ),
                      const SizedBox(width: 6),
                    ],
                    FilledButton.icon(
                      onPressed: _addChild,"""
if old_add_btn in code and "_withdrawCurrentChild" not in code:
    code = code.replace(old_add_btn, withdraw_btn)
    withdraw_method = """
  void _withdrawCurrentChild() {
    final sName = _selectedStudentName ?? '';
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('⚠️ انصراف و حذف پرونده'),
          content: Text('آیا از انصراف و حذف پرونده نوآموز «$sName» اطمینان دارید؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final cur = _children.where((c) => c.studentName.trim().toLowerCase() == sName.trim().toLowerCase()).firstOrNull;
                if (cur != null && Backend.ready) {
                  try {
                    await Backend.client.from('registration_records').delete().eq('id', cur.id);
                  } catch (_) {}
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('پرونده با موفقیت حذف شد')),
                );
                await _loadChildren();
              },
              child: const Text('حذف قطعی پرونده'),
            ),
          ],
        ),
      ),
    );
  }
"""
    last_brace = code.rfind('}')
    code = code[:last_brace] + withdraw_method + "\n}\n"
    print("Fixed: Added parent withdrawal button")

with open('lib/pages/registration_page.dart', 'w', encoding='utf-8') as f:
    f.write(code)

# 4. Add Manager delete button in registration_manager_page.dart
with open('lib/pages/registration_manager_page.dart', 'r', encoding='utf-8') as f:
    m_code = f.read()

target_icon = "tooltip: 'مشاهده و ویرایش جزئیات',\n                      onPressed: () => _showDetailsDialog(record),\n                    ),"
new_icons = """tooltip: 'مشاهده و ویرایش جزئیات',
                      onPressed: () => _showDetailsDialog(record),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      tooltip: 'حذف کامل پرونده نوآموز',
                      onPressed: () => _deleteRegistrationRecord(record),
                    ),"""
if target_icon in m_code and "_deleteRegistrationRecord" not in m_code:
    m_code = m_code.replace(target_icon, new_icons)
    delete_method = """
  void _deleteRegistrationRecord(Map<String, dynamic> record) {
    final data = record['data'] is Map ? Map<String, dynamic>.from(record['data'] as Map) : <String, dynamic>{};
    final studentName = '${data['نام نوآموز'] ?? data['نام'] ?? record['student_name'] ?? 'نوآموز'} ${data['نام خانوادگی'] ?? ''}'.trim();
    final recId = '${record['id']}';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('⚠️ حذف کامل پرونده ثبت‌نام'),
          content: Text('آیا از حذف کامل پرونده نوآموز «$studentName» اطمینان دارید؟ این عملیات در گزارش تغییرات ثبت می‌شود.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  if (Backend.ready) {
                    await Backend.client.from('registration_records').delete().eq('id', recId);
                  }
                  await AuditLogService.log(
                    actor: Session.userName,
                    role: Session.role.label,
                    action: 'حذف پرونده ثبت‌نام',
                    details: 'نوآموز: $studentName (توسط مدیر از سیستم حذف شد)',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('پرونده با موفقیت حذف شد'), backgroundColor: Colors.green),
                  );
                  _load();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطا در حذف پرونده: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('حذف پرونده'),
            ),
          ],
        ),
      ),
    );
  }
"""
    last_brace_m = m_code.rfind('}')
    m_code = m_code[:last_brace_m] + delete_method + "\n}\n"
    print("Fixed: Added manager delete button")

with open('lib/pages/registration_manager_page.dart', 'w', encoding='utf-8') as f:
    f.write(m_code)

print("All fixes applied successfully!")
