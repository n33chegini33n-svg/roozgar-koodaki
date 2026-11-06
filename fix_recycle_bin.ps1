python -c "
# 1. Update registration_manager_page.dart (Add Recycle Bin filter & Restore button)
with open('lib/pages/registration_manager_page.dart', 'r', encoding='utf-8') as f:
    m = f.read()

# Add Recycle Bin to filters
old_filters = \"'همه پرونده‌ها', 'در انتظار بررسی', 'تأیید شده', 'عدم تأیید / نیاز به اصلاح'\"
new_filters = \"'همه پرونده‌ها', 'در انتظار بررسی', 'تأیید شده', 'عدم تأیید / نیاز به اصلاح', '🗑️ سطل بازیافت (حذف‌شده‌ها)'\"
if old_filters in m:
    m = m.replace(old_filters, new_filters)

# In filter logic, handle recycle bin
old_filter_logic = \"final isStatusMatch = _selectedStatusFilter == 'همه پرونده‌ها' ||\"
new_filter_logic = \"\"\"final isRecycle = _selectedStatusFilter == '🗑️ سطل بازیافت (حذف‌شده‌ها)';
      final isDeleted = rec['is_deleted'] == true;
      if (isRecycle) {
        if (!isDeleted) return false;
      } else {
        if (isDeleted) return false;
      }
      final isStatusMatch = _selectedStatusFilter == 'همه پرونده‌ها' || isRecycle ||\"\"\"

if old_filter_logic in m and 'isRecycle' not in m:
    m = m.replace(old_filter_logic, new_filter_logic, 1)

# In _load, don't throw away deleted rows so recycle bin can see them
old_filter_rows = \"final rows = allRows.where((r) => r['is_deleted'] != true).toList();\"
if old_filter_rows in m:
    m = m.replace(old_filter_rows, \"final rows = allRows;\")

with open('lib/pages/registration_manager_page.dart', 'w', encoding='utf-8') as f:
    f.write(m)
print('Manager Recycle Bin ready!')

# 2. Update registration_page.dart (Hide deleted from parent, put trash icon directly on child chip)
with open('lib/pages/registration_page.dart', 'r', encoding='utf-8') as f:
    p = f.read()

# In ChoiceChip row, put the red trash icon right inside/next to each child chip
old_chip_item = \"label: Text('${child.studentName} • ${_statusLabel(child.status)}'),\"
new_chip_item = \"\"\"label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${child.studentName} • ${_statusLabel(child.status)}'),
                        if (child.status != 'approved') ...[
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _deleteSpecificChild(child),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                          ),
                        ],
                      ],
                    ),\"\"\"

if old_chip_item in p:
    p = p.replace(old_chip_item, new_chip_item, 1)

# Add _deleteSpecificChild
del_spec = \"\"\"
  void _deleteSpecificChild(dynamic child) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('⚠️ حذف پرونده فرزند'),
          content: Text('آیا از حذف پرونده «${child.studentName}» اطمینان دارید؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                if (Backend.ready) {
                  try {
                    await Backend.client.from('registration_records').update({'is_deleted': true, 'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', child.id);
                  } catch (_) {}
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('پرونده با موفقیت به سطل زباله منتقل شد 🗑️')),
                );
                setState(() {
                  _children.removeWhere((c) => c.studentName == child.studentName);
                });
              },
              child: const Text('حذف پرونده'),
            ),
          ],
        ),
      ),
    );
  }
\"\"\"
if '_deleteSpecificChild' not in p:
    last_b = p.rfind('}')
    p = p[:last_b] + del_spec + \"\n}\n\"

with open('lib/pages/registration_page.dart', 'w', encoding='utf-8') as f:
    f.write(p)
print('Parent child chips with trash icon ready!')
"
