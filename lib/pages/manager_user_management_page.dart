import 'package:flutter/material.dart';
import '../utils/export_helper.dart';
import '../models/audit_log_model.dart';
import '../services/backend.dart';
import '../services/backend_directory.dart';
import '../services/user_admin_service.dart';
import 'create_account_dialog.dart';
import 'transfer_account_dialog.dart';
import 'manager_archive_page.dart';
import '../models/permissions.dart';
import '../models/user_directory.dart';
import '../models/school_classes.dart';


class ManagerUserManagementPage extends StatefulWidget {
  const ManagerUserManagementPage({super.key});

  @override
  State<ManagerUserManagementPage> createState() => _ManagerUserManagementPageState();
}

class _ManagerUserManagementPageState extends State<ManagerUserManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _hasAccess = true;
  String? _loadError;
  final Set<String> _activeBusyIds = {};
  List<UserModel> _users = [];
  String _searchQuery = '';
  String _selectedClassFilter = 'همه کلاس‌ها';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!PermissionService.instance.can(Session.role, Perm.manageUsers)) {
      if (!mounted) return;
      setState(() {
        _users = [];
        _isLoading = false;
        _hasAccess = false;
      });
      return;
    }
    try {
      final list = await UserDirectory.load();
      if (!mounted) return;
      setState(() {
        _users = List<UserModel>.from(list);
        _loadError = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'بارگذاری کاربران انجام نشد: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUsers() => UserDirectory.save(_users);

  void _showAddUserDialog({UserModel? editUser}) {
    final pageContext = context;
    if (!PermissionService.instance.can(Session.role, Perm.manageUsers)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شما اجازهٔ مدیریت کاربران را ندارید'), backgroundColor: Colors.red),
      );
      return;
    }
    if (Backend.ready && editUser != null) {
      _showServerEditDialog(editUser);
      return;
    }
    if (Backend.ready && editUser == null) {
      // ساخت حساب واقعی با تابع سمت سرور
      showCreateAccountDialog(pageContext).then((created) {
        if (created) {
          UserDirectory.clearCache();
          ServerDirectory.reset();
          _loadUsers();
        }
      });
      return;
    }
    final nameCtrl = TextEditingController(text: editUser?.name ?? '');
    final phoneCtrl = TextEditingController(text: editUser?.phone ?? '');

    const grades = [
      'مهدکودک 👶',
      'پیش‌دبستانی 🎨',
      'اول دبستان ✏️',
      'دوم دبستان 📖',
      'سوم دبستان 📘',
      'چهارم دبستان 📐',
      'پنجم دبستان 🔬',
      'ششم دبستان 🎓',
    ];
    String selectedGrade = grades[1]; // default to پیش‌دبستانی

    String selectedRole = editUser?.role ?? 'parent';

    final availableClasses = Backend.ready && ServerDirectory.classList.isNotEmpty
        ? ServerDirectory.classList.map((entry) => entry.key).toList()
        : kClassNames;
    final validClasses = [...availableClasses, 'والدین و اولیاء', 'مدیریت'];
    String selectedClass = (editUser != null && validClasses.contains(normalizeClassName(editUser.className)))
        ? normalizeClassName(editUser.className)
        : availableClasses.first;
    final studentNames = _users.where((u) => u.role == 'student').map((u) => u.name).toList();
    String linkedStudent = (editUser != null && studentNames.contains(editUser.linkedStudent))
        ? editUser.linkedStudent
        : (studentNames.isEmpty ? '' : studentNames.first);
    bool isSaving = false;
    String? saveError;

    showDialog(
      context: pageContext,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(editUser == null ? '➕ ثبت‌نام / افزودن کاربر جدید' : '✏️ ویرایش مشخصات کاربر'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'نام و نام خانوادگی', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'دوره / مقطع تحصیلی', border: OutlineInputBorder()),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedGrade,
                          isDense: true,
                          isExpanded: true,
                          items: [
                            for (final g in grades) DropdownMenuItem(value: g, child: Text(g)),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              selectedGrade = val!;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        return InputDecorator(
                          decoration: const InputDecoration(labelText: 'نقش کاربر', border: OutlineInputBorder()),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedRole,
                              isDense: true,
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(value: 'student', child: Text('دانش‌آموز (حساب مستقل) 🎒')),
                                const DropdownMenuItem(value: 'parent', child: Text('اولیاء / والدین 👨‍👩‍👦')),
                                const DropdownMenuItem(value: 'teacher', child: Text('مربی / معلم 👩‍🏫')),
                                const DropdownMenuItem(value: 'deputy', child: Text('معاون / ناظم 🧑‍💼')),
                                if (editUser?.role == 'manager' || Session.role == AppRole.admin)
                                  const DropdownMenuItem(value: 'manager', child: Text('مدیر')),
                                if (editUser?.role == 'admin')
                                  const DropdownMenuItem(value: 'admin', child: Text('ادمین سیستم')),
                              ],
                                  onChanged: Backend.ready && editUser?.isStudentRecord == true
                                  ? null
                                  : (val) => setDialogState(() => selectedRole = val!),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'کلاس / بخش مربوطه', border: OutlineInputBorder()),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedClass,
                          isDense: true,
                          isExpanded: true,
                          items: [
                            for (final c in availableClasses) DropdownMenuItem(value: c, child: Text(classLabel(c))),
                            if (selectedRole != 'student') ...[
                              const DropdownMenuItem(value: 'والدین و اولیاء', child: Text('والدین و اولیاء')),
                              const DropdownMenuItem(value: 'مدیریت', child: Text('مدیریت')),
                            ],
                          ],
                          onChanged: (val) => setDialogState(() => selectedClass = val!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'شماره تماس / همراه', border: OutlineInputBorder()),
                    ),
                    if (!Backend.ready && selectedRole == 'parent' && studentNames.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: const InputDecoration(labelText: 'فرزند این ولی', border: OutlineInputBorder()),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: linkedStudent,
                            isDense: true,
                            isExpanded: true,
                            items: [for (final n in studentNames) DropdownMenuItem(value: n, child: Text(n))],
                            onChanged: (val) => setDialogState(() => linkedStudent = val ?? linkedStudent),
                          ),
                        ),
                      ),
                    ],
                    if (saveError != null) ...[
                      const SizedBox(height: 10),
                      Text(saveError!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white),
                onPressed: isSaving ? null : () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final isEdit = editUser != null;
                  final updatedUser = (editUser ?? UserModel(
                    id: 'U-${DateTime.now().millisecondsSinceEpoch}',
                    name: '',
                    role: selectedRole,
                    className: selectedClass,
                    phone: '',
                  )).copyWith(
                    name: nameCtrl.text.trim(),
                    role: selectedRole,
                    className: selectedClass,
                    phone: phoneCtrl.text.trim(),
                    linkedStudent: selectedRole == 'parent' ? linkedStudent : '',
                  );

                  if (Backend.ready && editUser != null) {
                    setDialogState(() {
                      isSaving = true;
                      saveError = null;
                    });
                    try {
                      await UserAdminService.updateUser(
                        previous: editUser,
                        name: updatedUser.name,
                        phone: updatedUser.phone,
                        role: updatedUser.role,
                        className: updatedUser.className,
                      );
                      await AuditLogService.log(
                        actor: Session.userName,
                        role: Session.role.label,
                        action: 'ویرایش کاربر',
                        details: 'قبلی: ${editUser.name} • ${editUser.role} • ${editUser.phone} • ${editUser.className} '
                            '← جدید: ${updatedUser.name} • ${updatedUser.role} • ${updatedUser.phone} • ${updatedUser.className}',
                      );
                      UserDirectory.clearCache();
                      ServerDirectory.reset();
                      await _loadUsers();
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (pageContext.mounted) {
                        ScaffoldMessenger.of(pageContext).showSnackBar(
                          const SnackBar(content: Text('اطلاعات کاربر در سرور به‌روزرسانی شد.'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        setDialogState(() {
                          isSaving = false;
                          saveError = 'ذخیره‌سازی انجام نشد: $e';
                        });
                      }
                    }
                    return;
                  }

                  if (isEdit) {
                    final idx = _users.indexWhere((u) => u.id == editUser.id);
                    if (idx != -1) _users[idx] = updatedUser;
                  } else {
                    _users.add(updatedUser);
                  }
                  await _saveUsers();
                  await AuditLogService.log(
                    actor: Session.userName,
                    role: Session.role.label,
                    action: isEdit ? 'ویرایش کاربر' : 'افزودن کاربر',
                    details: isEdit
                        ? 'قبلی: ${editUser.name} • ${editUser.role} • ${editUser.phone} • ${editUser.className} '
                            '← جدید: ${updatedUser.name} • ${updatedUser.role} • ${updatedUser.phone} • ${updatedUser.className}'
                        : '${updatedUser.name} • نقش: ${updatedUser.role} • ${updatedUser.className}',
                  );
                  if (mounted) setState(() {});
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (pageContext.mounted) {
                    ScaffoldMessenger.of(pageContext).showSnackBar(
                      const SnackBar(content: Text('اطلاعات کاربر با موفقیت ذخیره شد.'), backgroundColor: Colors.green),
                    );
                  }
                },
                child: Text(isSaving ? 'در حال ذخیره...' : 'ذخیره و ثبت'),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _showServerEditDialog(UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);
    final classes = ServerDirectory.classList;
    final isStudentRecord = user.isStudentRecord;
    String role = user.role;
    String? className = classes.any((c) => c.key == user.className) ? user.className : null;
    final selectedIds = <String>{...user.classIds};
    bool busy = false;
    String? error;

    final roles = <String, String>{
      if (Session.role == AppRole.admin) 'manager': 'مدیر',
      'deputy': 'معاون / ناظم',
      'teacher': 'مربی / معلم',
      'parent': 'ولی',
      'student': 'دانش‌آموز',
    };

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          Future<void> save() async {
            setD(() {
              busy = true;
              error = null;
            });
            try {
              await UserAdminService.updateUser(
                previous: user,
                name: nameCtrl.text,
                phone: phoneCtrl.text,
                role: role,
                className: className ?? '',
                classIds: selectedIds.toList(),
              );
              UserDirectory.clearCache();
              ServerDirectory.reset();
              if (ctx.mounted) Navigator.pop(ctx);
              await _loadUsers();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ اطلاعات کاربر ذخیره شد'), backgroundColor: Colors.green),
                );
              }
            } catch (e) {
              setD(() {
                busy = false;
                error = '$e'.replaceFirst('Bad state: ', '');
              });
            }
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('ویرایش مشخصات کاربر'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'نام و نام خانوادگی',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'شمارهٔ همراه',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: roles.containsKey(role) ? role : null,
                        decoration: const InputDecoration(
                          labelText: 'نقش کاربر',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final e in roles.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                        ],
                        onChanged: (isStudentRecord || busy) ? null : (v) => setD(() => role = v ?? role),
                      ),
                      const SizedBox(height: 10),
                      if (role == 'teacher' || role == 'deputy') ...[
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text('کلاس‌های این کادر (می‌توانید چند کلاس انتخاب کنید):',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (final c in classes)
                                CheckboxListTile(
                                  dense: true,
                                  value: selectedIds.contains(c.value),
                                  title: Text(c.key, style: const TextStyle(fontSize: 13)),
                                  onChanged: busy
                                      ? null
                                      : (v) => setD(() => v == true ? selectedIds.add(c.value) : selectedIds.remove(c.value)),
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (role != 'teacher' && role != 'deputy')
                      DropdownButtonFormField<String>(
                        initialValue: className,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'کلاس / بخش',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final c in classes)
                            DropdownMenuItem(value: c.key, child: Text(c.key, overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: busy ? null : (v) => setD(() => className = v),
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
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(ctx),
                  child: const Text('انصراف'),
                ),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('ذخیره'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteUser(String id) async {
    if (!PermissionService.instance.can(Session.role, Perm.manageUsers)) return;
    final user = _users.where((item) => item.id == id).firstOrNull;
    if (user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('⚠️ حذف کاربر'),
          content: const Text('آیا از حذف این کاربر از سیستم اطمینان دارید؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      if (Backend.ready) {
        await UserAdminService.deleteUser(user);
      } else {
        _users.removeWhere((item) => item.id == id);
        await _saveUsers();
      }
      await AuditLogService.log(
        actor: Session.userName,
        role: Session.role.label,
        action: 'حذف کاربر',
        details: 'نام: ${user.name} • نقش: ${user.role} • شناسه: ${user.id}',
      );
      if (Backend.ready) {
        UserDirectory.clearCache();
        ServerDirectory.reset();
        await _loadUsers();
      } else if (mounted) {
        setState(() {});
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('کاربر از فهرست سامانه حذف شد.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حذف کاربر انجام نشد: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _setUserActive(UserModel user, bool active) async {
    final busyKey = user.profileId ?? user.id;
    if (_activeBusyIds.contains(busyKey)) return;
    setState(() => _activeBusyIds.add(busyKey));
    var updated = false;
    try {
      await UserAdminService.setActive(user, active);
      updated = true;
      UserDirectory.clearCache();
      await _loadUsers();
      await AuditLogService.log(
        actor: Session.userName,
        role: Session.role.label,
        action: active ? 'فعال‌سازی حساب کاربر' : 'غیرفعال‌سازی حساب کاربر',
        details: 'شناسهٔ پروفایل: $busyKey',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updated ? 'وضعیت حساب تغییر کرد، اما ثبت گزارش انجام نشد: $e' : 'تغییر وضعیت حساب انجام نشد: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _activeBusyIds.remove(busyKey));
    }
  }

  List<UserModel> _filterUserList(List<UserModel> baseList) {
    return baseList.where((u) {
      if (_selectedClassFilter != 'همه کلاس‌ها' && u.className != _selectedClassFilter) {
        return false;
      }

      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();

      return u.name.toLowerCase().contains(q) ||
          u.phone.toLowerCase().contains(q) ||
          u.className.toLowerCase().contains(q) ||
          u.linkedStudent.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAccess) {
      return const Scaffold(body: Center(child: Text('شما اجازهٔ مدیریت کاربران را ندارید')));
    }
    List<UserModel> students = _filterUserList(_users.where((u) => u.role == 'student').toList());
    List<UserModel> teachers = _filterUserList(_users.where((u) => u.role == 'teacher' || u.role == 'deputy' || u.role == 'manager').toList());
    List<UserModel> parents = _filterUserList(_users.where((u) => u.role == 'parent').toList());

    final totalCount = _users.length;
    final studentCount = _users.where((u) => u.role == 'student').length;
    final staffCount = _users.where((u) => u.role == 'teacher' || u.role == 'deputy' || u.role == 'manager').length;
    final parentCount = _users.where((u) => u.role == 'parent').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت کاربران و نقش‌ها'),
        backgroundColor: const Color(0xFF01579B),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          tabs: [
            Tab(text: 'دانش‌آموزان (${students.length})', icon: const Icon(Icons.child_care_rounded)),
            Tab(text: 'مربیان و کادر (${teachers.length})', icon: const Icon(Icons.badge_rounded)),
            Tab(text: 'والدین (${parents.length})', icon: const Icon(Icons.family_restroom_rounded)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'بایگانی',
            icon: const Icon(Icons.archive_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManagerArchivePage()),
            ).then((_) {
              UserDirectory.clearCache();
              ServerDirectory.reset();
              _loadUsers();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart_rounded),
            tooltip: 'خروجی اکسل',
            onPressed: () {
              ExportHelper.exportToExcel(
                context: context,
                title: 'لیست جامع کاربران مهدکودک',
                headers: ['نام', 'نقش', 'کلاس / بخش', 'شماره تماس'],
                rows: _users.map((u) => [u.name, _roleLabel(u.role), u.className, u.phone]).toList(),
                fileName: 'users_list_${DateTime.now().millisecondsSinceEpoch}',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'خروجی PDF',
            onPressed: () {
              ExportHelper.exportToPdf(
                context: context,
                title: 'گزارش رسمی لیست کاربران مهدکودک',
                headers: ['نام', 'نقش', 'کلاس / بخش', 'شماره تماس'],
                rows: _users.map((u) => [u.name, u.role == 'student' ? 'دانش‌آموز' : (u.role == 'teacher' ? 'مربی' : 'ولی'), u.className, u.phone]).toList(),
                fileName: 'users_list_${DateTime.now().millisecondsSinceEpoch}',
              );
            },
          ),
          /*print*/
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'چاپ',
            onPressed: () {
              ExportHelper.printTable(
                context: context,
                title: 'گزارش رسمی لیست کاربران مهدکودک',
                headers: ['نام', 'نقش', 'کلاس / بخش', 'شماره تماس'],
                rows: _users.map((u) => [u.name, u.role == 'student' ? 'دانش‌آموز' : (u.role == 'teacher' ? 'مربی' : 'ولی'), u.className, u.phone]).toList(),
                fileName: 'users_list_${DateTime.now().millisecondsSinceEpoch}',
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUserDialog(),
        backgroundColor: const Color(0xFF0288D1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('افزودن کاربر جدید'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_loadError!, textAlign: TextAlign.center)))
          : Column(
              children: [
                _buildStatsAndSearchHeader(
                  total: totalCount,
                  students: studentCount,
                  staff: staffCount,
                  parents: parentCount,
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUserList(students),
                      _buildUserList(teachers),
                      _buildUserList(parents),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsAndSearchHeader({
    required int total,
    required int students,
    required int staff,
    required int parents,
  }) {
    final classOptions = ['همه کلاس‌ها', ...kClassNames.map((c) => classLabel(c)), 'والدین و اولیاء', 'مدیریت'];

    return Container(
      padding: const EdgeInsets.all(14),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              _statChip('کل کاربران', '$total', Colors.blue.shade800, Colors.blue.shade50),
              const SizedBox(width: 8),
              _statChip('دانش‌آموزان', '$students', Colors.orange.shade800, Colors.orange.shade50),
              const SizedBox(width: 8),
              _statChip('مربیان/کادر', '$staff', Colors.purple.shade800, Colors.purple.shade50),
              const SizedBox(width: 8),
              _statChip('اولیاء', '$parents', Colors.teal.shade800, Colors.teal.shade50),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'جستجوی نام، تلفن، کلاس یا فرزند...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF01579B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedClassFilter,
                    isDense: true,
                    items: [
                      for (final opt in classOptions)
                        DropdownMenuItem(
                          value: opt,
                          child: Text(opt, style: const TextStyle(fontSize: 12)),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedClassFilter = val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: textColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: textColor), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String r) {
    switch (r) {
      case 'student':
        return 'دانش‌آموز';
      case 'teacher':
        return 'مربی';
      case 'deputy':
        return 'معاون / ناظم';
      case 'manager':
        return 'مدیر';
      case 'admin':
        return 'ادمین';
    }
    return 'ولی';
  }

  Widget _buildUserList(List<UserModel> list) {
    if (list.isEmpty) {
      return const Center(child: Text('کاربری ثبت نشده است.', style: TextStyle(color: Colors.grey, fontSize: 16)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final u = list[index];
        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: u.role == 'student' ? Colors.orange.shade100 : (u.role == 'teacher' ? Colors.purple.shade100 : Colors.blue.shade100),
              child: Icon(
                u.role == 'student' ? Icons.child_care : (u.role == 'teacher' ? Icons.badge : Icons.person),
                color: u.role == 'student' ? Colors.orange : (u.role == 'teacher' ? Colors.purple : Colors.blue),
              ),
            ),
            title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(u.role == 'parent' && u.linkedStudent.isNotEmpty ? 'ولی ${u.linkedStudent}' : 'بخش/کلاس: ${u.className}'),
                if (u.phone.isNotEmpty) Text('تلفن: ${u.phone}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                if (u.profileId != null)
                  Text(u.active == true ? 'حساب فعال' : 'حساب غیرفعال',
                      style: TextStyle(fontSize: 11, color: u.active == true ? Colors.green.shade700 : Colors.red.shade700)),
                if (u.relatedNames.isNotEmpty)
                  Text(
                    u.role == 'parent' ? 'فرزند: ${u.relatedNames.join('، ')}' : 'ولی: ${u.relatedNames.join('، ')}',
                    style: const TextStyle(fontSize: 11, color: Colors.black38),
                  ),
                if (u.role == 'student' && u.profileId == null)
                  const Text('حساب ورود متصل نیست', style: TextStyle(fontSize: 11, color: Colors.black45)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (u.profileId != null)
                  SizedBox(
                    width: 54,
                    child: _activeBusyIds.contains(u.profileId)
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : Switch.adaptive(
                            value: u.active == true,
                            onChanged: (value) => _setUserActive(u, value),
                          ),
                  ),
                if (u.profileId != null && u.active == true)
                  IconButton(
                    icon: const Icon(Icons.swap_horiz_rounded, color: Colors.orange),
                    tooltip: 'انتقال حساب',
                    onPressed: () => showTransferAccountDialog(context, u).then((changed) {
                      if (changed) {
                        UserDirectory.clearCache();
                        ServerDirectory.reset();
                        _loadUsers();
                      }
                    }),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                  tooltip: 'ویرایش مشخصات',
                  onPressed: () => _showAddUserDialog(editUser: u),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                  tooltip: 'حذف کاربر',
                  onPressed: () => _deleteUser(u.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

